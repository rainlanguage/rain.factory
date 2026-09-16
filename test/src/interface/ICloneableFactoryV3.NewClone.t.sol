// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {ICloneableFactoryV1} from "src/interface/deprecated/ICloneableFactoryV1.sol";
import {ICloneableFactoryV2} from "src/interface/ICloneableFactoryV2.sol";
import {ICloneableFactoryV3} from "src/interface/ICloneableFactoryV3.sol";

/// @title ICloneableFactoryV3NewCloneTest
/// @notice Pins the wire identity of every `NewClone` this package publishes.
/// Each topic is recomputed from the literal ABI signature string, never read
/// back from the declaration it checks, so a declaration that drifts from its
/// documented signature fails here.
contract ICloneableFactoryV3NewCloneTest is Test {
    /// `ICloneableFactoryV1.NewClone` and `ICloneableFactoryV2.NewClone` are the
    /// same signature, so the same topic: a log with this topic does not say
    /// which of the two interfaces the emitting factory implements.
    function testNewCloneV1V2ShareTopic() external pure {
        bytes32 legacyTopic = keccak256("NewClone(address,address,address)");
        assertEq(ICloneableFactoryV1.NewClone.selector, legacyTopic);
        assertEq(ICloneableFactoryV2.NewClone.selector, legacyTopic);
    }

    /// `ICloneableFactoryV3.NewClone` carries salt and data, so its topic is
    /// distinct from the V1/V2 one: the two overloads are separable on the wire
    /// by topic even though they share a name.
    function testNewCloneV3TopicDistinctFromV2() external pure {
        bytes32 deterministicTopic = keccak256("NewClone(address,address,address,bytes32,bytes)");
        assertEq(ICloneableFactoryV3.NewClone.selector, deterministicTopic);
        assertTrue(ICloneableFactoryV3.NewClone.selector != ICloneableFactoryV2.NewClone.selector);
    }
}
