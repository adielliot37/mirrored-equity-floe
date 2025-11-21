// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {EquityOracleAdapter} from "../src/EquityOracleAdapter.sol";
import {ChainlinkDataStreamsAdapter} from "../src/adapters/ChainlinkDataStreamsAdapter.sol";
import {MockEquityToken} from "../src/MockEquityToken.sol";

contract DeployEquityOracle is Script {
    uint256 constant MARKET_HOURS_TIMEOUT = 6 hours;
    uint256 constant EXTENDED_TIMEOUT = 24 hours;
    uint8 constant PRICE_DECIMALS = 8;
    uint8 constant TOKEN_DECIMALS = 18;
    address constant ETH_USD_FEED = 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("Deploying with address:", deployer);
        console2.log("Balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console2.log("\n=== Deploying ChainlinkDataStreamsAdapter ===");
        ChainlinkDataStreamsAdapter priceSource = new ChainlinkDataStreamsAdapter();
        console2.log("ChainlinkDataStreamsAdapter deployed at:", address(priceSource));
        
        bytes32 nvdaFeedId = keccak256("NVDA/USD");
        bytes32 aaplFeedId = keccak256("AAPL/USD");
        bytes32 tslaFeedId = keccak256("TSLA/USD");
        
        console2.log("\n=== Configuring Price Feeds ===");
        console2.log("Adding NVDA/USD feed (using ETH/USD as proxy)");
        priceSource.addFeed(nvdaFeedId, ETH_USD_FEED);
        
        console2.log("Adding AAPL/USD feed (using ETH/USD as proxy)");
        priceSource.addFeed(aaplFeedId, ETH_USD_FEED);
        
        console2.log("Adding TSLA/USD feed (using ETH/USD as proxy)");
        priceSource.addFeed(tslaFeedId, ETH_USD_FEED);
        
        console2.log("\n=== Deploying Mock Equity Tokens ===");
        
        MockEquityToken nvidiaToken = new MockEquityToken("NVIDIA Token", "NVDA", TOKEN_DECIMALS);
        console2.log("NVIDIA Token deployed at:", address(nvidiaToken));
        
        MockEquityToken appleToken = new MockEquityToken("Apple Token", "AAPL", TOKEN_DECIMALS);
        console2.log("Apple Token deployed at:", address(appleToken));
        
        MockEquityToken teslaToken = new MockEquityToken("Tesla Token", "TSLA", TOKEN_DECIMALS);
        console2.log("Tesla Token deployed at:", address(teslaToken));
        
        console2.log("\n=== Deploying EquityOracleAdapters ===");
        
        EquityOracleAdapter nvidiaOracle = new EquityOracleAdapter(
            address(nvidiaToken),
            nvdaFeedId,
            address(priceSource),
            MARKET_HOURS_TIMEOUT,
            PRICE_DECIMALS,
            "NVIDIA/USD"
        );
        console2.log("NVIDIA Oracle deployed at:", address(nvidiaOracle));
        
        EquityOracleAdapter appleOracle = new EquityOracleAdapter(
            address(appleToken),
            aaplFeedId,
            address(priceSource),
            MARKET_HOURS_TIMEOUT,
            PRICE_DECIMALS,
            "Apple/USD"
        );
        console2.log("Apple Oracle deployed at:", address(appleOracle));
        
        EquityOracleAdapter teslaOracle = new EquityOracleAdapter(
            address(teslaToken),
            tslaFeedId,
            address(priceSource),
            EXTENDED_TIMEOUT,
            PRICE_DECIMALS,
            "Tesla/USD"
        );
        console2.log("Tesla Oracle deployed at:", address(teslaOracle));
        
        vm.stopBroadcast();
        
        console2.log("\n=== Deployment Summary ===");
        console2.log("ChainlinkDataStreamsAdapter:", address(priceSource));
        console2.log("");
        console2.log("Tokens:");
        console2.log("  NVDA:", address(nvidiaToken));
        console2.log("  AAPL:", address(appleToken));
        console2.log("  TSLA:", address(teslaToken));
        console2.log("");
        console2.log("Oracles:");
        console2.log("  NVDA Oracle:", address(nvidiaOracle));
        console2.log("  AAPL Oracle:", address(appleOracle));
        console2.log("  TSLA Oracle:", address(teslaOracle));
        console2.log("");
        console2.log("Staleness Timeouts:");
        console2.log("  NVDA, AAPL:", MARKET_HOURS_TIMEOUT / 3600, "hours");
        console2.log("  TSLA:", EXTENDED_TIMEOUT / 3600, "hours");
        
        string memory deploymentInfo = string.concat(
            "ChainlinkDataStreamsAdapter=", vm.toString(address(priceSource)), "\n",
            "NVDA_Token=", vm.toString(address(nvidiaToken)), "\n",
            "AAPL_Token=", vm.toString(address(appleToken)), "\n",
            "TSLA_Token=", vm.toString(address(teslaToken)), "\n",
            "NVDA_Oracle=", vm.toString(address(nvidiaOracle)), "\n",
            "AAPL_Oracle=", vm.toString(address(appleOracle)), "\n",
            "TSLA_Oracle=", vm.toString(address(teslaOracle)), "\n"
        );
        
        vm.writeFile("deployments/base-sepolia.txt", deploymentInfo);
        console2.log("\nDeployment addresses saved to: deployments/base-sepolia.txt");
    }
}
