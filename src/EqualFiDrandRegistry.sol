// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IEqualFiDrandRegistry } from "./interfaces/IEqualFiDrandRegistry.sol";
import { QuicknetVerifier } from "./libraries/QuicknetVerifier.sol";

/// @title EqualFi drand Registry
/// @notice Immutable Quicknet verification and permanent beacon cache shared by EqualFi consumers.
contract EqualFiDrandRegistry is IEqualFiDrandRegistry {
    struct Beacon {
        bytes32 randomness;
        uint64 postedAt;
        bool stored;
    }

    mapping(uint64 round => Beacon beacon) private _beacons;

    error BlockTimestampOutOfRange(uint256 timestamp);

    /// @inheritdoc IEqualFiDrandRegistry
    function firstRoundAfter(uint256 timestamp) external pure returns (uint64 round) {
        return QuicknetVerifier.firstRoundAfter(timestamp);
    }

    /// @inheritdoc IEqualFiDrandRegistry
    function roundTime(uint64 round) external pure returns (uint64 timestamp) {
        return QuicknetVerifier.roundTime(round);
    }

    /// @inheritdoc IEqualFiDrandRegistry
    function hasSig(uint64 round) external view returns (bool) {
        return _beacons[round].stored;
    }

    /// @inheritdoc IEqualFiDrandRegistry
    function randomnessOf(uint64 round) external view returns (bytes32 randomness) {
        return _beacons[round].randomness;
    }

    /// @inheritdoc IEqualFiDrandRegistry
    function postedAt(uint64 round) external view returns (uint64 timestamp) {
        return _beacons[round].postedAt;
    }

    /// @inheritdoc IEqualFiDrandRegistry
    function postSig(uint64 round, bytes calldata signature) external returns (bool newlyStored) {
        Beacon storage beacon = _beacons[round];
        if (beacon.stored) return false;

        uint256 currentTimestamp = block.timestamp;
        // Timestamp is recorded only as provenance and never influences randomness or acceptance.
        // forge-lint: disable-next-line(block-timestamp)
        if (currentTimestamp > type(uint64).max) {
            revert BlockTimestampOutOfRange(currentTimestamp);
        }

        // The normalized point is intentionally not persisted; only round-bound randomness is stored.
        // forge-lint: disable-next-line(unused-return)
        (bytes32 randomness,) = QuicknetVerifier.verifyAndNormalize(round, signature);

        beacon.randomness = randomness;
        // The explicit bound above proves the timestamp is within uint64.
        // forge-lint: disable-next-line(unsafe-typecast)
        beacon.postedAt = uint64(currentTimestamp);
        beacon.stored = true;

        emit QuicknetSignaturePosted(round, msg.sender, randomness, signature);
        return true;
    }
}
