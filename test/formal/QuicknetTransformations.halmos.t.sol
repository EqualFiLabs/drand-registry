// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import {
    QuicknetTransformationHarness
} from "../../formal/harness/QuicknetTransformationHarness.sol";

contract QuicknetTransformationsHalmosTest is Test {
    uint128 private constant FIELD_MODULUS_HI = 0x1a0111ea397fe69a4b1ba7b6434bacd7;
    uint256 private constant FIELD_MODULUS_LO =
        0x64774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab;
    uint128 private constant X_MASK = 0x1fffffffffffffffffffffffffffffff;

    bytes32 private constant QUICKNET_DST_HASH =
        0x506c45fcc1097216a58cc52cb771a3c6a8967abf4d42d2928827047c5412745e;
    bytes32 private constant QUICKNET_PUBLIC_KEY_HASH =
        0x27bd02e9bac7a070141898b500efbcb444d9b2718f06b286d2a2ce5aeb1440fa;

    QuicknetTransformationHarness private verifier;

    function setUp() public {
        verifier = new QuicknetTransformationHarness();
    }

    function check_validCompressedParsing(uint128 encodedHi, uint256 xLo) public view {
        vm.assume(encodedHi & (uint128(1) << 127) != 0);
        vm.assume(encodedHi & (uint128(1) << 126) == 0);
        uint128 expectedHi = encodedHi & X_MASK;
        vm.assume(verifier.isCanonicalFieldElement(expectedHi, xLo));

        (uint128 parsedHi, uint256 parsedLo, bool selectSmallerY) =
            verifier.parseCompressed(abi.encodePacked(encodedHi, xLo));

        assert(parsedHi == expectedHi);
        assert(parsedLo == xLo);
        assert(selectSmallerY == (encodedHi & (uint128(1) << 125) == 0));
    }

    function check_supportedSignatureLengths() public view {
        assert(verifier.compressedEncodingForLength(48));
        assert(!verifier.compressedEncodingForLength(96));
    }

    function check_unsupportedSignatureLengthsRevert(uint256 length) public view {
        vm.assume(length != 48 && length != 96);
        try verifier.compressedEncodingForLength(length) returns (bool) {
            assert(false);
        } catch { }
    }

    function check_missingCompressionFlagReverts(uint128 encodedHi, uint256 xLo) public view {
        vm.assume(encodedHi & (uint128(1) << 127) == 0);
        try verifier.parseCompressed(abi.encodePacked(encodedHi, xLo)) returns (
            uint128, uint256, bool
        ) {
            assert(false);
        } catch { }
    }

    function check_infinityFlagReverts(uint128 encodedHi, uint256 xLo) public view {
        encodedHi |= uint128(1) << 127;
        encodedHi |= uint128(1) << 126;
        try verifier.parseCompressed(abi.encodePacked(encodedHi, xLo)) returns (
            uint128, uint256, bool
        ) {
            assert(false);
        } catch { }
    }

    function check_nonCanonicalCompressedXReverts(uint256 xLo) public view {
        vm.assume(xLo >= FIELD_MODULUS_LO);
        uint128 encodedHi = FIELD_MODULUS_HI | (uint128(1) << 127);
        try verifier.parseCompressed(abi.encodePacked(encodedHi, xLo)) returns (
            uint128, uint256, bool
        ) {
            assert(false);
        } catch { }
    }

    function check_uncompressedDecodingRoundTrip(uint128 xHi, uint256 xLo, uint128 yHi, uint256 yLo)
        public
        view
    {
        vm.assume(verifier.isCanonicalFieldElement(xHi, xLo));
        vm.assume(verifier.isCanonicalFieldElement(yHi, yLo));
        vm.assume(xHi != 0 || xLo != 0 || yHi != 0 || yLo != 0);

        (uint128 decodedXHi, uint256 decodedXLo, uint128 decodedYHi, uint256 decodedYLo) =
            verifier.decodeUncompressed(abi.encodePacked(xHi, xLo, yHi, yLo));

        assert(decodedXHi == xHi);
        assert(decodedXLo == xLo);
        assert(decodedYHi == yHi);
        assert(decodedYLo == yLo);
        assert(
            verifier.normalizedPointHash(decodedXHi, decodedXLo, decodedYHi, decodedYLo)
                == verifier.normalizedPointHash(xHi, xLo, yHi, yLo)
        );
    }

    function check_decompressionSignSelection(uint128 yHi, uint256 yLo) public view {
        vm.assume(verifier.isCanonicalFieldElement(yHi, yLo));

        (uint128 smallerHi, uint256 smallerLo) = verifier.selectY(yHi, yLo, true);
        (uint128 largerHi, uint256 largerLo) = verifier.selectY(yHi, yLo, false);

        assert(smallerHi < largerHi || (smallerHi == largerHi && smallerLo <= largerLo));
        assert(verifier.isCanonicalFieldElement(smallerHi, smallerLo));
        assert(verifier.isCanonicalFieldElement(largerHi, largerLo));

        if (yHi == 0 && yLo == 0) {
            assert(smallerHi == 0 && smallerLo == 0);
            assert(largerHi == 0 && largerLo == 0);
        } else {
            uint256 summedLo;
            uint128 summedHi;
            unchecked {
                summedLo = smallerLo + largerLo;
                summedHi = smallerHi + largerHi;
                if (summedLo < smallerLo) summedHi += 1;
            }
            assert(summedHi == FIELD_MODULUS_HI);
            assert(summedLo == FIELD_MODULUS_LO);
        }
    }

    function check_curveConstantAddition(uint128 valueHi, uint256 valueLo) public view {
        vm.assume(verifier.isCanonicalFieldElement(valueHi, valueLo));
        (uint128 resultHi, uint256 resultLo) = verifier.addCurveB(valueHi, valueLo);

        unchecked {
            assert(resultLo == valueLo + 4);
            assert(resultHi == valueHi + (resultLo < valueLo ? 1 : 0));
        }
    }

    function check_quicknetTrustAnchorBinding() public view {
        assert(verifier.domainSeparationTagHash() == QUICKNET_DST_HASH);
        assert(verifier.publicKeyHash() == QUICKNET_PUBLIC_KEY_HASH);
    }

    function check_modExpCubeCalldata(uint128 baseHi, uint256 baseLo) public view {
        bytes memory input = verifier.modExpInput(abi.encode(uint256(baseHi), baseLo), hex"03");
        uint256 baseLength;
        uint256 exponentLength;
        uint256 modulusLength;
        uint256 encodedBaseHi;
        uint256 encodedBaseLo;
        uint256 encodedExponent;
        uint256 modulusHi;
        uint256 modulusLo;
        assembly ("memory-safe") {
            baseLength := mload(add(input, 0x20))
            exponentLength := mload(add(input, 0x40))
            modulusLength := mload(add(input, 0x60))
            encodedBaseHi := mload(add(input, 0x80))
            encodedBaseLo := mload(add(input, 0xa0))
            encodedExponent := byte(0, mload(add(input, 0xc0)))
            modulusHi := mload(add(input, 0xc1))
            modulusLo := mload(add(input, 0xe1))
        }

        assert(input.length == 225);
        assert(baseLength == 64);
        assert(exponentLength == 1);
        assert(modulusLength == 64);
        assert(encodedBaseHi == baseHi);
        assert(encodedBaseLo == baseLo);
        assert(encodedExponent == 3);
        assert(modulusHi == FIELD_MODULUS_HI);
        assert(modulusLo == FIELD_MODULUS_LO);
    }

    function check_precompileSuccessGate(uint256 target, uint256 expectedLength) public view {
        assert(verifier.validatePrecompileOutcome(target, true, expectedLength, expectedLength));
        assert(!verifier.decodePairingResult(0));
        assert(verifier.decodePairingResult(1));
    }

    function check_failedPrecompileReverts(
        uint256 target,
        uint256 actualLength,
        uint256 expectedLength
    ) public view {
        try verifier.validatePrecompileOutcome(target, false, actualLength, expectedLength) {
            assert(false);
        } catch { }
    }

    function check_wrongPrecompileLengthReverts(
        uint256 target,
        uint256 actualLength,
        uint256 expectedLength
    ) public view {
        vm.assume(actualLength != expectedLength);
        try verifier.validatePrecompileOutcome(target, true, actualLength, expectedLength) {
            assert(false);
        } catch { }
    }

    function check_invalidPairingResultReverts(uint256 result) public view {
        vm.assume(result > 1);
        try verifier.decodePairingResult(result) returns (bool) {
            assert(false);
        } catch { }
    }
}
