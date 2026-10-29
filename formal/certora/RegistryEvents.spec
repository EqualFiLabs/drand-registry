methods {
    function hasSig(uint64) external returns (bool) envfree;
    function randomnessOf(uint64) external returns (bytes32) envfree;
    function postedAt(uint64) external returns (uint64) envfree;
    function configureVerificationSummary(bool,uint64,bytes,uint128,uint256,uint128,uint256,uint128,uint256,uint128,uint256) external;
    function summarizedRandomness(uint64,uint128,uint256,uint128,uint256) external returns (bytes32) envfree;
    function canonicalPointIsValid(uint128,uint256,uint128,uint256) external returns (bool) envfree;
    function postSig(uint64,bytes) external returns (bool);
}

ghost mathint eventCount;
ghost bytes32 topic0;
ghost bytes32 topic1;
ghost bytes32 topic2;
ghost bytes32 topic3;
ghost uint256 dataLength;
hook LOG4(uint offset,uint length,bytes32 t1,bytes32 t2,bytes32 t3,bytes32 t4) {
    if (executingContract==currentContract) {
        eventCount=eventCount+1;
        topic0=t1;topic1=t2;topic2=t3;topic3=t4;dataLength=length;
    }
}

// This rule verifies the inherited production posting/event logic, conditional on
// the acceptance summary. Production cryptographic wiring is proved separately.
rule acceptedPostEmitsBoundTopicsAndLength(env e,uint64 round,bytes signature,uint128 xh,uint256 xl,uint128 yh,uint256 yl) {
    require e.msg.value==0;
    require e.block.timestamp<=max_uint64;
    require round>0 && !hasSig(round);
    require signature.length==48 || signature.length==96;
    require canonicalPointIsValid(xh,xl,yh,yl);
    configureVerificationSummary(e,true,round,signature,xh,xl,yh,yl,0,3,0,4);
    bytes32 expected=summarizedRandomness(round,xh,xl,yh,yl);
    eventCount=0;
    bool stored=postSig(e,round,signature);
    assert stored && eventCount==1;
    assert topic0==to_bytes32(0x62dc8e01fc32243070e4ebfd12f9dc058891a6570e3b349df48716e9fc479b79);
    uint256 roundWord=round;
    assert topic1==to_bytes32(roundWord);
    assert topic2==to_bytes32(e.msg.sender);
    assert topic3==expected;
    assert dataLength==64+((signature.length+31)/32)*32;
}

rule duplicateNeverEmitsAtAnyTimestamp(env e,env later,uint64 round,bytes first,bytes replacement) {
    require e.msg.value==0 && later.msg.value==0;
    require e.block.timestamp<=max_uint64;
    require round>0 && !hasSig(round);
    require first.length==48 || first.length==96;
    configureVerificationSummary(e,true,round,first,0,1,0,2,0,3,0,4);
    bool stored=postSig(e,round,first);
    bytes32 beforeRandomness=randomnessOf(round);
    uint64 beforeTime=postedAt(round);
    eventCount=0;
    bool duplicate=postSig(later,round,replacement);
    assert stored, "first post succeeds";
    assert !duplicate, "duplicate returns false";
    assert eventCount==0, "duplicate emits no event";
    assert hasSig(round), "presence preserved";
    assert randomnessOf(round)==beforeRandomness, "randomness preserved";
    assert postedAt(round)==beforeTime, "timestamp preserved";
}

rule overflowingTimestampCannotWriteOrEmit(env e,uint64 round,bytes signature) {
    require e.msg.value==0 && e.block.timestamp>max_uint64;
    require round>0 && !hasSig(round);
    require signature.length==48 || signature.length==96;
    configureVerificationSummary(e,true,round,signature,0,1,0,2,0,3,0,4);
    bytes32 beforeRandomness=randomnessOf(round);
    uint64 beforeTime=postedAt(round);
    eventCount=0;
    postSig@withrevert(e,round,signature);
    assert lastReverted && eventCount==0;
    assert !hasSig(round) && randomnessOf(round)==beforeRandomness && postedAt(round)==beforeTime;
}
