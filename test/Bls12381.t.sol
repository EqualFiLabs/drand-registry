// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { Test } from "forge-std/Test.sol";
import { Bls12381 } from "../src/libraries/Bls12381.sol";
import { QuicknetVerifier } from "../src/libraries/QuicknetVerifier.sol";

contract Bls12381Test is Test {
    // Golden outputs use an independent RFC 9380 XMD-SHA256 calculation, not this helper.
    function test_expandZeroDigest() external pure {
        assertEq(
            Bls12381.expandMsg(bytes(QuicknetVerifier.DST), abi.encodePacked(bytes32(0)), 128),
            hex"5c8026ee5bee3ce556932e6c2a99d875f2ba983b2a2d4251d655a2458b6b1531bf2b69f193a6043cba2db685d3cd22fb39e914855344bfd8a54fbda7b6260aca82d57fa9721a99cd98d5cc2b6367ad28b8d38b56b138b3e60a4bb3790a7ef3f5aec5a48e9660a6d4349dd7fd66bba47dbfc27d95922d9bf8515a89ea12dbfd2b"
        );
    }

    function test_expandQuicknetVectorDigest() external pure {
        bytes32 digest = sha256(abi.encodePacked(uint64(20_791_007)));
        assertEq(
            Bls12381.expandMsg(bytes(QuicknetVerifier.DST), abi.encodePacked(digest), 128),
            hex"1820f4deda5998429862f825a45e6f02a1d5eafe6e723026cf1e5d30b855322d471fd726c71b0aefaebf8d716ca392962bf978d6abc8842b3bd4bd999cda39704d9609dae6b706fc68775edb3419f711afa939d0742cc7d797c9265ac0ca24fed047a07cd4d96dfbca1de663bfa5a6da6cfaf8c8857db6f851dae4ffbea783c2"
        );
    }

    function test_rejectsOversizedDomain() external {
        bytes memory domain = new bytes(256);
        vm.expectRevert(abi.encodeWithSelector(Bls12381.InvalidDSTLength.selector, domain));
        this.expand(domain, bytes32(0));
    }

    function testFuzz_marshalMatchesPackedCoordinates(
        uint128 xHi,
        uint256 xLo,
        uint128 yHi,
        uint256 yLo
    ) external pure {
        bytes memory encoded = Bls12381.g1Marshal(Bls12381.PointG1(xHi, xLo, yHi, yLo));
        assertEq(encoded.length, 96);
        assertEq(encoded, abi.encodePacked(xHi, xLo, yHi, yLo));
    }

    function expand(bytes calldata domain, bytes32 digest) external pure returns (bytes memory) {
        return Bls12381.expandMsg(domain, abi.encodePacked(digest), 128);
    }
}
