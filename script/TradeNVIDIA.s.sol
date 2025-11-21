// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {MockEquityToken} from "../src/MockEquityToken.sol";
import {EquityOracleAdapter} from "../src/EquityOracleAdapter.sol";


contract TradeNVIDIA is Script {
    // After deployment, replace these with your actual deployed addresses
    address constant NVDA_TOKEN = address(0); // Replace with deployed address
    address constant NVDA_ORACLE = address(0); // Replace with deployed address
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // If you have the addresses, use them. Otherwise deploy locally for testing
        MockEquityToken nvidiaToken;
        EquityOracleAdapter nvidiaOracle;
        
        if (NVDA_TOKEN == address(0)) {
            console2.log("No addresses provided. Please deploy first with DeployEquityOracle.s.sol");
            console2.log("Or update NVDA_TOKEN and NVDA_ORACLE constants in this script");
            return;
        }
        
        nvidiaToken = MockEquityToken(NVDA_TOKEN);
        nvidiaOracle = EquityOracleAdapter(NVDA_ORACLE);
        
        // ===== STEP 1: Check your NVIDIA token balance =====
        console2.log("\n=== Your NVIDIA Token Balance ===");
        uint256 balance = nvidiaToken.balanceOf(user);
        console2.log("Balance:", balance / 1e18, "NVDA tokens");
        
        // ===== STEP 2: Get current NVIDIA price from oracle =====
        console2.log("\n=== Current NVIDIA Price ===");
        try nvidiaOracle.latestRoundData() returns (
            uint80,
            int256 price,
            uint256,
            uint256 timestamp,
            uint80
        ) {
            console2.log("Price: $", uint256(price) / 1e8);
            console2.log("Decimals:", nvidiaOracle.decimals());
            console2.log("Last Updated:", timestamp);
            console2.log("Description:", nvidiaOracle.description());
            
            // Calculate your portfolio value
            uint256 portfolioValue = (balance * uint256(price)) / 1e18 / 1e8;
            console2.log("\nYour Portfolio Value: $", portfolioValue);
        } catch {
            console2.log("Error: Could not fetch price. Price might be stale.");
        }
        
        // ===== STEP 3: Check staleness =====
        console2.log("\n=== Price Feed Health ===");
        try nvidiaOracle.checkStaleness() returns (bool isStale, uint256 age) {
            if (isStale) {
                console2.log("WARNING: Price is STALE");
                console2.log("Age:", age / 3600, "hours");
            } else {
                console2.log("Price is FRESH");
                console2.log("Age:", age, "seconds");
            }
        } catch {
            console2.log("Could not check staleness");
        }
        
        // ===== STEP 4: Mint more tokens (only works if you're the deployer) =====
        console2.log("\n=== Minting Additional Tokens ===");
        try nvidiaToken.mint(user, 100 * 1e18) {
            console2.log("Successfully minted 100 NVDA tokens");
            console2.log("New balance:", nvidiaToken.balanceOf(user) / 1e18);
        } catch {
            console2.log("Could not mint (you may not be the token owner)");
        }
        
        // ===== STEP 5: Example - Transfer tokens =====
        console2.log("\n=== Transfer Example ===");
        address recipient = address(0x1234567890123456789012345678901234567890);
        uint256 transferAmount = 10 * 1e18; // Transfer 10 NVDA
        
        if (nvidiaToken.balanceOf(user) >= transferAmount) {
            nvidiaToken.transfer(recipient, transferAmount);
            console2.log("Transferred", transferAmount / 1e18, "NVDA to", recipient);
        } else {
            console2.log("Insufficient balance for transfer");
        }
        
        vm.stopBroadcast();
        
        // ===== SUMMARY =====
        console2.log("\n=== Summary ===");
        console2.log("Token Address:", address(nvidiaToken));
        console2.log("Oracle Address:", address(nvidiaOracle));
        console2.log("Your Address:", user);
    }
}
