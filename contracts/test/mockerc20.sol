// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../worldPublicswappair.sol';

contract mockerc20 is ERC20 {
    uint8 private _decimals;
    constructor(uint _totalSupply,
                string memory name,
                string memory symbol,
                uint8 decimals_) ERC20(name,symbol) {
        _decimals = decimals_;
        _mint(msg.sender, _totalSupply);
    }
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
