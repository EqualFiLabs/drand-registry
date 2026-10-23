// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IEqualFiDrandRegistry } from "../src/interfaces/IEqualFiDrandRegistry.sol";

contract EqualFiDrandRegistryInterfaceTest is Test {
    function test_interfaceSelectorsAreStable() external pure {
        assertEq(
            IEqualFiDrandRegistry.firstRoundAfter.selector,
            bytes4(keccak256("firstRoundAfter(uint256)"))
        );
        assertEq(IEqualFiDrandRegistry.roundTime.selector, bytes4(keccak256("roundTime(uint64)")));
        assertEq(IEqualFiDrandRegistry.hasSig.selector, bytes4(keccak256("hasSig(uint64)")));
        assertEq(
            IEqualFiDrandRegistry.randomnessOf.selector, bytes4(keccak256("randomnessOf(uint64)"))
        );
        assertEq(IEqualFiDrandRegistry.postedAt.selector, bytes4(keccak256("postedAt(uint64)")));
        assertEq(IEqualFiDrandRegistry.postSig.selector, bytes4(keccak256("postSig(uint64,bytes)")));
    }

    function test_interfaceIdCommitsToAllSelectors() external pure {
        bytes4 expected = IEqualFiDrandRegistry.firstRoundAfter.selector
            ^ IEqualFiDrandRegistry.roundTime.selector ^ IEqualFiDrandRegistry.hasSig.selector
            ^ IEqualFiDrandRegistry.randomnessOf.selector ^ IEqualFiDrandRegistry.postedAt.selector
            ^ IEqualFiDrandRegistry.postSig.selector;

        assertEq(type(IEqualFiDrandRegistry).interfaceId, expected);
    }
}
