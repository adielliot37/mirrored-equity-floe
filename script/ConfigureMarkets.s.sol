// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";

interface ILendingIntentMatcher {
    function createMarket(
        address loanToken,
        address collateralToken,
        uint256 interestRateBps,
        uint256 ltvBps,
        uint256 marketFeeBps,
        uint256 liquidationIncentiveBps
    ) external;
}

contract ConfigureMarkets is Script {
    address constant USDC_ADDRESS = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    
    address constant NVDA_TOKEN = 0x370627bb90F37907bE2293a60d77e4938b35FAbA;
    address constant FLOE_MATCHER = address(0); // Replace with actual Floe matcher address
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== Configuring Equity-Backed Markets ===");
        
        ILendingIntentMatcher matcher = ILendingIntentMatcher(FLOE_MATCHER);
        
        configureNvidiaMarket(matcher);
        
        vm.stopBroadcast();
        
        console.log("=== Markets Configured Successfully ===");
    }
    
    function configureNvidiaMarket(ILendingIntentMatcher matcher) internal {
        console.log("\nConfiguring NVIDIA/USDC Market:");
        console.log("  Collateral: NVDA");
        console.log("  Loan Token: USDC");
        
        matcher.createMarket(
            USDC_ADDRESS,
            NVDA_TOKEN,
            600,    // 6% annual interest
            4500,   // 45% LTV
            150,    // 1.5% protocol fee
            700     // 7% liquidation incentive
        );
        
        console.log("  Status: Created");
    }
    
    function configureBlueChipMarket(
        ILendingIntentMatcher matcher,
        address equityToken,
        string memory symbol
    ) internal {
        console.log(string.concat("\nConfiguring ", symbol, "/USDC Market (Blue-Chip):"));
        
        matcher.createMarket(
            USDC_ADDRESS,
            equityToken,
            400,    // 4% annual interest
            6000,   // 60% LTV
            100,    // 1% protocol fee
            500     // 5% liquidation incentive
        );
        
        console.log("  Status: Created");
    }
    
    function configureVolatileMarket(
        ILendingIntentMatcher matcher,
        address equityToken,
        string memory symbol
    ) internal {
        console.log(string.concat("\nConfiguring ", symbol, "/USDC Market (Volatile):"));
        
        matcher.createMarket(
            USDC_ADDRESS,
            equityToken,
            800,    // 8% annual interest
            3500,   // 35% LTV
            200,    // 2% protocol fee
            1000    // 10% liquidation incentive
        );
        
        console.log("  Status: Created");
    }
}
