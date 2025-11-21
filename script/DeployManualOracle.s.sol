// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {EquityOracleAdapter} from "../src/EquityOracleAdapter.sol";

contract DeployManualOracle is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Contract addresses
        address nvdaToken = 0x370627bb90F37907bE2293a60d77e4938b35FAbA;
        address manualAdapter = 0xbBD700ca8Fc326c90BA90A028fC1C7b36b0e9D7B;
        bytes32 nvdaFeedId = keccak256("NVDA/USD");
        uint256 stalenessTimeout = 21600; // 6 hours
        uint8 decimals = 8;
        string memory description = "NVIDIA/USD";
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy NVDA Oracle
        EquityOracleAdapter nvdaOracle = new EquityOracleAdapter(
            nvdaToken,
            nvdaFeedId,
            manualAdapter,
            stalenessTimeout,
            decimals,
            description
        );
        
        console.log("NVDA Oracle deployed to:", address(nvdaOracle));
        console.log("Feed ID:", vm.toString(nvdaFeedId));
        
        vm.stopBroadcast();
    }
}
