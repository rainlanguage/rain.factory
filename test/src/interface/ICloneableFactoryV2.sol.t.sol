// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {ICloneableFactoryV2} from "src/interface/ICloneableFactoryV2.sol";
import {ICloneableFactoryV3} from "src/interface/ICloneableFactoryV3.sol";
import {ICloneableFactoryV1} from "src/interface/deprecated/ICloneableFactoryV1.sol";
import {LibPublishedAbi} from "test/src/lib/LibPublishedAbi.sol";

/// @title ICloneableFactoryV2DeclarationTest
/// @notice `ICloneableFactoryV2` is the legacy, nonce-dependent factory
/// interface. Nothing in `src/` or `test/` imports it and it has no logic, but
/// it is PUBLISHED: it ships in the soldeer package and consumers pinned to it
/// compile against these exact bytes. Declaration-only is not the same as
/// unowned, so the surface is pinned here rather than left to drift silently.
contract ICloneableFactoryV2DeclarationTest is Test {
    /// The legacy `clone` selector.
    function testCloneSelectorPinned() external pure {
        assertEq(ICloneableFactoryV2.clone.selector, bytes4(keccak256("clone(address,bytes)")));
    }

    /// The legacy `NewClone` topic.
    function testNewCloneTopicZeroPinned() external pure {
        assertEq(ICloneableFactoryV2.NewClone.selector, keccak256("NewClone(address,address,address)"));
    }

    /// A PUBLISHED-SURFACE HAZARD, pinned as a fact rather than asserted away.
    /// Three of the four factory interfaces in this package declare an event
    /// called `NewClone`. `ICloneableFactoryV1` and `ICloneableFactoryV2`
    /// declare the SAME three-parameter signature, so they are literally the
    /// same topic and an indexer cannot tell a V1 clone from a V2 clone by
    /// `topics[0]`. `ICloneableFactoryV3` takes five parameters and is a
    /// different topic entirely. Any change to these relationships is a
    /// breaking change for every downstream indexer.
    function testNewCloneTopicRelationshipsAcrossTheFamily() external pure {
        assertEq(ICloneableFactoryV1.NewClone.selector, ICloneableFactoryV2.NewClone.selector);
        assertTrue(ICloneableFactoryV2.NewClone.selector != ICloneableFactoryV3.NewClone.selector);
    }

    /// The declaration itself, as published: three unindexed `address`
    /// parameters in the order sender, implementation, clone; and
    /// `clone(address implementation, bytes data)` returning an unnamed
    /// `address`.
    function testAbiPinned() external view {
        string memory json = LibPublishedAbi.artifactJson("ICloneableFactoryV2", "ICloneableFactoryV2");
        assertTrue(
            vm.contains(
                json,
                "{\"type\":\"event\",\"name\":\"NewClone\",\"inputs\":["
                "{\"name\":\"sender\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},"
                "{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},"
                "{\"name\":\"clone\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}"
                "],\"anonymous\":false}"
            ),
            "NewClone: sender, implementation, clone - in that order, none indexed"
        );
        assertTrue(
            vm.contains(
                json,
                "{\"type\":\"function\",\"name\":\"clone\",\"inputs\":["
                "{\"name\":\"implementation\",\"type\":\"address\",\"internalType\":\"address\"},"
                "{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}"
                "],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],"
                "\"stateMutability\":\"nonpayable\"}"
            ),
            "clone(implementation, data) returns address"
        );
    }
}
