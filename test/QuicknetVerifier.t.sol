// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { QuicknetVerifier } from "../src/libraries/QuicknetVerifier.sol";
import { QuicknetVerifierHarness } from "./helpers/QuicknetVerifierHarness.sol";

contract QuicknetVerifierTest is Test {
    uint64 private constant VECTOR_ROUND = 20_791_007;
    uint64 private constant GENESIS_TIMESTAMP = 1_692_803_367;
    uint64 private constant PERIOD = 3;

    bytes private constant COMPRESSED_SIGNATURE =
        hex"8d2c8bbc37170dbacc5e280a21d4e195cff5f32a19fd6a58633fa4e4670478b5fb39bc13dd8f8c4372c5a76191198ac5";
    bytes private constant UNCOMPRESSED_SIGNATURE =
        hex"0d2c8bbc37170dbacc5e280a21d4e195cff5f32a19fd6a58633fa4e4670478b5fb39bc13dd8f8c4372c5a76191198ac50823ff37364b4060af65c7ec4dde05a428e4a444713680d95c34a4b109f112af1792643c742b75d85940c4bdcfdfbfa1";
    bytes private constant QUICKNET_PUBLIC_KEY =
        hex"03cf0f2896adee7eb8b5f01fcad3912212c437e0073e911fb90022d3e760183c8c4b450b6a0a6c3ac6a5776a2d1064510d1fec758c921cc22b0e17e63aaf4bcb5ed66304de9cf809bd274ca73bab4af5a6e9c76a4bc09e76eae8991ef5ece45a01a714f2edb74119a2f2b0d5a7c75ba902d163700a61bc224ededd8e63aef7be1aaf8e93d7a9718b047ccddb3eb5d68b0e5db2b6bfbb01c867749cadffca88b36c24f3012ba09fc4d3022c5c37dce0f977d3adb5d183c7477c442b1f04515273";

    QuicknetVerifierHarness private verifier;

    function setUp() external {
        verifier = new QuicknetVerifierHarness();
    }

    function test_constantsMatchQuicknetTrustAnchor() external view {
        assertEq(verifier.period(), PERIOD);
        assertEq(verifier.genesisTimestamp(), GENESIS_TIMESTAMP);
        assertEq(verifier.domainSeparationTag(), "BLS_SIG_BLS12381G1_XMD:SHA-256_SSWU_RO_NUL_");
        assertEq(verifier.publicKey(), QUICKNET_PUBLIC_KEY);
    }

    function test_roundTimeRejectsZero() external {
        vm.expectRevert(abi.encodeWithSelector(QuicknetVerifier.InvalidQuicknetRound.selector, 0));
        verifier.roundTime(0);
    }

    function test_roundTimeHandlesFirstAndLastRepresentableRounds() external view {
        assertEq(verifier.roundTime(1), GENESIS_TIMESTAMP);

        uint64 maxRound = verifier.maxRound();
        uint64 maxRoundTime = verifier.roundTime(maxRound);
        assertEq(maxRoundTime, type(uint64).max);
    }

    function test_roundTimeRejectsUnrepresentableRound() external {
        uint64 invalidRound = verifier.maxRound() + 1;
        vm.expectRevert(
            abi.encodeWithSelector(QuicknetVerifier.InvalidQuicknetRound.selector, invalidRound)
        );
        verifier.roundTime(invalidRound);
    }

    function test_firstRoundAfterHandlesGenesisBoundaries() external view {
        assertEq(verifier.firstRoundAfter(0), 1);
        assertEq(verifier.firstRoundAfter(GENESIS_TIMESTAMP - 1), 1);
        assertEq(verifier.firstRoundAfter(GENESIS_TIMESTAMP), 2);
        assertEq(verifier.firstRoundAfter(GENESIS_TIMESTAMP + PERIOD - 1), 2);
        assertEq(verifier.firstRoundAfter(GENESIS_TIMESTAMP + PERIOD), 3);
    }

    function test_firstRoundAfterRejectsTimestampAtLastRepresentableRound() external {
        uint64 maxRoundTime = verifier.roundTime(verifier.maxRound());
        vm.expectRevert(
            abi.encodeWithSelector(
                QuicknetVerifier.NoFutureQuicknetRound.selector, uint256(maxRoundTime)
            )
        );
        verifier.firstRoundAfter(maxRoundTime);
    }

    function test_firstRoundAfterRejectsUint256Maximum() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                QuicknetVerifier.NoFutureQuicknetRound.selector, type(uint256).max
            )
        );
        verifier.firstRoundAfter(type(uint256).max);
    }

    function test_compressedAndUncompressedSignaturesNormalizeIdentically() external view {
        (bytes32 compressedRandomness, bytes memory compressedCanonical) =
            verifier.verifyAndNormalize(VECTOR_ROUND, COMPRESSED_SIGNATURE);
        (bytes32 uncompressedRandomness, bytes memory uncompressedCanonical) =
            verifier.verifyAndNormalize(VECTOR_ROUND, UNCOMPRESSED_SIGNATURE);

        assertEq(compressedCanonical, UNCOMPRESSED_SIGNATURE);
        assertEq(uncompressedCanonical, UNCOMPRESSED_SIGNATURE);
        assertEq(compressedRandomness, uncompressedRandomness);
        assertEq(
            compressedRandomness, keccak256(abi.encodePacked(UNCOMPRESSED_SIGNATURE, VECTOR_ROUND))
        );
    }

    function test_rejectsUnsupportedSignatureLength() external {
        bytes memory malformed = new bytes(47);
        vm.expectRevert(
            abi.encodeWithSelector(QuicknetVerifier.UnsupportedSignatureLength.selector, 47)
        );
        verifier.verifyAndNormalize(VECTOR_ROUND, malformed);
    }

    function test_rejectsSignatureForWrongRound() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                QuicknetVerifier.InvalidQuicknetSignature.selector, VECTOR_ROUND + 1
            )
        );
        verifier.verifyAndNormalize(VECTOR_ROUND + 1, COMPRESSED_SIGNATURE);
    }

    function test_rejectsUncompressedInfinity() external {
        vm.expectRevert(QuicknetVerifier.InvalidG1Point.selector);
        verifier.verifyAndNormalize(VECTOR_ROUND, new bytes(96));
    }
}
