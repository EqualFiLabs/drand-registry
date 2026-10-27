methods {
    function hasSig(uint64) external returns (bool) envfree;
    function randomnessOf(uint64) external returns (bytes32) envfree;
    function postedAt(uint64) external returns (uint64) envfree;
    function postSig(uint64,bytes) external returns (bool);
}
ghost mathint eventCount;
persistent ghost mathint primitiveCalls;
hook STATICCALL(uint g,address target,uint argsOffset,uint argsLength,uint retOffset,uint retLength) uint rc {
    if (executingContract==currentContract && (target==2 || target==5 || target==11 || target==15 || target==16)) { primitiveCalls=primitiveCalls+1; }
}
hook LOG4(uint offset,uint length,bytes32 t0,bytes32 t1,bytes32 t2,bytes32 t3) {
    if (executingContract==currentContract) { eventCount=eventCount+1; }
}

hook LOG0(uint offset,uint length) { if (executingContract==currentContract) { eventCount=eventCount+1; } }
hook LOG1(uint offset,uint length,bytes32 t0) { if (executingContract==currentContract) { eventCount=eventCount+1; } }
hook LOG2(uint offset,uint length,bytes32 t0,bytes32 t1) { if (executingContract==currentContract) { eventCount=eventCount+1; } }
hook LOG3(uint offset,uint length,bytes32 t0,bytes32 t1,bytes32 t2) { if (executingContract==currentContract) { eventCount=eventCount+1; } }

// No calldata-length enumeration, loop unrolling, or crypto override.
rule unsupportedLengthRejectsAllBytes(env e,uint64 round,bytes signature) {
    require e.msg.value==0 && e.block.timestamp<=max_uint64;
    require round>0 && !hasSig(round);
    require signature.length!=48 && signature.length!=96;
    bytes32 beforeRandomness=randomnessOf(round);
    uint64 beforeTime=postedAt(round);
    eventCount=0; primitiveCalls=0;
    postSig@withrevert(e,round,signature);
    assert lastReverted && eventCount==0 && primitiveCalls==0;
    assert !hasSig(round) && randomnessOf(round)==beforeRandomness && postedAt(round)==beforeTime;
}

rule duplicateIgnoresAllBytesAndTimestamps(env e,uint64 round,bytes signature,uint64 other) {
    require e.msg.value==0 && hasSig(round);
    bytes32 beforeRandomness=randomnessOf(round);
    uint64 beforeTime=postedAt(round);
    bool otherPresent=hasSig(other);
    bytes32 otherRandomness=randomnessOf(other);
    uint64 otherTime=postedAt(other);
    eventCount=0; primitiveCalls=0;
    bool stored=postSig(e,round,signature);
    assert !stored && eventCount==0 && primitiveCalls==0;
    assert hasSig(round) && randomnessOf(round)==beforeRandomness && postedAt(round)==beforeTime;
    assert hasSig(other)==otherPresent && randomnessOf(other)==otherRandomness && postedAt(other)==otherTime;
}

rule overflowRejectsAllBytes(env e,uint64 round,bytes signature) {
    require e.msg.value==0 && e.block.timestamp>max_uint64 && !hasSig(round);
    bytes32 beforeRandomness=randomnessOf(round);
    uint64 beforeTime=postedAt(round);
    eventCount=0; primitiveCalls=0;
    postSig@withrevert(e,round,signature);
    assert lastReverted && eventCount==0 && primitiveCalls==0;
    assert !hasSig(round) && randomnessOf(round)==beforeRandomness && postedAt(round)==beforeTime;
}

rule zeroRoundRejectsAllBytes(env e,bytes signature) {
    require e.msg.value==0 && e.block.timestamp<=max_uint64 && !hasSig(0);
    bytes32 beforeRandomness=randomnessOf(0);
    uint64 beforeTime=postedAt(0);
    eventCount=0; primitiveCalls=0;
    postSig@withrevert(e,0,signature);
    assert lastReverted && eventCount==0 && primitiveCalls==0;
    assert !hasSig(0) && randomnessOf(0)==beforeRandomness && postedAt(0)==beforeTime;
}
