// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {ICloneableV1} from "src/interface/deprecated/ICloneableV1.sol";
import {LibPublishedAbi} from "test/lib/LibPublishedAbi.sol";

/// @title ICloneableV1AbiTest
/// @notice Pins the published ABI of `ICloneableV1`: the `initialize`
/// selector from its literal signature, and its ABI entry as it appears in the
/// compiled artifact.
contract ICloneableV1AbiTest is Test {
    /// `initialize(bytes)` selector.
    function testInitializeSelectorPinned() external pure {
        assertEq(ICloneableV1.initialize.selector, bytes4(keccak256("initialize(bytes)")));
    }

    /// `initialize(bytes data)` returns nothing and is nonpayable.
    function testInitializeAbiPinned() external view {
        assertTrue(
            vm.contains(
                LibPublishedAbi.artifactJson(vm, "ICloneableV1", "ICloneableV1"),
                "{\"type\":\"function\",\"name\":\"initialize\",\"inputs\":["
                "{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}"
                "],\"outputs\":[],\"stateMutability\":\"nonpayable\"}"
            ),
            "initialize(bytes data) returns nothing"
        );
    }
}
