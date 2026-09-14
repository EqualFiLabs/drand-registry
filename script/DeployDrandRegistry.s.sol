// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { EqualFiDrandRegistry } from "../src/EqualFiDrandRegistry.sol";

/// @notice Deploys the immutable, administrator-free Registry implementation.
contract DeployDrandRegistry is Script {
    function run() external returns (EqualFiDrandRegistry registry) {
        vm.startBroadcast();
        registry = new EqualFiDrandRegistry();
        vm.stopBroadcast();
    }
}
