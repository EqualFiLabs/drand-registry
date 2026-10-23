// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { BLS2 } from "bls-solidity/libraries/BLS2.sol";
import { EqualFiDrandRegistry } from "../../src/EqualFiDrandRegistry.sol";
import { QuicknetVerifier } from "../../src/libraries/QuicknetVerifier.sol";

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
    bool private _accepted;
    uint64 private _summarizedRound;
    bytes32 private _submittedProofHash;
    BLS2.PointG1 private _signaturePoint;
    BLS2.PointG1 private _messagePoint;
    bytes32 private _messageBinding;
    bytes32 private _pairingBinding;

    error FormalPairingRejected();

    function configureVerificationSummary(
        bool accepted,
        uint64 round,
        bytes calldata submittedProof,
        uint128 signatureXHi,
        uint256 signatureXLo,
        uint128 signatureYHi,
        uint256 signatureYLo,
        uint128 messageXHi,
        uint256 messageXLo,
        uint128 messageYHi,
        uint256 messageYLo
    ) external {
        BLS2.PointG1 memory signaturePoint =
            BLS2.PointG1(signatureXHi, signatureXLo, signatureYHi, signatureYLo);
        BLS2.PointG1 memory messagePoint =
            BLS2.PointG1(messageXHi, messageXLo, messageYHi, messageYLo);
        QuicknetVerifier.validateG1Point(signaturePoint);
        QuicknetVerifier.validateG1Point(messagePoint);

        _accepted = accepted;
        _summarizedRound = round;
        _submittedProofHash = keccak256(submittedProof);
        _signaturePoint = signaturePoint;
        _messagePoint = messagePoint;
        _messageBinding = messageBinding(round, messagePoint);
        _pairingBinding = pairingBinding(signaturePoint, messagePoint);
    }

    function summarizedRandomness(
        uint64 round,
        uint128 signatureXHi,
        uint256 signatureXLo,
        uint128 signatureYHi,
        uint256 signatureYLo
    )
        public
        pure
        returns (bytes32)
    {
        BLS2.PointG1 memory signaturePoint =
            BLS2.PointG1(signatureXHi, signatureXLo, signatureYHi, signatureYLo);
        return keccak256(abi.encodePacked(BLS2.g1Marshal(signaturePoint), round));
    }

    function canonicalPointIsValid(uint128 xHi, uint256 xLo, uint128 yHi, uint256 yLo)
        external
        pure
        returns (bool)
    {
        return (xHi != 0 || xLo != 0 || yHi != 0 || yLo != 0)
            && QuicknetVerifier.isCanonicalFieldElement(xHi, xLo)
            && QuicknetVerifier.isCanonicalFieldElement(yHi, yLo);
    }

    function messageBinding(uint64 round, BLS2.PointG1 memory messagePoint)
        public
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                QuicknetVerifier.domainSeparationTag(),
                QuicknetVerifier.roundMessage(round),
                BLS2.g1Marshal(messagePoint)
            )
        );
    }

    function pairingBinding(
        BLS2.PointG1 memory signaturePoint,
        BLS2.PointG1 memory messagePoint
    ) public pure returns (bytes32) {
        return keccak256(
            QuicknetVerifier.pairingInput(
                signaturePoint, QuicknetVerifier.publicKey(), messagePoint
            )
        );
    }

    function _verifiedRandomness(uint64 round, bytes calldata signature)
        internal
        view
        override
        returns (bytes32 randomness)
    {
        if (
            !_accepted || round != _summarizedRound
                || keccak256(signature) != _submittedProofHash
                || messageBinding(round, _messagePoint) != _messageBinding
                || pairingBinding(_signaturePoint, _messagePoint) != _pairingBinding
        ) {
            revert FormalPairingRejected();
        }
        return summarizedRandomness(
            round,
            _signaturePoint.x_hi,
            _signaturePoint.x_lo,
            _signaturePoint.y_hi,
            _signaturePoint.y_lo
        );
    }
}
