// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockEquityToken is ERC20 {
    uint8 private immutable _decimals;
    
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimalsValue
    ) ERC20(name, symbol) {
        _decimals = decimalsValue;
        _mint(msg.sender, 1_000_000 * 10 ** decimalsValue);
    }
    
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
