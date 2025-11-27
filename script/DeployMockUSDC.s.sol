// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

contract DeployMockUSDC is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);
        MockUSDC usdc = new MockUSDC();
        vm.stopBroadcast();

        console2.log("MockUSDC deployed at:", address(usdc));

        string memory deploymentInfo = string.concat(
            "MockUSDC=", vm.toString(address(usdc)),
            "\n"
        );
        vm.writeFile("deployments/mock-usdc-base-sepolia.txt", deploymentInfo);
        console2.log("Deployment info written to deployments/mock-usdc-base-sepolia.txt");
    }
}

