// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import {IPriceSource} from "../interfaces/IPriceSource.sol";

contract ManualPriceAdapter is IPriceSource {
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        bool exists;
    }
    
    mapping(bytes32 => PriceData) public prices;
    address public immutable owner;
    mapping(address => bool) public isAuthorized;
    
    event PriceUpdated(bytes32 indexed feedId, uint256 price, uint256 timestamp, address updater);
    event AuthorizationChanged(address indexed account, bool authorized);
    
    error Unauthorized();
    error InvalidPrice();
    error FeedNotFound();
    
    modifier onlyAuthorized() {
        if (!isAuthorized[msg.sender] && msg.sender != owner) revert Unauthorized();
        _;
    }
    
    constructor() {
        owner = msg.sender;
        isAuthorized[msg.sender] = true;
    }
    
    function updatePrice(bytes32 feedId, uint256 price) external onlyAuthorized {
        if (price == 0) revert InvalidPrice();
        
        prices[feedId] = PriceData({
            price: price,
            timestamp: block.timestamp,
            exists: true
        });
        
        emit PriceUpdated(feedId, price, block.timestamp, msg.sender);
    }
    
    function updatePrices(bytes32[] calldata feedIds, uint256[] calldata priceValues) external onlyAuthorized {
        require(feedIds.length == priceValues.length, "Length mismatch");
        
        for (uint256 i = 0; i < feedIds.length; i++) {
            if (priceValues[i] == 0) revert InvalidPrice();
            
            prices[feedIds[i]] = PriceData({
                price: priceValues[i],
                timestamp: block.timestamp,
                exists: true
            });
            
            emit PriceUpdated(feedIds[i], priceValues[i], block.timestamp, msg.sender);
        }
    }
    
    function getLatestPrice(bytes32 feedId)
        external 
        view 
        override
        returns (uint256 price, uint256 timestamp) 
    {
        PriceData memory data = prices[feedId];
        if (!data.exists) revert FeedNotFound();
        return (data.price, data.timestamp);
    }
    
    function isFeedAvailable(bytes32 feedId) external view override returns (bool) {
        return prices[feedId].exists;
    }
    
    function setAuthorization(address account, bool authorized) external {
        if (msg.sender != owner) revert Unauthorized();
        isAuthorized[account] = authorized;
        emit AuthorizationChanged(account, authorized);
    }
}
