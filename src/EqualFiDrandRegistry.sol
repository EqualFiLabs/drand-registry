// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IEqualFiDrandRegistry } from "./interfaces/IEqualFiDrandRegistry.sol";
import { QuicknetVerifier } from "./libraries/QuicknetVerifier.sol";

/// @title EqualFi drand Registry
/// @notice Immutable Quicknet verification surface shared by EqualFi consumers.
/// @dev Registry storage and caching complete this abstract implementation in the next slice.
abstract contract EqualFiDrandRegistry is IEqualFiDrandRegistry {
    /// @inheritdoc IEqualFiDrandRegistry
    function firstRoundAfter(uint256 timestamp) external pure returns (uint64 round) {
        return QuicknetVerifier.firstRoundAfter(timestamp);
    }

    /// @inheritdoc IEqualFiDrandRegistry
    function roundTime(uint64 round) external pure returns (uint64 timestamp) {
        return QuicknetVerifier.roundTime(round);
    }
}
