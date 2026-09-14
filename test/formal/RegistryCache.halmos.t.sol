// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { RegistryStateHarness } from "../../formal/harness/RegistryStateHarness.sol";

contract RegistryCacheHalmosTest is Test {
    RegistryStateHarness private registry;

    function setUp() public {
        registry = new RegistryStateHarness();
    }

    function check_firstWriteStoresExactly(uint64 round, bytes32 randomness, uint64 recordedAt)
        public
    {
        bool stored = registry.cacheVerified(round, randomness, recordedAt);

        assert(stored);
        assert(registry.hasSig(round));
        assert(registry.randomnessOf(round) == randomness);
        assert(registry.postedAt(round) == recordedAt);
    }

    function check_duplicateCannotReplace(
        uint64 round,
        bytes32 firstRandomness,
        uint64 firstPostedAt,
        bytes32 replacementRandomness,
        uint64 replacementPostedAt
    ) public {
        assert(registry.cacheVerified(round, firstRandomness, firstPostedAt));
        assert(!registry.cacheVerified(round, replacementRandomness, replacementPostedAt));

        assert(registry.hasSig(round));
        assert(registry.randomnessOf(round) == firstRandomness);
        assert(registry.postedAt(round) == firstPostedAt);
    }

    function check_distinctRoundsRemainIsolated(
        uint64 firstRound,
        uint64 secondRound,
        bytes32 firstRandomness,
        bytes32 secondRandomness,
        uint64 firstPostedAt,
        uint64 secondPostedAt
    ) public {
        vm.assume(firstRound != secondRound);

        assert(registry.cacheVerified(firstRound, firstRandomness, firstPostedAt));
        assert(registry.cacheVerified(secondRound, secondRandomness, secondPostedAt));

        assert(registry.randomnessOf(firstRound) == firstRandomness);
        assert(registry.postedAt(firstRound) == firstPostedAt);
        assert(registry.randomnessOf(secondRound) == secondRandomness);
        assert(registry.postedAt(secondRound) == secondPostedAt);
    }
}
