// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { Bls12381 } from "../../src/libraries/Bls12381.sol";
import { QuicknetVerifier } from "../../src/libraries/QuicknetVerifier.sol";

contract QuicknetVerifierHarness {
    function period() external pure returns (uint64) {
        return QuicknetVerifier.PERIOD;
    }

    function genesisTimestamp() external pure returns (uint64) {
        return QuicknetVerifier.GENESIS_TIMESTAMP;
    }

    function maxRound() external pure returns (uint64) {
        return QuicknetVerifier.MAX_ROUND;
    }

    function domainSeparationTag() external pure returns (string memory) {
        return QuicknetVerifier.DST;
    }

    function publicKey() external pure returns (bytes memory) {
        Bls12381.PointG2 memory key = QuicknetVerifier.publicKey();
        return abi.encodePacked(
            key.x1_hi, key.x1_lo, key.x0_hi, key.x0_lo, key.y1_hi, key.y1_lo, key.y0_hi, key.y0_lo
        );
    }

    function messageHash(uint64 round) external pure returns (bytes32) {
        return QuicknetVerifier.messageHash(round);
    }

    function roundMessage(uint64 round) external pure returns (bytes memory) {
        return QuicknetVerifier.roundMessage(round);
    }

    function decodeSignature(bytes calldata signature) external view returns (bytes memory) {
        return Bls12381.g1Marshal(QuicknetVerifier.decodeSignature(signature));
    }

    function hashMessageToPoint(bytes32 digest) external view returns (bytes memory) {
        return Bls12381.g1Marshal(QuicknetVerifier.hashMessageToPoint(digest));
    }

    function checkedStaticcall(uint256 target, bytes calldata input, uint256 outputLength)
        external
        view
        returns (bytes memory)
    {
        return QuicknetVerifier.checkedStaticcall(target, input, outputLength);
    }

    function roundTime(uint64 round) external pure returns (uint64) {
        return QuicknetVerifier.roundTime(round);
    }

    function firstRoundAfter(uint256 timestamp) external pure returns (uint64) {
        return QuicknetVerifier.firstRoundAfter(timestamp);
    }

    function verifyAndNormalize(uint64 round, bytes calldata signature)
        external
        view
        returns (bytes32 randomness, bytes memory canonicalSignature)
    {
        return QuicknetVerifier.verifyAndNormalize(round, signature);
    }
}
