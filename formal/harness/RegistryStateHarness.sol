// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { EqualFiDrandRegistry } from "../../src/EqualFiDrandRegistry.sol";

/// @notice Exposes only the Registry's first-write transition for state-machine proofs.
contract RegistryStateHarness is EqualFiDrandRegistry {
    function cacheVerified(uint64 round, bytes32 randomness, uint64 recordedAt)
        external
        returns (bool newlyStored)
    {
        return _cacheVerified(round, randomness, recordedAt);
    }
}

/// @notice Replaces EIP-2537 with an explicit proof/canonical-point relation for acceptance proofs.
/// @dev `accepted` models the constrained pairing summary. `canonicalPoint` models the normalized
///      G1 point; the summary binds the result to it, the exact round, and the submitted proof hash.
contract RegistryAcceptanceHarness is EqualFiDrandRegistry {
    bytes32 private constant FORMAL_QUICKNET_DOMAIN = keccak256(
        "Quicknet|BLS_SIG_BLS12381G1_XMD:SHA-256_SSWU_RO_NUL_|52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971"
    );

    bool private _accepted;
    bytes32 private _canonicalPoint;
    bytes32 private _submittedProofHash;

    error FormalPairingRejected();

    function configureVerificationSummary(
        bool accepted,
        bytes32 canonicalPoint,
        bytes calldata submittedProof
    ) external {
        _accepted = accepted;
        _canonicalPoint = canonicalPoint;
        _submittedProofHash = keccak256(submittedProof);
    }

    function summarizedRandomness(uint64 round, bytes32 canonicalPoint)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(FORMAL_QUICKNET_DOMAIN, canonicalPoint, round));
    }

    function _verifiedRandomness(uint64 round, bytes calldata signature)
        internal
        view
        override
        returns (bytes32 randomness)
    {
        if (!_accepted || keccak256(signature) != _submittedProofHash) {
            revert FormalPairingRejected();
        }
        return summarizedRandomness(round, _canonicalPoint);
    }
}
