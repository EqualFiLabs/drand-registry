// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { BLS2 } from "bls-solidity/libraries/BLS2.sol";

/// @title drand Quicknet verification
/// @notice Binds supported signature encodings to the immutable Quicknet trust anchor.
library QuicknetVerifier {
    uint64 internal constant PERIOD = 3;
    uint64 internal constant GENESIS_TIMESTAMP = 1_692_803_367;
    uint64 internal constant MAX_ROUND = 6_148_914_690_672_249_417;

    uint256 internal constant COMPRESSED_SIGNATURE_LENGTH = 48;
    uint256 internal constant UNCOMPRESSED_SIGNATURE_LENGTH = 96;

    string internal constant DST = "BLS_SIG_BLS12381G1_XMD:SHA-256_SSWU_RO_NUL_";

    uint128 private constant FIELD_MODULUS_HI = 0x1a0111ea397fe69a4b1ba7b6434bacd7;
    uint256 private constant FIELD_MODULUS_LO =
        0x64774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab;

    error InvalidQuicknetRound(uint64 round);
    error NoFutureQuicknetRound(uint256 timestamp);
    error UnsupportedSignatureLength(uint256 length);
    error InvalidG1Point();
    error InvalidQuicknetSignature(uint64 round);

    /// @notice Returns the scheduled Unix timestamp for a representable Quicknet round.
    function roundTime(uint64 round) internal pure returns (uint64 timestamp) {
        if (round == 0 || round > MAX_ROUND) revert InvalidQuicknetRound(round);

        uint256 scheduled = uint256(GENESIS_TIMESTAMP) + (uint256(round) - 1) * uint256(PERIOD);
        // The MAX_ROUND guard proves scheduled is within uint64.
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint64(scheduled);
    }

    /// @notice Returns the minimal representable Quicknet round strictly after `timestamp`.
    function firstRoundAfter(uint256 timestamp) internal pure returns (uint64 round) {
        if (timestamp < GENESIS_TIMESTAMP) return 1;

        uint256 candidate = (timestamp - GENESIS_TIMESTAMP) / PERIOD + 2;
        if (candidate > MAX_ROUND) revert NoFutureQuicknetRound(timestamp);
        // The MAX_ROUND guard proves candidate is within uint64.
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint64(candidate);
    }

    /// @notice Verifies either supported signature encoding and derives canonical randomness.
    /// @dev Randomness commits to the normalized 96-byte point and exact uint64 round.
    function verifyAndNormalize(uint64 round, bytes calldata signature)
        internal
        view
        returns (bytes32 randomness, bytes memory canonicalSignature)
    {
        if (round == 0) revert InvalidQuicknetRound(round);

        BLS2.PointG1 memory signaturePoint;
        if (signature.length == COMPRESSED_SIGNATURE_LENGTH) {
            signaturePoint = BLS2.g1UnmarshalCompressed(signature);
        } else if (signature.length == UNCOMPRESSED_SIGNATURE_LENGTH) {
            signaturePoint = BLS2.g1Unmarshal(signature);
        } else {
            revert UnsupportedSignatureLength(signature.length);
        }

        _validateG1Point(signaturePoint);

        bytes32 messageHash = sha256(abi.encodePacked(round));
        BLS2.PointG1 memory messagePoint =
            BLS2.hashToPoint(bytes(DST), abi.encodePacked(messageHash));
        (bool pairingSuccess, bool callSuccess) =
            BLS2.verifySingle(signaturePoint, publicKey(), messagePoint);
        if (!callSuccess || !pairingSuccess) revert InvalidQuicknetSignature(round);

        canonicalSignature = BLS2.g1Marshal(signaturePoint);
        randomness = keccak256(abi.encodePacked(canonicalSignature, round));
    }

    /// @notice Returns the immutable Quicknet G2 public key.
    function publicKey() internal pure returns (BLS2.PointG2 memory) {
        return BLS2.PointG2(
            0x03cf0f2896adee7eb8b5f01fcad39122,
            0x12c437e0073e911fb90022d3e760183c8c4b450b6a0a6c3ac6a5776a2d106451,
            0x0d1fec758c921cc22b0e17e63aaf4bcb,
            0x5ed66304de9cf809bd274ca73bab4af5a6e9c76a4bc09e76eae8991ef5ece45a,
            0x01a714f2edb74119a2f2b0d5a7c75ba9,
            0x02d163700a61bc224ededd8e63aef7be1aaf8e93d7a9718b047ccddb3eb5d68b,
            0x0e5db2b6bfbb01c867749cadffca88b3,
            0x6c24f3012ba09fc4d3022c5c37dce0f977d3adb5d183c7477c442b1f04515273
        );
    }

    function _validateG1Point(BLS2.PointG1 memory point) private pure {
        if (
            (point.x_hi == 0 && point.x_lo == 0 && point.y_hi == 0 && point.y_lo == 0)
                || !_isCanonicalFieldElement(point.x_hi, point.x_lo)
                || !_isCanonicalFieldElement(point.y_hi, point.y_lo)
        ) {
            revert InvalidG1Point();
        }
    }

    function _isCanonicalFieldElement(uint128 hi, uint256 lo) private pure returns (bool) {
        return hi < FIELD_MODULUS_HI || (hi == FIELD_MODULUS_HI && lo < FIELD_MODULUS_LO);
    }
}
