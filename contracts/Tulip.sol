pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./owner/Operator.sol";
import "./lib/SafeMath8.sol";
import "./interfaces/IOracle.sol";

// _________  ___  ___  ___       ___  ________   
// |\___   ___\\  \|\  \|\  \     |\  \|\   __  \  
// \|___ \  \_\ \  \\\  \ \  \    \ \  \ \  \|\  \ 
//      \ \  \ \ \  \\\  \ \  \    \ \  \ \   ____\
//       \ \  \ \ \  \\\  \ \  \____\ \  \ \  \___|
//        \ \__\ \ \_______\ \_______\ \__\ \__\   
//         \|__|  \|_______|\|_______|\|__|\|__|

contract Tulip is ERC20Burnable, Operator {
    using SafeMath8 for uint8;
    using SafeMath for uint256;

    // Initial distribution for the first 24h genesis pools
    uint256 public constant INITIAL_GENESIS_POOL_DISTRIBUTION = 50000 ether;
    // Initial distribution for the day 2-5 TULIP-ROSE LP -> TULIP pool
    uint256 public constant INITIAL_TULIP_POOL_DISTRIBUTION = 250000 ether;
    // Distribution for initial offering
    uint256 public constant INITIAL_OFFERING_DISTRIBUTION = 90000 ether;

    // Have the rewards been distributed to the pools
    bool public rewardPoolDistributed = false;
    bool public initialOfferingDistributed = false;

    /* ================= Taxation =============== */
    // Address of the Oracle
    address public tulipOracle;
    // Address of the Tax Office
    address public taxOffice;

    address private _operator;

    // Current tax rate
    uint256 public taxRate;
    // Price threshold below which taxes will get burned
    uint256 public burnThreshold = 1.10e18;
    // Address of the tax collector wallet
    address public taxCollectorAddress;

    // Should the taxes be calculated using the tax tiers
    bool public autoCalculateTax;

    // Sender addresses excluded from Tax
    mapping(address => bool) public excludedAddresses;

    event TaxOfficeTransferred(address oldAddress, address newAddress);

    modifier onlyTaxOffice() {
        require(taxOffice == msg.sender, "Caller is not the tax office");
        _;
    }

    modifier onlyOperatorOrTaxOffice() {
        require(isOperator() || taxOffice == msg.sender, "Caller is not the operator or the tax office");
        _;
    }

    /**
     * @notice Constructs the TULIP ERC-20 contract.
     */
    constructor(uint256 _taxRate, address _taxCollectorAddress) public ERC20("TULIP", "TULIP") {
        // Mints 1 TULIP to contract creator for initial pool setup
        require(_taxRate < 10000, "tax equal or bigger to 100%");
        require(_taxCollectorAddress != address(0), "tax collector address must be non-zero address");

        emit OperatorTransferred(address(0), _operator);

        excludeAddress(address(this));

        _mint(msg.sender, 1 ether);
        taxRate = _taxRate;
        taxCollectorAddress = _taxCollectorAddress;
    }

    function setBurnThreshold(uint256 _burnThreshold) public onlyTaxOffice returns (bool) {
        burnThreshold = _burnThreshold;
    }

    function _getTulipPrice() internal view returns (uint256 _tulipPrice) {
        try IOracle(tulipOracle).consult(address(this), 1e18) returns (uint144 _price) {
            return uint256(_price);
        } catch {
            revert("Tulip: failed to fetch TULIP price from Oracle");
        }
    }

    function setTulipOracle(address _tulipOracle) public onlyOperatorOrTaxOffice {
        require(_tulipOracle != address(0), "oracle address cannot be 0 address");
        tulipOracle = _tulipOracle;
    }

    function setTaxOffice(address _taxOffice) public onlyOperatorOrTaxOffice {
        require(_taxOffice != address(0), "tax office address cannot be 0 address");
        emit TaxOfficeTransferred(taxOffice, _taxOffice);
        taxOffice = _taxOffice;
    }

    function setTaxCollectorAddress(address _taxCollectorAddress) public onlyTaxOffice {
        require(_taxCollectorAddress != address(0), "tax collector address must be non-zero address");
        taxCollectorAddress = _taxCollectorAddress;
    }

    function excludeAddress(address _address) public onlyOperatorOrTaxOffice returns (bool) {
        require(!excludedAddresses[_address], "address can't be excluded");
        excludedAddresses[_address] = true;
        return true;
    }

    function includeAddress(address _address) public onlyOperatorOrTaxOffice returns (bool) {
        require(excludedAddresses[_address], "address can't be included");
        excludedAddresses[_address] = false;
        return true;
    }

    /**
     * @notice Operator mints TULIP to a recipient
     * @param recipient_ The address of recipient
     * @param amount_ The amount of TULIP to mint to
     * @return whether the process has been done
     */
    function mint(address recipient_, uint256 amount_) public onlyOperator returns (bool) {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);

        return balanceAfter > balanceBefore;
    }

    function burn(uint256 amount) public override {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount) public override onlyOperator {
        super.burnFrom(account, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        uint256 currentTaxRate = 0;

        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), allowance(sender, _msgSender()).sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function distributeInitialOffering(
        address _offeringContract
    ) external onlyOperator {
        require(_offeringContract != address(0), "!_offeringContract");
        require(!initialOfferingDistributed, "only distribute once");

        _mint(_offeringContract, INITIAL_OFFERING_DISTRIBUTION);
        initialOfferingDistributed = true;
    }

    /**
     * @notice distribute to reward pool (only once)
     */
    function distributeReward(
        address _genesisPool,
        address _tulipPool,
        address _offeringContract
    ) external onlyOperator {
        require(!rewardPoolDistributed, "only can distribute once");
        require(_genesisPool != address(0), "!_genesisPool");
        require(_tulipPool != address(0), "!_tulipPool");
        rewardPoolDistributed = true;
        _mint(_genesisPool, INITIAL_GENESIS_POOL_DISTRIBUTION);
        _mint(_tulipPool, INITIAL_TULIP_POOL_DISTRIBUTION);
    }

    function governanceRecoverUnsupported(
        IERC20 _token,
        uint256 _amount,
        address _to
    ) external onlyOperator {
        _token.transfer(_to, _amount);
    }
}
