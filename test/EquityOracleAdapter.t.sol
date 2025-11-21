// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {EquityOracleAdapter} from "../src/EquityOracleAdapter.sol";
import {ChainlinkDataStreamsAdapter} from "../src/adapters/ChainlinkDataStreamsAdapter.sol";
import {MockEquityToken} from "../src/MockEquityToken.sol";

contract EquityOracleAdapterTest is Test {
    EquityOracleAdapter public oracle;
    ChainlinkDataStreamsAdapter public priceSource;
    MockEquityToken public equityToken;
    
    bytes32 constant FEED_ID = keccak256("TEST/USD");
    uint256 constant STALENESS_TIMEOUT = 6 hours;
    uint8 constant DECIMALS = 8;
    
    // Mock Chainlink aggregator for testing
    MockChainlinkAggregator public mockAggregator;
    
    address owner = address(this);
    
    function setUp() public {
        // Deploy mock equity token
        equityToken = new MockEquityToken("Test Equity", "TEST", 18);
        
        // Deploy mock Chainlink aggregator
        mockAggregator = new MockChainlinkAggregator(DECIMALS);
        mockAggregator.updateAnswer(100_000_000); // $100.00
        
        // Deploy price source adapter
        priceSource = new ChainlinkDataStreamsAdapter();
        
        // Configure feed
        priceSource.addFeed(FEED_ID, address(mockAggregator));
        
        // Deploy oracle adapter
        oracle = new EquityOracleAdapter(
            address(equityToken),
            FEED_ID,
            address(priceSource),
            STALENESS_TIMEOUT,
            DECIMALS,
            "TEST/USD"
        );
    }
    
    function test_Constructor() public view {
        assertEq(oracle.equityToken(), address(equityToken));
        assertEq(oracle.feedId(), FEED_ID);
        assertEq(address(oracle.priceSource()), address(priceSource));
        assertEq(oracle.stalenessTimeout(), STALENESS_TIMEOUT);
        assertEq(oracle.decimals(), DECIMALS);
        assertEq(oracle.description(), "TEST/USD");
        assertEq(oracle.version(), 1);
    }
    
    function test_LatestRoundData() public view {
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = oracle.latestRoundData();
        
        assertEq(roundId, 0);
        assertEq(answer, 100_000_000); // $100.00
        assertEq(startedAt, 0);
        assertGt(updatedAt, 0);
        assertEq(answeredInRound, 0);
    }
    
    function test_LatestAnswer() public view {
        int256 answer = oracle.latestAnswer();
        assertEq(answer, 100_000_000);
    }
    
    function test_LatestTimestamp() public view {
        uint256 timestamp = oracle.latestTimestamp();
        assertGt(timestamp, 0);
        assertLe(timestamp, block.timestamp);
    }
    
    function test_LatestRound() public view {
        uint256 round = oracle.latestRound();
        assertEq(round, 0);
    }
    
    function test_RevertWhen_PriceIsStale() public {
        // Warp forward past staleness timeout
        vm.warp(block.timestamp + STALENESS_TIMEOUT + 1);
        
        vm.expectRevert();
        oracle.latestRoundData();
    }
    
    function test_RevertWhen_FeedUnavailable() public {
        // Create oracle with non-existent feed
        bytes32 invalidFeedId = keccak256("INVALID/USD");
        EquityOracleAdapter invalidOracle = new EquityOracleAdapter(
            address(equityToken),
            invalidFeedId,
            address(priceSource),
            STALENESS_TIMEOUT,
            DECIMALS,
            "INVALID/USD"
        );
        
        vm.expectRevert(EquityOracleAdapter.FeedUnavailable.selector);
        invalidOracle.latestRoundData();
    }
    
    function test_RevertWhen_PriceIsZero() public {
        // Update mock aggregator to return 0
        mockAggregator.updateAnswer(0);
        
        vm.expectRevert("Invalid price");
        oracle.latestRoundData();
    }
    
    function test_CheckStaleness_Fresh() public view {
        (bool isStale, uint256 age) = oracle.checkStaleness();
        assertFalse(isStale);
        assertLe(age, 1);
    }
    
    function test_CheckStaleness_Stale() public {
        vm.warp(block.timestamp + STALENESS_TIMEOUT + 1);
        
        (bool isStale, uint256 age) = oracle.checkStaleness();
        assertTrue(isStale);
        assertGt(age, STALENESS_TIMEOUT);
    }
    
    function test_GetRoundData_Reverts() public {
        vm.expectRevert("Historical data not supported");
        oracle.getRoundData(1);
    }
    
    function test_GetAnswer_Reverts() public {
        vm.expectRevert("Historical data not supported");
        oracle.getAnswer(1);
    }
    
    function test_GetTimestamp_Reverts() public {
        vm.expectRevert("Historical data not supported");
        oracle.getTimestamp(1);
    }
    
    function test_PriceUpdate() public {
        // Initial price
        int256 initialPrice = oracle.latestAnswer();
        assertEq(initialPrice, 100_000_000);
        
        // Update price
        mockAggregator.updateAnswer(150_000_000); // $150.00
        
        // Check updated price
        int256 newPrice = oracle.latestAnswer();
        assertEq(newPrice, 150_000_000);
    }
    
    function testFuzz_PriceValues(int256 price) public {
        vm.assume(price > 0);
        vm.assume(price < type(int256).max);
        
        mockAggregator.updateAnswer(price);
        int256 retrievedPrice = oracle.latestAnswer();
        assertEq(retrievedPrice, price);
    }
}

/// @notice Mock Chainlink aggregator for testing
contract MockChainlinkAggregator {
    uint8 public decimals;
    int256 public latestAnswer_;
    uint256 public latestTimestamp_;
    
    constructor(uint8 _decimals) {
        decimals = _decimals;
        latestTimestamp_ = block.timestamp;
    }
    
    function updateAnswer(int256 answer) external {
        latestAnswer_ = answer;
        latestTimestamp_ = block.timestamp;
    }
    
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (0, latestAnswer_, 0, latestTimestamp_, 0);
    }
    
    function description() external pure returns (string memory) {
        return "Mock Aggregator";
    }
}
