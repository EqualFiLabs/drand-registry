methods {
    function hasSig(uint64) external returns (bool) envfree;
    function randomnessOf(uint64) external returns (bytes32) envfree;
    function postedAt(uint64) external returns (uint64) envfree;
    function configureVerificationSummary(bool, bytes32, bytes) external;
    function summarizedRandomness(uint64, bytes32) external returns (bytes32) envfree;
    function postSig(uint64, bytes) external returns (bool);
}

/// A proof accepted by the constrained Quicknet summary stores the round-bound canonical result.
rule acceptedProofStoresBoundRandomness(
    env e,
    uint64 round,
    bytes32 canonicalPoint,
    bytes signature
) {
    require e.msg.value == 0;
    require !hasSig(round);
    require e.block.timestamp <= max_uint64;

    configureVerificationSummary(e, true, canonicalPoint, signature);
    bytes32 expected = summarizedRandomness(round, canonicalPoint);
    bool newlyStored = postSig(e, round, signature);

    assert newlyStored;
    assert hasSig(round);
    assert randomnessOf(round) == expected;
    assert postedAt(round) == e.block.timestamp;
}

/// A rejected pairing summary cannot make beacon storage reachable.
rule rejectedProofCannotWrite(
    env e,
    uint64 round,
    bytes32 canonicalPoint,
    bytes signature
) {
    require e.msg.value == 0;
    require !hasSig(round);
    require e.block.timestamp <= max_uint64;

    bytes32 randomnessBefore = randomnessOf(round);
    uint64 postedAtBefore = postedAt(round);
    configureVerificationSummary(e, false, canonicalPoint, signature);
    postSig@withrevert(e, round, signature);

    assert lastReverted;
    assert !hasSig(round);
    assert randomnessOf(round) == randomnessBefore;
    assert postedAt(round) == postedAtBefore;
}

/// A duplicate returns before consulting even a rejecting replacement summary.
rule duplicateSkipsReplacementVerification(
    env e,
    uint64 round,
    bytes32 canonicalPoint,
    bytes32 replacementPoint,
    bytes firstSignature,
    bytes replacementSignature
) {
    require e.msg.value == 0;
    require !hasSig(round);
    require e.block.timestamp <= max_uint64;

    configureVerificationSummary(e, true, canonicalPoint, firstSignature);
    bool firstStored = postSig(e, round, firstSignature);
    bytes32 storedRandomness = randomnessOf(round);
    uint64 storedAt = postedAt(round);

    configureVerificationSummary(e, false, replacementPoint, replacementSignature);
    bool replacementStored = postSig(e, round, replacementSignature);

    assert firstStored;
    assert !replacementStored;
    assert randomnessOf(round) == storedRandomness;
    assert postedAt(round) == storedAt;
}

/// The summary binds randomness to the round even for the same canonical point.
rule summarizedRandomnessIsRoundBound(uint64 firstRound, uint64 secondRound, bytes32 canonicalPoint) {
    require firstRound != secondRound;
    assert summarizedRandomness(firstRound, canonicalPoint)
        != summarizedRandomness(secondRound, canonicalPoint);
}
