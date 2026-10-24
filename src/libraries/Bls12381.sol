// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Randamu
pragma solidity 0.8.30;

// Extracted from randa-mu/bls-solidity at 11af179a8287d978659aae07adb66aa60f64b8a6.
// See docs/dependencies.md and licenses/bls-solidity-MIT.txt for provenance and license.

uint256 constant MODEXP_ADDRESS = 5;
uint256 constant BLS12_G1ADD = 0x0b;
uint256 constant BLS12_PAIRING_CHECK = 0x0f;
uint256 constant BLS12_MAP_FP_TO_G1 = 0x10;

/// @notice The BLS12-381 data and byte helpers used by the Quicknet verifier.
/// @dev Function bodies and point layouts preserve the pinned upstream implementation.
///      Production uses expandMsg only with the fixed Quicknet DST and 128-byte output.
library Bls12381 {
    struct PointG1 {
        uint128 x_hi;
        uint256 x_lo;
        uint128 y_hi;
        uint256 y_lo;
    }

    struct PointG2 {
        uint128 x1_hi;
        uint256 x1_lo;
        uint128 x0_hi;
        uint256 x0_lo;
        uint128 y1_hi;
        uint256 y1_lo;
        uint128 y0_hi;
        uint256 y0_lo;
    }

    error InvalidDSTLength(bytes dst);

    function g1Marshal(PointG1 memory point) internal pure returns (bytes memory) {
        bytes memory m = new bytes(96);
        uint256 x_hi = point.x_hi;
        uint256 x_lo = point.x_lo;
        uint256 y_hi = point.y_hi;
        uint256 y_lo = point.y_lo;

        assembly {
            mstore(add(m, 0x20), shl(128, x_hi))
            mstore(add(m, 0x30), x_lo)
            mstore(add(m, 0x50), shl(128, y_hi))
            mstore(add(m, 0x60), y_lo)
        }

        return m;
    }

    function expandMsg(bytes memory DST, bytes memory message, uint8 n_bytes)
        internal
        pure
        returns (bytes memory)
    {
        uint256 domainLen = DST.length;
        if (domainLen > 255) {
            revert InvalidDSTLength(DST);
        }
        bytes memory zpad = new bytes(64);
        bytes memory b_0 =
            abi.encodePacked(zpad, message, uint8(0), n_bytes, uint8(0), DST, uint8(domainLen));
        bytes32 b0 = sha256(b_0);

        bytes memory b_i = abi.encodePacked(b0, uint8(1), DST, uint8(domainLen));
        bytes32 bi = sha256(b_i);
        bytes memory out = new bytes(n_bytes);
        uint256 ell = (n_bytes + uint256(31)) >> 5;
        for (uint256 i = 1; i < ell; i++) {
            b_i = abi.encodePacked(b0 ^ bi, uint8(1 + i), DST, uint8(domainLen));
            assembly {
                let p := add(32, out)
                p := add(p, mul(32, sub(i, 1)))
                mstore(p, bi)
            }
            bi = sha256(b_i);
        }
        assembly {
            let p := add(32, out)
            p := add(p, mul(32, sub(ell, 1)))
            mstore(p, bi)
        }
        return out;
    }
}
