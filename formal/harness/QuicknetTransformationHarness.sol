// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { BLS2 } from "bls-solidity/libraries/BLS2.sol";
import { QuicknetVerifier } from "../../src/libraries/QuicknetVerifier.sol";

/// @notice Thin external wrappers around the exact production transformation code.
/// @dev No parsing, normalization, or precompile-layout logic is reimplemented here.
contract QuicknetTransformationHarness {
    function compressedEncodingForLength(uint256 length) external pure returns (bool) {
        return QuicknetVerifier.compressedEncodingForLength(length);
    }

    function parseCompressed(bytes calldata signature)
        external
        pure
        returns (uint128 xHi, uint256 parsedLo, bool selectSmallerY)
    {
        return QuicknetVerifier.parseCompressedSignature(signature);
    }

    function decodeUncompressed(bytes calldata signature)
        external
        pure
        returns (uint128, uint256, uint128, uint256)
    {
        BLS2.PointG1 memory point = QuicknetVerifier.decodeUncompressedSignature(signature);
        return (point.x_hi, point.x_lo, point.y_hi, point.y_lo);
    }

    function selectY(uint128 yHi, uint256 yLo, bool selectSmallerY)
        external
        pure
        returns (uint128 selectedHi, uint256 selectedLo)
    {
        return QuicknetVerifier.selectY(yHi, yLo, selectSmallerY);
    }

    function addCurveB(uint128 valueHi, uint256 valueLo)
        external
        pure
        returns (uint128 resultHi, uint256 resultLo)
    {
        return QuicknetVerifier.addCurveB(valueHi, valueLo);
    }

    function isCanonicalFieldElement(uint128 hi, uint256 lo) external pure returns (bool) {
        return QuicknetVerifier.isCanonicalFieldElement(hi, lo);
    }

    function normalizedPointHash(uint128 xHi, uint256 xLo, uint128 yHi, uint256 yLo)
        external
        pure
        returns (bytes32)
    {
        BLS2.PointG1 memory point = BLS2.PointG1(xHi, xLo, yHi, yLo);
        QuicknetVerifier.validateG1Point(point);
        return keccak256(BLS2.g1Marshal(point));
    }

    function domainSeparationTagHash() external pure returns (bytes32) {
        return keccak256(QuicknetVerifier.domainSeparationTag());
    }

    function publicKeyHash() external pure returns (bytes32) {
        return keccak256(BLS2.g2Marshal(QuicknetVerifier.publicKey()));
    }

    function modExpInput(bytes calldata base, bytes calldata exponent)
        external
        pure
        returns (bytes memory)
    {
        return QuicknetVerifier.modExpInput(base, exponent);
    }

    function g1AddInput(bytes calldata firstPoint, bytes calldata secondPoint)
        external
        pure
        returns (bytes memory)
    {
        return QuicknetVerifier.g1AddInput(firstPoint, secondPoint);
    }

    function pairingInput(BLS2.PointG1 calldata signature, BLS2.PointG1 calldata message)
        external
        pure
        returns (bytes memory)
    {
        return QuicknetVerifier.pairingInput(signature, QuicknetVerifier.publicKey(), message);
    }

    function validatePrecompileOutcome(
        uint256 target,
        bool success,
        uint256 actualLength,
        uint256 expectedLength
    ) external pure returns (bool) {
        QuicknetVerifier.validatePrecompileOutcome(target, success, actualLength, expectedLength);
        return true;
    }

    function decodePairingResult(uint256 result) external pure returns (bool) {
        return QuicknetVerifier.decodePairingResult(abi.encode(result));
    }
}
