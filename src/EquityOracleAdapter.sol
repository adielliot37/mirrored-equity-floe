// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {IPriceSource} from "./interfaces/IPriceSource.sol";

contract EquityOracleAdapter is AggregatorV2V3Interface {
    address public immutable equityToken;
    bytes32 public immutable feedId;
    uint256 public immutable stalenessTimeout;
    IPriceSource public immutable priceSource;
    uint8 public immutable override decimals;
    string private _description;
    uint256 public constant override version = 1;
    
    event PriceFetched(int256 price, uint256 timestamp);
    event StalenessDetected(uint256 lastUpdate, uint256 currentTime);
    
    error PriceTooStale(uint256 lastUpdate, uint256 stalenessThreshold);
    error InvalidPrice();
    error FeedUnavailable();
    
    constructor(
        address _equityToken,
        bytes32 _feedId,
        address _priceSource,
        uint256 _stalenessTimeout,
        uint8 _decimals,
        string memory description_
    ) {
        require(_equityToken != address(0), "Invalid token");
        require(_priceSource != address(0), "Invalid price source");
        require(_stalenessTimeout > 0, "Invalid timeout");
        
        equityToken = _equityToken;
        feedId = _feedId;
        priceSource = IPriceSource(_priceSource);
        stalenessTimeout = _stalenessTimeout;
        decimals = _decimals;
        _description = description_;
    }
    
    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        if (!priceSource.isFeedAvailable(feedId)) {
            revert FeedUnavailable();
        }
        
        (uint256 price, uint256 timestamp) = priceSource.getLatestPrice(feedId);
        
        if (price == 0) revert InvalidPrice();
        
        if (block.timestamp - timestamp > stalenessTimeout) {
            revert PriceTooStale(timestamp, stalenessTimeout);
        }
        
        return (
            0,
            int256(price),
            0,
            timestamp,
            0
        );
    }
    
    function getRoundData(uint80)
        external
        pure
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        revert("Historical data not supported");
    }
    
    function latestAnswer() external view override returns (int256) {
        (, int256 answer,,,) = this.latestRoundData();
        return answer;
    }
    
    function latestTimestamp() external view override returns (uint256) {
        (,,, uint256 updatedAt,) = this.latestRoundData();
        return updatedAt;
    }
    
    function latestRound() external pure override returns (uint256) {
        return 0;
    }
    
    function getAnswer(uint256) external pure override returns (int256) {
        revert("Historical data not supported");
    }
    
    function getTimestamp(uint256) external pure override returns (uint256) {
        revert("Historical data not supported");
    }
    
    function description() external view override returns (string memory) {
        return _description;
    }
    
    function checkStaleness() external view returns (bool isStale, uint256 age) {
        (, uint256 timestamp) = priceSource.getLatestPrice(feedId);
        age = block.timestamp - timestamp;
        isStale = age > stalenessTimeout;
    }
}
