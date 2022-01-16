pragma solidity ^0.8.0;

interface IERC20Token {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
    function burn(uint256 amount) external;
}

contract TokenSale {
    IERC20Token public tokenContract;  // the token being sold
    address owner;
    mapping(address => uint256) private _balances;
    bool public started;
    bool public completed;

    uint256 MAX_TOKEN_PURCHASE = 3000 ether;

    uint256 public tokensSold;

    event Sold(address buyer, uint256 amount);

    constructor(IERC20Token _tokenContract) public {
        owner = msg.sender;
        tokenContract = _tokenContract;
        started = false;
    }

    // Guards against integer overflows
    function safeMultiply(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        } else {
            uint256 c = a * b;
            assert(c / a == b);
            return c;
        }
    }

    function buyTokens(uint256 numberOfTokens) public payable {
        require(started, "sale is not started yet");
        require(!completed, "sale is stopped");
        require(msg.value == safeMultiply(numberOfTokens, 1 ether), "invalid total");

        uint256 scaledAmount = safeMultiply(numberOfTokens,
            uint256(10) ** tokenContract.decimals());
        tokensSold += scaledAmount;

        require(tokenContract.balanceOf(address(this)) >= tokensSold, "not enough tokens left in contract");

        emit Sold(msg.sender, numberOfTokens);
        _balances[msg.sender] += scaledAmount;
        require(_balances[msg.sender] <= MAX_TOKEN_PURCHASE, "Bought more than max allotment");
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function start() public {
        require(msg.sender == owner);
        started = true;
    }

    function claim() public {
        require(completed, "Not complete yet");

        uint256 total = _balances[msg.sender];
        delete _balances[msg.sender];

        require(tokenContract.transfer(msg.sender, total), "transfer error");
    }

    function endSale() public {
        require(msg.sender == owner);
        require(started == true);

        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "transfer failed");
        completed = true;
    }

    function burnUnsold() public {
        require(msg.sender == owner);
        require(completed);
        tokenContract.burn(tokenContract.balanceOf(address(this)));
    }
}
