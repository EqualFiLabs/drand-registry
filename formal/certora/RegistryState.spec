methods {
    function hasSig(uint64) external returns (bool) envfree;
    function randomnessOf(uint64) external returns (bytes32) envfree;
    function postedAt(uint64) external returns (uint64) envfree;
    function cacheVerified(uint64, bytes32, uint64) external returns (bool);
}

/// The first modeled verified result is stored exactly.
rule firstWriteStoresExactly(env e, uint64 round, bytes32 randomness, uint64 recordedAt) {
    require e.msg.value == 0;
    require !hasSig(round);

    bool newlyStored = cacheVerified(e, round, randomness, recordedAt);

    assert newlyStored;
    assert hasSig(round);
    assert randomnessOf(round) == randomness;
    assert postedAt(round) == recordedAt;
}

/// Once present, a beacon cannot be replaced through the cache transition.
rule duplicateCannotReplace(
    env e,
    uint64 round,
    bytes32 firstRandomness,
    uint64 firstPostedAt,
    bytes32 replacementRandomness,
    uint64 replacementPostedAt
) {
    require e.msg.value == 0;
    require !hasSig(round);

    bool firstStored = cacheVerified(e, round, firstRandomness, firstPostedAt);
    bytes32 storedRandomness = randomnessOf(round);
    uint64 storedAt = postedAt(round);
    bool replacementStored = cacheVerified(e, round, replacementRandomness, replacementPostedAt);

    assert firstStored;
    assert !replacementStored;
    assert hasSig(round);
    assert randomnessOf(round) == storedRandomness;
    assert postedAt(round) == storedAt;
    assert storedRandomness == firstRandomness;
    assert storedAt == firstPostedAt;
}

/// Writing one round cannot alter another round's cached beacon.
rule roundsRemainIsolated(
    env e,
    uint64 firstRound,
    uint64 secondRound,
    bytes32 firstRandomness,
    uint64 firstPostedAt,
    bytes32 secondRandomness,
    uint64 secondPostedAt
) {
    require e.msg.value == 0;
    require firstRound != secondRound;
    require !hasSig(firstRound);
    require !hasSig(secondRound);

    cacheVerified(e, firstRound, firstRandomness, firstPostedAt);
    bytes32 firstStoredRandomness = randomnessOf(firstRound);
    uint64 firstStoredAt = postedAt(firstRound);
    cacheVerified(e, secondRound, secondRandomness, secondPostedAt);

    assert randomnessOf(firstRound) == firstStoredRandomness;
    assert postedAt(firstRound) == firstStoredAt;
    assert randomnessOf(secondRound) == secondRandomness;
    assert postedAt(secondRound) == secondPostedAt;
}
