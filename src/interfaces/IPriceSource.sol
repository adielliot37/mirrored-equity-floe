// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

interface IPriceSource {
    function getLatestPrice(bytes32 feedId)
        external 
        view 
        returns (uint256 price, uint256 timestamp);
    
    function isFeedAvailable(bytes32 feedId) external view returns (bool isValid);
}
