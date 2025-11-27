// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    uint8 private constant TOKEN_DECIMALS = 6;

    constructor() ERC20("Mock USD Coin", "mUSDC") {
        _mint(msg.sender, 10_000_000 * 10 ** TOKEN_DECIMALS);
    }

    function decimals() public pure override returns (uint8) {
        return TOKEN_DECIMALS;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
