// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import {IPriceSource} from "../interfaces/IPriceSource.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract ChainlinkDataStreamsAdapter is IPriceSource {
    mapping(bytes32 => address) public feedAggregators;
    address public immutable owner;
    
    event FeedAdded(bytes32 indexed feedId, address indexed aggregator);
    event FeedRemoved(bytes32 indexed feedId);
    
    error Unauthorized();
    error InvalidAggregator();
    error FeedNotFound();
    error StalePrice();
    
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    function addFeed(bytes32 feedId, address aggregator) external onlyOwner {
        if (aggregator == address(0)) revert InvalidAggregator();
        
        try AggregatorV3Interface(aggregator).decimals() returns (uint8) {
            feedAggregators[feedId] = aggregator;
            emit FeedAdded(feedId, aggregator);
        } catch {
            revert InvalidAggregator();
        }
    }
    
    function removeFeed(bytes32 feedId) external onlyOwner {
        delete feedAggregators[feedId];
        emit FeedRemoved(feedId);
    }
    
    function getLatestPrice(bytes32 feedId)
        external 
        view 
        override
        returns (uint256 price, uint256 timestamp) 
    {
        address aggregator = feedAggregators[feedId];
        if (aggregator == address(0)) revert FeedNotFound();
        
        AggregatorV3Interface priceFeed = AggregatorV3Interface(aggregator);
        
        (
            /* uint80 roundId */,
            int256 answer,
            /* uint256 startedAt */,
            uint256 updatedAt,
            /* uint80 answeredInRound */
        ) = priceFeed.latestRoundData();
        
        require(answer > 0, "Invalid price");
        
        return (uint256(answer), updatedAt);
    }
    
    function isFeedAvailable(bytes32 feedId) external view override returns (bool isValid) {
        return feedAggregators[feedId] != address(0);
    }
    
    function getFeedDecimals(bytes32 feedId) external view returns (uint8) {
        address aggregator = feedAggregators[feedId];
        if (aggregator == address(0)) revert FeedNotFound();
        return AggregatorV3Interface(aggregator).decimals();
    }
    
    function getFeedDescription(bytes32 feedId) external view returns (string memory) {
        address aggregator = feedAggregators[feedId];
        if (aggregator == address(0)) revert FeedNotFound();
        return AggregatorV3Interface(aggregator).description();
    }
}
