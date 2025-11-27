// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {NvdaLendingPool} from "../src/NvdaLendingPool.sol";

contract DeployNvdaLendingPool is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address nvdaToken = vm.envAddress("NVDA_TOKEN");
        address nvdaOracle = vm.envAddress("NVDA_ORACLE");
        address usdcToken = vm.envAddress("USDC_TOKEN");

        vm.startBroadcast(deployerKey);

        console2.log("Deploying NvdaLendingPool...");
        NvdaLendingPool pool = new NvdaLendingPool(nvdaToken, usdcToken, nvdaOracle);
        console2.log("NvdaLendingPool deployed at:", address(pool));

        vm.stopBroadcast();

        string memory deploymentInfo = string.concat(
            "USDC_TOKEN=", vm.toString(usdcToken), "\n",
            "NvdaLendingPool=", vm.toString(address(pool)), "\n"
        );

        vm.writeFile("deployments/nvda-lending-base-sepolia.txt", deploymentInfo);
        console2.log("Deployment info written to deployments/nvda-lending-base-sepolia.txt");
    }
}

