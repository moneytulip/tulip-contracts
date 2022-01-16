// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./owner/Operator.sol";

// _________  ___  ___  ___       ___  ________   
// |\___   ___\\  \|\  \|\  \     |\  \|\   __  \  
// \|___ \  \_\ \  \\\  \ \  \    \ \  \ \  \|\  \ 
//      \ \  \ \ \  \\\  \ \  \    \ \  \ \   ____\
//       \ \  \ \ \  \\\  \ \  \____\ \  \ \  \___|
//        \ \__\ \ \_______\ \_______\ \__\ \__\   
//         \|__|  \|_______|\|_______|\|__|\|__|

contract Petal is ERC20Burnable, Operator {
    using SafeMath for uint256;

    // TOTAL MAX SUPPLY = 70,000 Petal
    uint256 public constant FARMING_POOL_REWARD_ALLOCATION = 65000 ether;
    // DEV
    uint256 public constant DEV_FUND_POOL_ALLOCATION = 5000 ether;

    uint256 public constant VESTING_DURATION = 90 days;
    uint256 public startTime;
    uint256 public endTime;

    uint256 public devFundRewardRate;

    address public devFund;

    uint256 public devFundLastClaimed;

    bool public rewardPoolDistributed = false;

    constructor(address _devFund) public ERC20("PETAL", "PETAL") {
        _mint(msg.sender, 10 ether); // mint 10 Tulip for initial pools deployment

        startTime = block.timestamp + 2 hours;
        endTime = startTime + VESTING_DURATION;

        devFundLastClaimed = startTime;

        devFundRewardRate = DEV_FUND_POOL_ALLOCATION.div(VESTING_DURATION);

        require(_devFund != address(0), "Address cannot be 0");
        devFund = _devFund;
    }

    function setDevFund(address _devFund) external {
        require(msg.sender == devFund, "!dev");
        require(_devFund != address(0), "zero");
        devFund = _devFund;
    }

    function unclaimedDevFund() public view returns (uint256 _pending) {
        uint256 _now = block.timestamp;
        if (_now > endTime) _now = endTime;
        if (devFundLastClaimed >= _now) return 0;
        _pending = _now.sub(devFundLastClaimed).mul(devFundRewardRate);
    }

    /**
     * @dev Claim pending rewards to community and dev fund
     */
    function claimRewards() external {
        uint256 _pending = unclaimedDevFund();
        if (_pending > 0 && devFund != address(0)) {
            _mint(devFund, _pending);
            devFundLastClaimed = block.timestamp;
        }
    }

    /**
     * @notice distribute to reward pool (only once)
     */
    function distributeReward(address _farmingIncentiveFund) external onlyOperator {
        require(!rewardPoolDistributed, "only can distribute once");
        require(_farmingIncentiveFund != address(0), "!_farmingIncentiveFund");
        rewardPoolDistributed = true;
        _mint(_farmingIncentiveFund, FARMING_POOL_REWARD_ALLOCATION);
    }

    function burn(uint256 amount) public override {
        super.burn(amount);
    }

    function governanceRecoverUnsupported(
        IERC20 _token,
        uint256 _amount,
        address _to
    ) external onlyOperator {
        _token.transfer(_to, _amount);
    }
}