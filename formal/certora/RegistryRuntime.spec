methods {
    function hasSig(uint64) external returns (bool) envfree;
    function randomnessOf(uint64) external returns (bytes32) envfree;
    function postedAt(uint64) external returns (uint64) envfree;
    function postSig(uint64, bytes) external returns (bool);
}

/// The deployed runtime's duplicate branch returns before proof parsing or verification.
rule duplicateSubmissionIsNoOp(env e, uint64 round, bytes replacementProof) {
    require e.msg.value == 0;
    require hasSig(round);

    bytes32 storedRandomness = randomnessOf(round);
    uint64 storedAt = postedAt(round);
    bool newlyStored = postSig(e, round, replacementProof);

    assert !newlyStored;
    assert hasSig(round);
    assert randomnessOf(round) == storedRandomness;
    assert postedAt(round) == storedAt;
}

/// No external selector in the compiled runtime can replace an already stored beacon.
rule storedBeaconImmutableAcrossExternalCalls(env e, uint64 round) {
    require hasSig(round);

    bytes32 storedRandomness = randomnessOf(round);
    uint64 storedAt = postedAt(round);
    method f;
    calldataarg args;
    f@withrevert(e, args);

    assert hasSig(round);
    assert randomnessOf(round) == storedRandomness;
    assert postedAt(round) == storedAt;
}

/// The compiled ABI has no state-creating entry point other than postSig.
rule onlyPostSigCanCreateBeacon(env e, uint64 observedRound) {
    require !hasSig(observedRound);

    method f;
    calldataarg args;
    f@withrevert(e, args);

    assert hasSig(observedRound)
        => f.selector == sig:postSig(uint64,bytes).selector;
}
