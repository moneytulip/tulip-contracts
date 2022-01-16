pragma solidity ^0.8.0;

contract Simple {
    function time() external view returns(bool) {
        return block.timestamp >= 1642208631;
    }
}
