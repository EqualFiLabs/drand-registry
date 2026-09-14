// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { BLS2 } from "bls-solidity/libraries/BLS2.sol";
import {
    QuicknetTransformationHarness
} from "../../formal/harness/QuicknetTransformationHarness.sol";

contract QuicknetTransformationsHalmosTest is Test {
    uint128 private constant FIELD_MODULUS_HI = 0x1a0111ea397fe69a4b1ba7b6434bacd7;
    uint256 private constant FIELD_MODULUS_LO =
        0x64774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab;
    uint128 private constant X_MASK = 0x1fffffffffffffffffffffffffffffff;
    uint128 private constant SQRT_EXPONENT_HI = 0x0680447a8e5ff9a692c6e9ed90d2eb35;
    uint256 private constant SQRT_EXPONENT_LO =
        0xd91dd2e13ce144afd9cc34a83dac3d8907aaffffac54ffffee7fbfffffffeaab;

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

    function check_equivalentEncodingsNormalizeIdentically(
        uint128 encodedHi,
        uint256 xLo,
        uint128 rootHi,
        uint256 rootLo
    ) public view {
        vm.assume(encodedHi & (uint128(1) << 127) != 0);
        vm.assume(encodedHi & (uint128(1) << 126) == 0);
        uint128 expectedXHi = encodedHi & X_MASK;
        vm.assume(verifier.isCanonicalFieldElement(expectedXHi, xLo));
        vm.assume(verifier.isCanonicalFieldElement(rootHi, rootLo));

        (uint128 parsedXHi, uint256 parsedXLo, bool selectSmallerY) =
            verifier.parseCompressed(abi.encodePacked(encodedHi, xLo));
        (uint128 selectedYHi, uint256 selectedYLo) =
            verifier.selectY(rootHi, rootLo, selectSmallerY);
        vm.assume(parsedXHi != 0 || parsedXLo != 0 || selectedYHi != 0 || selectedYLo != 0);

        (uint128 uxHi, uint256 uxLo, uint128 uyHi, uint256 uyLo) = verifier.decodeUncompressed(
            abi.encodePacked(parsedXHi, parsedXLo, selectedYHi, selectedYLo)
        );
        assert(
            verifier.normalizedPointHash(parsedXHi, parsedXLo, selectedYHi, selectedYLo)
                == verifier.normalizedPointHash(uxHi, uxLo, uyHi, uyLo)
        );
    }

    function check_uncompressedInfinityReverts() public view {
        try verifier.decodeUncompressed(new bytes(96)) returns (
            uint128, uint256, uint128, uint256
        ) {
            assert(false);
        } catch { }
    }

    function check_nonCanonicalUncompressedXReverts(uint256 xLo) public view {
        vm.assume(xLo >= FIELD_MODULUS_LO);
        bytes memory signature = abi.encodePacked(FIELD_MODULUS_HI, xLo, uint128(0), uint256(1));
        try verifier.decodeUncompressed(signature) returns (uint128, uint256, uint128, uint256) {
            assert(false);
        } catch { }
    }

    function check_nonCanonicalUncompressedYReverts(uint256 yLo) public view {
        vm.assume(yLo >= FIELD_MODULUS_LO);
        bytes memory signature = abi.encodePacked(uint128(0), uint256(1), FIELD_MODULUS_HI, yLo);
        try verifier.decodeUncompressed(signature) returns (uint128, uint256, uint128, uint256) {
            assert(false);
        } catch { }
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

    function check_modExpSquareRootCalldata(uint128 baseHi, uint256 baseLo) public view {
        bytes memory input = verifier.modExpInput(
            abi.encode(uint256(baseHi), baseLo),
            abi.encode(uint256(SQRT_EXPONENT_HI), SQRT_EXPONENT_LO)
        );
        uint256 baseLength;
        uint256 exponentLength;
        uint256 modulusLength;
        uint256 encodedBaseHi;
        uint256 encodedBaseLo;
        uint256 exponentHi;
        uint256 exponentLo;
        uint256 modulusHi;
        uint256 modulusLo;
        assembly ("memory-safe") {
            baseLength := mload(add(input, 0x20))
            exponentLength := mload(add(input, 0x40))
            modulusLength := mload(add(input, 0x60))
            encodedBaseHi := mload(add(input, 0x80))
            encodedBaseLo := mload(add(input, 0xa0))
            exponentHi := mload(add(input, 0xc0))
            exponentLo := mload(add(input, 0xe0))
            modulusHi := mload(add(input, 0x100))
            modulusLo := mload(add(input, 0x120))
        }

        assert(input.length == 288);
        assert(baseLength == 64);
        assert(exponentLength == 64);
        assert(modulusLength == 64);
        assert(encodedBaseHi == baseHi);
        assert(encodedBaseLo == baseLo);
        assert(exponentHi == SQRT_EXPONENT_HI);
        assert(exponentLo == SQRT_EXPONENT_LO);
        assert(modulusHi == FIELD_MODULUS_HI);
        assert(modulusLo == FIELD_MODULUS_LO);
    }

    function check_g1AdditionCalldata(
        uint256 firstXHi,
        uint256 firstXLo,
        uint256 firstYHi,
        uint256 firstYLo,
        uint256 secondXHi,
        uint256 secondXLo,
        uint256 secondYHi,
        uint256 secondYLo
    ) public view {
        bytes memory input = verifier.g1AddInput(
            abi.encode(firstXHi, firstXLo, firstYHi, firstYLo),
            abi.encode(secondXHi, secondXLo, secondYHi, secondYLo)
        );
        assert(input.length == 256);
        assert(
            keccak256(input)
                == keccak256(
                    abi.encode(
                        firstXHi,
                        firstXLo,
                        firstYHi,
                        firstYLo,
                        secondXHi,
                        secondXLo,
                        secondYHi,
                        secondYLo
                    )
                )
        );
    }

    function check_pairingPointCalldata(
        uint128 signatureXHi,
        uint256 signatureYLo,
        uint128 messageXHi,
        uint256 messageYLo
    ) public view {
        BLS2.PointG1 memory signature = BLS2.PointG1(signatureXHi, 0, 0, signatureYLo);
        BLS2.PointG1 memory message = BLS2.PointG1(messageXHi, 0, 0, messageYLo);
        bytes memory input = verifier.pairingInput(signature, message);

        uint256 firstSignatureWord;
        uint256 lastSignatureWord;
        uint256 firstMessageWord;
        uint256 lastMessageWord;
        assembly ("memory-safe") {
            firstSignatureWord := mload(add(input, 0x20))
            lastSignatureWord := mload(add(input, 0x80))
            firstMessageWord := mload(add(input, 0x1a0))
            lastMessageWord := mload(add(input, 0x200))
        }

        assert(input.length == 768);
        assert(firstSignatureWord == signatureXHi);
        assert(lastSignatureWord == signatureYLo);
        assert(firstMessageWord == messageXHi);
        assert(lastMessageWord == messageYLo);
    }

    function check_pairingTrustAnchorCalldata() public view {
        BLS2.PointG1 memory emptyPoint = BLS2.PointG1(0, 0, 0, 0);
        bytes memory input = verifier.pairingInput(emptyPoint, emptyPoint);
        uint256 firstNegativeGeneratorWord;
        uint256 lastNegativeGeneratorWord;
        uint256 firstPublicKeyWord;
        uint256 lastPublicKeyWord;
        assembly ("memory-safe") {
            firstNegativeGeneratorWord := mload(add(input, 0xa0))
            lastNegativeGeneratorWord := mload(add(input, 0x180))
            firstPublicKeyWord := mload(add(input, 0x220))
            lastPublicKeyWord := mload(add(input, 0x300))
        }

        assert(input.length == 768);
        assert(firstNegativeGeneratorWord == 0x024aa2b2f08f0a91260805272dc51051);
        assert(
            lastNegativeGeneratorWord
                == 0x993923066dddaf1040bc3ff59f825c78df74f2d75467e25e0f55f8a00fa030ed
        );
        assert(firstPublicKeyWord == 0x0d1fec758c921cc22b0e17e63aaf4bcb);
        assert(
            lastPublicKeyWord == 0x02d163700a61bc224ededd8e63aef7be1aaf8e93d7a9718b047ccddb3eb5d68b
        );
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
