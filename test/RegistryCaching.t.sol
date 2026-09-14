// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { EqualFiDrandRegistry } from "../src/EqualFiDrandRegistry.sol";
import { IEqualFiDrandRegistry } from "../src/interfaces/IEqualFiDrandRegistry.sol";
import { QuicknetVerifier } from "../src/libraries/QuicknetVerifier.sol";

contract RegistryCachingTest is Test {
    uint64 private constant VECTOR_ROUND = 20_791_007;
    bytes private constant COMPRESSED_SIGNATURE =
        hex"8d2c8bbc37170dbacc5e280a21d4e195cff5f32a19fd6a58633fa4e4670478b5fb39bc13dd8f8c4372c5a76191198ac5";
    bytes private constant UNCOMPRESSED_SIGNATURE =
        hex"0d2c8bbc37170dbacc5e280a21d4e195cff5f32a19fd6a58633fa4e4670478b5fb39bc13dd8f8c4372c5a76191198ac50823ff37364b4060af65c7ec4dde05a428e4a444713680d95c34a4b109f112af1792643c742b75d85940c4bdcfdfbfa1";

    EqualFiDrandRegistry private registry;
    address private poster = makeAddr("poster");

    function setUp() external {
        registry = new EqualFiDrandRegistry();
    }

    function test_unpostedRoundReturnsEmptyState() external view {
        assertFalse(registry.hasSig(VECTOR_ROUND));
        assertEq(registry.randomnessOf(VECTOR_ROUND), bytes32(0));
        assertEq(registry.postedAt(VECTOR_ROUND), 0);
    }

    function test_permissionlessPostStoresBeaconAndProvenance() external {
        vm.warp(1_800_000_000);
        bytes32 expectedRandomness =
            keccak256(abi.encodePacked(UNCOMPRESSED_SIGNATURE, VECTOR_ROUND));

        vm.expectEmit(true, true, true, true, address(registry));
        emit IEqualFiDrandRegistry.QuicknetSignaturePosted(
            VECTOR_ROUND, poster, expectedRandomness, COMPRESSED_SIGNATURE
        );

        vm.prank(poster);
        assertTrue(registry.postSig(VECTOR_ROUND, COMPRESSED_SIGNATURE));

        assertTrue(registry.hasSig(VECTOR_ROUND));
        assertEq(registry.randomnessOf(VECTOR_ROUND), expectedRandomness);
        assertEq(registry.postedAt(VECTOR_ROUND), 1_800_000_000);
    }

    function test_duplicateReturnsFalseWithoutVerificationOrMutation() external {
        vm.warp(1_800_000_000);
        assertTrue(registry.postSig(VECTOR_ROUND, COMPRESSED_SIGNATURE));

        bytes32 storedRandomness = registry.randomnessOf(VECTOR_ROUND);
        uint64 storedAt = registry.postedAt(VECTOR_ROUND);

        vm.warp(1_900_000_000);
        assertFalse(registry.postSig(VECTOR_ROUND, hex"deadbeef"));

        assertEq(registry.randomnessOf(VECTOR_ROUND), storedRandomness);
        assertEq(registry.postedAt(VECTOR_ROUND), storedAt);
    }

    function test_uncompressedProofStoresEquivalentRandomness() external {
        vm.warp(1_800_000_000);
        assertTrue(registry.postSig(VECTOR_ROUND, UNCOMPRESSED_SIGNATURE));

        assertEq(
            registry.randomnessOf(VECTOR_ROUND),
            keccak256(abi.encodePacked(UNCOMPRESSED_SIGNATURE, VECTOR_ROUND))
        );
    }

    function test_invalidProofLeavesRoundUnposted() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                QuicknetVerifier.InvalidQuicknetSignature.selector, VECTOR_ROUND + 1
            )
        );
        registry.postSig(VECTOR_ROUND + 1, COMPRESSED_SIGNATURE);

        assertFalse(registry.hasSig(VECTOR_ROUND + 1));
        assertEq(registry.randomnessOf(VECTOR_ROUND + 1), bytes32(0));
        assertEq(registry.postedAt(VECTOR_ROUND + 1), 0);
    }

    function test_zeroTimestampStillRecordsPresence() external {
        vm.warp(0);
        assertTrue(registry.postSig(VECTOR_ROUND, COMPRESSED_SIGNATURE));

        assertTrue(registry.hasSig(VECTOR_ROUND));
        assertEq(registry.postedAt(VECTOR_ROUND), 0);
        assertFalse(registry.postSig(VECTOR_ROUND, bytes("")));
    }

    function test_rejectsTimestampBeyondUint64() external {
        vm.warp(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                EqualFiDrandRegistry.BlockTimestampOutOfRange.selector,
                uint256(type(uint64).max) + 1
            )
        );
        registry.postSig(VECTOR_ROUND, COMPRESSED_SIGNATURE);

        assertFalse(registry.hasSig(VECTOR_ROUND));
    }
}
