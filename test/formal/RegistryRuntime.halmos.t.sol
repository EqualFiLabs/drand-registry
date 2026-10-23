// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { EqualFiDrandRegistry } from "../../src/EqualFiDrandRegistry.sol";

/// @notice Proves the duplicate path on the exact production Registry runtime.
/// @dev The setup writes a symbolic already-stored beacon because no valid symbolic BLS proof is
///      available. The property under test then calls only the production `postSig` bytecode.
contract RegistryRuntimeHalmosTest is Test {
    EqualFiDrandRegistry private registry;

    function setUp() public {
        registry = new EqualFiDrandRegistry();
    }

    function check_duplicateSubmissionIsNoOpOnRuntime(
        uint64 round,
        bytes32 storedRandomness,
        uint64 storedAt,
        bytes32 replacementProof
    ) public {
        bytes32 beaconSlot = keccak256(abi.encode(round, uint256(0)));
        vm.store(address(registry), beaconSlot, storedRandomness);
        vm.store(
            address(registry),
            bytes32(uint256(beaconSlot) + 1),
            bytes32(uint256(storedAt) | (uint256(1) << 64))
        );

        bool newlyStored = registry.postSig(round, abi.encodePacked(replacementProof));

        assert(!newlyStored);
        assert(registry.hasSig(round));
        assert(registry.randomnessOf(round) == storedRandomness);
        assert(registry.postedAt(round) == storedAt);
    }
}
