methods {
    function hasSig(uint64) external returns (bool) envfree;
    function randomnessOf(uint64) external returns (bytes32) envfree;
    function postedAt(uint64) external returns (uint64) envfree;
}

/// No non-postSig selector in the compiled runtime can replace an already stored beacon.
rule storedBeaconImmutableAcrossNonPostSelectors(env e, uint64 round) filtered {
    f -> f.selector != sig:postSig(uint64,bytes).selector
} {
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
rule onlyPostSigCanCreateBeacon(env e, uint64 observedRound) filtered {
    f -> f.selector != sig:postSig(uint64,bytes).selector
} {
    require !hasSig(observedRound);

    method f;
    calldataarg args;
    f@withrevert(e, args);

    assert !hasSig(observedRound);
}
