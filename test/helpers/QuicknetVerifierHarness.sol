// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { BLS2 } from "bls-solidity/libraries/BLS2.sol";
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
        return BLS2.g2Marshal(QuicknetVerifier.publicKey());
    }

    function messageHash(uint64 round) external pure returns (bytes32) {
        return QuicknetVerifier.messageHash(round);
    }

    function roundMessage(uint64 round) external pure returns (bytes memory) {
        return QuicknetVerifier.roundMessage(round);
    }

    function decodeSignature(bytes calldata signature) external view returns (bytes memory) {
        return BLS2.g1Marshal(QuicknetVerifier.decodeSignature(signature));
    }

    function hashMessageToPoint(bytes32 digest) external view returns (bytes memory) {
        return BLS2.g1Marshal(QuicknetVerifier.hashMessageToPoint(digest));
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
