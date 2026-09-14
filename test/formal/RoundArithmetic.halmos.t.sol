// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { QuicknetVerifierHarness } from "../helpers/QuicknetVerifierHarness.sol";

contract RoundArithmeticHalmosTest is Test {
    uint256 private constant GENESIS_TIMESTAMP = 1_692_803_367;
    uint256 private constant PERIOD = 3;
    uint256 private constant MAX_ROUND = 6_148_914_690_672_249_417;

    QuicknetVerifierHarness private verifier;

    function setUp() public {
        verifier = new QuicknetVerifierHarness();
    }

    function check_roundTimeFormula(uint256 round) public view {
        vm.assume(round >= 1 && round <= MAX_ROUND);

        // The assumption proves the value is within uint64.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint64 narrowedRound = uint64(round);
        uint256 expected = GENESIS_TIMESTAMP + (round - 1) * PERIOD;

        assert(uint256(verifier.roundTime(narrowedRound)) == expected);
        assert(expected <= type(uint64).max);
    }

    function check_firstRoundAfterIsMinimal(uint256 timestamp) public view {
        vm.assume(timestamp < type(uint64).max);

        uint64 round = verifier.firstRoundAfter(timestamp);
        uint256 scheduled = verifier.roundTime(round);
        assert(scheduled > timestamp);

        if (round > 1) {
            assert(uint256(verifier.roundTime(round - 1)) <= timestamp);
        }
    }

    function check_preGenesisMapsToFirstRound(uint256 timestamp) public view {
        vm.assume(timestamp < GENESIS_TIMESTAMP);
        assert(verifier.firstRoundAfter(timestamp) == 1);
    }

    function check_roundMessageSerialization(uint64 round) public view {
        vm.assume(round > 0);
        bytes memory encoded = verifier.roundMessage(round);
        uint256 encodedWord;
        assembly ("memory-safe") {
            encodedWord := mload(add(encoded, 0x20))
        }

        assert(encoded.length == 8);
        assert(encodedWord == uint256(round) << 192);
    }
}
