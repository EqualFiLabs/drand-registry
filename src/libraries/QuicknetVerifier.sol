// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { BLS2 } from "bls-solidity/libraries/BLS2.sol";
import {
    BLS12_G1ADD,
    BLS12_MAP_FP_TO_G1,
    BLS12_PAIRING_CHECK,
    MODEXP_ADDRESS
} from "bls-solidity/libraries/Precompiles.sol";

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
    uint128 private constant SQRT_EXPONENT_HI = 0x0680447a8e5ff9a692c6e9ed90d2eb35;
    uint256 private constant SQRT_EXPONENT_LO =
        0xd91dd2e13ce144afd9cc34a83dac3d8907aaffffac54ffffee7fbfffffffeaab;

    uint128 private constant NEGATIVE_G2_X0_HI = 0x024aa2b2f08f0a91260805272dc51051;
    uint256 private constant NEGATIVE_G2_X0_LO =
        0xc6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8;
    uint128 private constant NEGATIVE_G2_X1_HI = 0x13e02b6052719f607dacd3a088274f65;
    uint256 private constant NEGATIVE_G2_X1_LO =
        0x596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e;
    uint128 private constant NEGATIVE_G2_Y0_HI = 0x0d1b3cc2c7027888be51d9ef691d77bc;
    uint256 private constant NEGATIVE_G2_Y0_LO =
        0xb679afda66c73f17f9ee3837a55024f78c71363275a75d75d86bab79f74782aa;
    uint128 private constant NEGATIVE_G2_Y1_HI = 0x13fa4d4a0ad8b1ce186ed5061789213d;
    uint256 private constant NEGATIVE_G2_Y1_LO =
        0x993923066dddaf1040bc3ff59f825c78df74f2d75467e25e0f55f8a00fa030ed;

    error InvalidQuicknetRound(uint64 round);
    error NoFutureQuicknetRound(uint256 timestamp);
    error UnsupportedSignatureLength(uint256 length);
    error InvalidCompressedEncoding();
    error PointAtInfinity();
    error InvalidG1Point();
    error InvalidQuicknetSignature(uint64 round);
    error PrecompileCallFailed(uint256 precompile);
    error InvalidPrecompileReturnData(uint256 precompile, uint256 actualLength);
    error InvalidPrecompileResult(uint256 precompile, uint256 result);

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

        BLS2.PointG1 memory signaturePoint = decodeSignature(signature);
        bytes32 digest = messageHash(round);
        BLS2.PointG1 memory messagePoint = hashMessageToPoint(digest);
        if (!_verifyPairing(signaturePoint, publicKey(), messagePoint)) {
            revert InvalidQuicknetSignature(round);
        }

        canonicalSignature = BLS2.g1Marshal(signaturePoint);
        randomness = keccak256(abi.encodePacked(canonicalSignature, round));
    }

    function messageHash(uint64 round) internal pure returns (bytes32) {
        if (round == 0) revert InvalidQuicknetRound(round);
        return sha256(abi.encodePacked(round));
    }

    function decodeSignature(bytes calldata signature)
        internal
        view
        returns (BLS2.PointG1 memory point)
    {
        if (signature.length == COMPRESSED_SIGNATURE_LENGTH) {
            point = _decodeCompressedSignature(signature);
        } else if (signature.length == UNCOMPRESSED_SIGNATURE_LENGTH) {
            point = BLS2.g1Unmarshal(signature);
        } else {
            revert UnsupportedSignatureLength(signature.length);
        }

        _validateG1Point(point);
    }

    function hashMessageToPoint(bytes32 digest) internal view returns (BLS2.PointG1 memory point) {
        bytes memory uniform = BLS2.expandMsg(bytes(DST), abi.encodePacked(digest), 128);
        bytes memory firstField = _uniformChunk(uniform, 0);
        bytes memory secondField = _uniformChunk(uniform, 64);

        bytes memory reducedFirst = _modExp(firstField, hex"01");
        bytes memory reducedSecond = _modExp(secondField, hex"01");
        bytes memory firstPoint = checkedStaticcall(BLS12_MAP_FP_TO_G1, reducedFirst, 128);
        bytes memory secondPoint = checkedStaticcall(BLS12_MAP_FP_TO_G1, reducedSecond, 128);
        bytes memory encodedPoint =
            checkedStaticcall(BLS12_G1ADD, bytes.concat(firstPoint, secondPoint), 128);

        point = _decodePrecompileG1(encodedPoint);
        _validateG1Point(point);
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

    /// @notice Executes a static call and requires the exact expected return-data length.
    /// @dev Internal visibility permits direct failure-path testing without replacing precompiles.
    function checkedStaticcall(uint256 target, bytes memory input, uint256 outputLength)
        internal
        view
        returns (bytes memory output)
    {
        output = new bytes(outputLength);
        bool success;
        uint256 actualLength;
        assembly ("memory-safe") {
            success := staticcall(
                gas(),
                target,
                add(input, 0x20),
                mload(input),
                add(output, 0x20),
                outputLength
            )
            actualLength := returndatasize()
        }

        if (!success) revert PrecompileCallFailed(target);
        if (actualLength != outputLength) {
            revert InvalidPrecompileReturnData(target, actualLength);
        }
    }

    function _decodeCompressedSignature(bytes calldata signature)
        private
        view
        returns (BLS2.PointG1 memory point)
    {
        uint128 xHi;
        uint256 xLo;
        assembly ("memory-safe") {
            xHi := shr(128, calldataload(signature.offset))
            xLo := calldataload(add(signature.offset, 16))
        }

        // Shifting a uint128 by 120 leaves exactly one byte.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 flags = uint8(xHi >> 120);
        if (flags & 0x80 == 0) revert InvalidCompressedEncoding();
        if (flags & 0x40 != 0) revert PointAtInfinity();
        bool selectLargerY = flags & 0x20 == 0;

        xHi &= 0x1fffffffffffffffffffffffffffffff;
        if (!_isCanonicalFieldElement(xHi, xLo)) revert InvalidG1Point();

        bytes memory x = abi.encodePacked(uint256(xHi), xLo);
        (uint128 rhsHi, uint256 rhsLo) = _decodeFieldElement(_modExp(x, hex"03"));
        unchecked {
            uint256 priorLo = rhsLo;
            rhsLo += 4;
            if (rhsLo < priorLo) rhsHi += 1;
        }

        bytes memory exponent = abi.encodePacked(uint256(SQRT_EXPONENT_HI), SQRT_EXPONENT_LO);
        (uint128 yHi, uint256 yLo) =
            _decodeFieldElement(_modExp(abi.encodePacked(uint256(rhsHi), rhsLo), exponent));

        uint128 alternateYHi = FIELD_MODULUS_HI - yHi;
        uint256 alternateYLo;
        unchecked {
            alternateYLo = FIELD_MODULUS_LO - yLo;
            if (alternateYLo > FIELD_MODULUS_LO) alternateYHi -= 1;
        }

        bool yIsLarger = yHi > alternateYHi || (yHi == alternateYHi && yLo > alternateYLo);
        if (selectLargerY == yIsLarger) {
            yHi = alternateYHi;
            yLo = alternateYLo;
        }

        point = BLS2.PointG1(xHi, xLo, yHi, yLo);
    }

    function _verifyPairing(
        BLS2.PointG1 memory signature,
        BLS2.PointG2 memory pubkey,
        BLS2.PointG1 memory message
    ) private view returns (bool) {
        uint256[24] memory operands = [
            signature.x_hi,
            signature.x_lo,
            signature.y_hi,
            signature.y_lo,
            NEGATIVE_G2_X0_HI,
            NEGATIVE_G2_X0_LO,
            NEGATIVE_G2_X1_HI,
            NEGATIVE_G2_X1_LO,
            NEGATIVE_G2_Y0_HI,
            NEGATIVE_G2_Y0_LO,
            NEGATIVE_G2_Y1_HI,
            NEGATIVE_G2_Y1_LO,
            message.x_hi,
            message.x_lo,
            message.y_hi,
            message.y_lo,
            pubkey.x0_hi,
            pubkey.x0_lo,
            pubkey.x1_hi,
            pubkey.x1_lo,
            pubkey.y0_hi,
            pubkey.y0_lo,
            pubkey.y1_hi,
            pubkey.y1_lo
        ];
        bytes memory output = checkedStaticcall(BLS12_PAIRING_CHECK, abi.encode(operands), 32);
        uint256 result;
        assembly ("memory-safe") {
            result := mload(add(output, 0x20))
        }
        if (result > 1) revert InvalidPrecompileResult(BLS12_PAIRING_CHECK, result);
        return result == 1;
    }

    function _modExp(bytes memory base, bytes memory exponent) private view returns (bytes memory) {
        bytes memory input = bytes.concat(
            abi.encode(uint256(64), uint256(exponent.length), uint256(64)),
            base,
            exponent,
            abi.encode(uint256(FIELD_MODULUS_HI), FIELD_MODULUS_LO)
        );
        return checkedStaticcall(MODEXP_ADDRESS, input, 64);
    }

    function _uniformChunk(bytes memory uniform, uint256 offset)
        private
        pure
        returns (bytes memory chunk)
    {
        chunk = new bytes(64);
        assembly ("memory-safe") {
            mstore(add(chunk, 0x20), mload(add(add(uniform, 0x20), offset)))
            mstore(add(chunk, 0x40), mload(add(add(uniform, 0x40), offset)))
        }
    }

    function _decodeFieldElement(bytes memory encoded)
        private
        pure
        returns (uint128 hi, uint256 lo)
    {
        uint256 hiWord;
        assembly ("memory-safe") {
            hiWord := mload(add(encoded, 0x20))
            lo := mload(add(encoded, 0x40))
        }
        if (hiWord > type(uint128).max) revert InvalidG1Point();
        // The explicit bound above proves hiWord is within uint128.
        // forge-lint: disable-next-line(unsafe-typecast)
        hi = uint128(hiWord);
    }

    function _decodePrecompileG1(bytes memory encoded)
        private
        pure
        returns (BLS2.PointG1 memory point)
    {
        uint256 xHiWord;
        uint256 xLo;
        uint256 yHiWord;
        uint256 yLo;
        assembly ("memory-safe") {
            xHiWord := mload(add(encoded, 0x20))
            xLo := mload(add(encoded, 0x40))
            yHiWord := mload(add(encoded, 0x60))
            yLo := mload(add(encoded, 0x80))
        }
        if (xHiWord > type(uint128).max || yHiWord > type(uint128).max) {
            revert InvalidG1Point();
        }
        // The explicit bounds above prove both high limbs are within uint128.
        // forge-lint: disable-next-line(unsafe-typecast)
        point = BLS2.PointG1(uint128(xHiWord), xLo, uint128(yHiWord), yLo);
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
