methods {
    function hasSig(uint64) external returns (bool) envfree;
    function randomnessOf(uint64) external returns (bytes32) envfree;
    function postedAt(uint64) external returns (uint64) envfree;
    function configureVerificationSummary(
        bool,
        uint64,
        bytes,
        uint128,
        uint256,
        uint128,
        uint256,
        uint128,
        uint256,
        uint128,
        uint256
    ) external;
    function summarizedRandomness(uint64,uint128,uint256,uint128,uint256)
        external returns (bytes32) envfree;
    function canonicalPointIsValid(uint128,uint256,uint128,uint256)
        external returns (bool) envfree;
    function postSig(uint64, bytes) external returns (bool);
}

/// A constrained pairing summary stores the production round-bound canonical result.
rule acceptedProofStoresBoundRandomness(
    env e,
    uint64 round,
    bytes signature,
    uint128 sxh,
    uint256 sxl,
    uint128 syh,
    uint256 syl,
    uint128 mxh,
    uint256 mxl,
    uint128 myh,
    uint256 myl
) {
    require e.msg.value == 0;
    require !hasSig(round);
    require e.block.timestamp <= max_uint64;
    require signature.length == 48 || signature.length == 96;
    require canonicalPointIsValid(sxh, sxl, syh, syl);
    require canonicalPointIsValid(mxh, mxl, myh, myl);

    configureVerificationSummary(
        e, true, round, signature, sxh, sxl, syh, syl, mxh, mxl, myh, myl
    );
    bytes32 expected = summarizedRandomness(round, sxh, sxl, syh, syl);
    bool newlyStored = postSig(e, round, signature);

    assert newlyStored;
    assert hasSig(round);
    assert randomnessOf(round) == expected;
    assert postedAt(round) == e.block.timestamp;
}

/// A rejected pairing result for the exact transcript cannot make storage reachable.
rule rejectedProofCannotWrite(
    env e,
    uint64 round,
    bytes signature,
    uint128 sxh,
    uint256 sxl,
    uint128 syh,
    uint256 syl,
    uint128 mxh,
    uint256 mxl,
    uint128 myh,
    uint256 myl
) {
    require e.msg.value == 0;
    require !hasSig(round);
    require e.block.timestamp <= max_uint64;
    require signature.length == 48 || signature.length == 96;
    require canonicalPointIsValid(sxh, sxl, syh, syl);
    require canonicalPointIsValid(mxh, mxl, myh, myl);

    bytes32 randomnessBefore = randomnessOf(round);
    uint64 postedAtBefore = postedAt(round);
    configureVerificationSummary(
        e, false, round, signature, sxh, sxl, syh, syl, mxh, mxl, myh, myl
    );
    postSig@withrevert(e, round, signature);

    assert lastReverted;
    assert !hasSig(round);
    assert randomnessOf(round) == randomnessBefore;
    assert postedAt(round) == postedAtBefore;
}

/// A summary for another round or submitted proof cannot authorize this call.
rule mismatchedSummaryCannotWrite(
    env e,
    uint64 configuredRound,
    uint64 submittedRound,
    bytes configuredProof,
    bytes submittedProof,
    uint128 sxh,
    uint256 sxl,
    uint128 syh,
    uint256 syl,
    uint128 mxh,
    uint256 mxl,
    uint128 myh,
    uint256 myl
) {
    require e.msg.value == 0;
    require configuredRound != submittedRound || configuredProof != submittedProof;
    require !hasSig(submittedRound);
    require e.block.timestamp <= max_uint64;
    require configuredProof.length == 48 || configuredProof.length == 96;
    require submittedProof.length == 48 || submittedProof.length == 96;
    require canonicalPointIsValid(sxh, sxl, syh, syl);
    require canonicalPointIsValid(mxh, mxl, myh, myl);

    configureVerificationSummary(
        e, true, configuredRound, configuredProof, sxh, sxl, syh, syl, mxh, mxl, myh, myl
    );
    postSig@withrevert(e, submittedRound, submittedProof);

    assert lastReverted;
    assert !hasSig(submittedRound);
}

/// A duplicate returns before consulting even a rejecting replacement summary.
rule duplicateSkipsReplacementVerification(
    env e,
    uint64 round,
    bytes firstSignature,
    bytes replacementSignature,
    uint128 sxh,
    uint256 sxl,
    uint128 syh,
    uint256 syl,
    uint128 mxh,
    uint256 mxl,
    uint128 myh,
    uint256 myl
) {
    require e.msg.value == 0;
    require !hasSig(round);
    require e.block.timestamp <= max_uint64;
    require firstSignature.length == 48 || firstSignature.length == 96;
    require replacementSignature.length == 48 || replacementSignature.length == 96;
    require canonicalPointIsValid(sxh, sxl, syh, syl);
    require canonicalPointIsValid(mxh, mxl, myh, myl);

    configureVerificationSummary(
        e, true, round, firstSignature, sxh, sxl, syh, syl, mxh, mxl, myh, myl
    );
    bool firstStored = postSig(e, round, firstSignature);
    bytes32 storedRandomness = randomnessOf(round);
    uint64 storedAt = postedAt(round);

    configureVerificationSummary(
        e, false, round, replacementSignature, sxh, sxl, syh, syl, mxh, mxl, myh, myl
    );
    bool replacementStored = postSig(e, round, replacementSignature);

    assert firstStored;
    assert !replacementStored;
    assert randomnessOf(round) == storedRandomness;
    assert postedAt(round) == storedAt;
}

/// The same canonical point derives different modeled randomness for distinct rounds.
rule summarizedRandomnessIsRoundBound(
    uint64 firstRound,
    uint64 secondRound,
    uint128 sxh,
    uint256 sxl,
    uint128 syh,
    uint256 syl
) {
    require firstRound != secondRound;
    require canonicalPointIsValid(sxh, sxl, syh, syl);
    assert summarizedRandomness(firstRound, sxh, sxl, syh, syl)
        != summarizedRandomness(secondRound, sxh, sxl, syh, syl);
}
