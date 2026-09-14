// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { QuicknetVerifier } from "../src/libraries/QuicknetVerifier.sol";
import { QuicknetVerifierHarness } from "./helpers/QuicknetVerifierHarness.sol";

contract RevertingStaticTarget {
    fallback() external {
        revert();
    }
}

contract ShortReturnStaticTarget {
    fallback() external {
        assembly ("memory-safe") {
            mstore(0, 1)
            return(0, 31)
        }
    }
}

contract QuicknetAdversarialTest is Test {
    uint64 private constant VECTOR_ROUND = 20_791_007;
    bytes private constant COMPRESSED_SIGNATURE =
        hex"8d2c8bbc37170dbacc5e280a21d4e195cff5f32a19fd6a58633fa4e4670478b5fb39bc13dd8f8c4372c5a76191198ac5";

    QuicknetVerifierHarness private verifier;

    function setUp() external {
        verifier = new QuicknetVerifierHarness();
    }

    function test_rejectsCompressedEncodingWithoutCompressionFlag() external {
        bytes memory malformed = COMPRESSED_SIGNATURE;
        malformed[0] = bytes1(uint8(malformed[0]) & 0x7f);

        vm.expectRevert(QuicknetVerifier.InvalidCompressedEncoding.selector);
        verifier.decodeSignature(malformed);
    }

    function test_rejectsCompressedInfinity() external {
        bytes memory infinity = new bytes(48);
        infinity[0] = 0xc0;

        vm.expectRevert(QuicknetVerifier.PointAtInfinity.selector);
        verifier.decodeSignature(infinity);
    }

    function test_rejectsNonCanonicalCompressedX() external {
        bytes memory nonCanonical =
            hex"9a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab";

        vm.expectRevert(QuicknetVerifier.InvalidG1Point.selector);
        verifier.decodeSignature(nonCanonical);
    }

    function test_rejectsNonCanonicalUncompressedX() external {
        bytes memory nonCanonical = bytes.concat(
            hex"1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab",
            hex"0823ff37364b4060af65c7ec4dde05a428e4a444713680d95c34a4b109f112af1792643c742b75d85940c4bdcfdfbfa1"
        );

        vm.expectRevert(QuicknetVerifier.InvalidG1Point.selector);
        verifier.decodeSignature(nonCanonical);
    }

    function test_rejectsNonCanonicalUncompressedY() external {
        bytes memory nonCanonical = bytes.concat(
            hex"0d2c8bbc37170dbacc5e280a21d4e195cff5f32a19fd6a58633fa4e4670478b5fb39bc13dd8f8c4372c5a76191198ac5",
            hex"1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab"
        );

        vm.expectRevert(QuicknetVerifier.InvalidG1Point.selector);
        verifier.decodeSignature(nonCanonical);
    }

    function test_rejectsAlteredSignature() external {
        bytes memory altered = COMPRESSED_SIGNATURE;
        altered[47] = bytes1(uint8(altered[47]) ^ 0x01);

        vm.expectRevert();
        verifier.verifyAndNormalize(VECTOR_ROUND, altered);
    }

    function testFuzz_rejectsUnsupportedSignatureLengths(uint256 rawLength) external {
        uint256 length = bound(rawLength, 0, 160);
        vm.assume(length != 48 && length != 96);
        bytes memory malformed = new bytes(length);

        vm.expectRevert(
            abi.encodeWithSelector(QuicknetVerifier.UnsupportedSignatureLength.selector, length)
        );
        verifier.decodeSignature(malformed);
    }

    function test_checkedStaticcallRejectsCallFailure() external {
        RevertingStaticTarget target = new RevertingStaticTarget();
        uint256 targetAddress = uint256(uint160(address(target)));

        vm.expectRevert(
            abi.encodeWithSelector(QuicknetVerifier.PrecompileCallFailed.selector, targetAddress)
        );
        verifier.checkedStaticcall(targetAddress, bytes(""), 32);
    }

    function test_checkedStaticcallRejectsShortReturnData() external {
        ShortReturnStaticTarget target = new ShortReturnStaticTarget();
        uint256 targetAddress = uint256(uint160(address(target)));

        vm.expectRevert(
            abi.encodeWithSelector(
                QuicknetVerifier.InvalidPrecompileReturnData.selector, targetAddress, 31
            )
        );
        verifier.checkedStaticcall(targetAddress, bytes(""), 32);
    }
}
