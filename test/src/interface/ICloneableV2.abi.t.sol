// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {ICloneableV2} from "src/interface/ICloneableV2.sol";
import {LibPublishedAbi} from "test/lib/LibPublishedAbi.sol";

/// @title ICloneableV2AbiTest
/// @notice Pins the published ABI of `ICloneableV2`: selectors from their
/// literal signatures, and each ABI entry as it appears in the compiled
/// artifact.
contract ICloneableV2AbiTest is Test {
    /// `initialize(bytes)` selector.
    function testInitializeSelectorPinned() external pure {
        assertEq(ICloneableV2.initialize.selector, bytes4(keccak256("initialize(bytes)")));
    }

    /// `InitializeSignatureFn()` selector.
    function testInitializeSignatureFnSelectorPinned() external pure {
        assertEq(ICloneableV2.InitializeSignatureFn.selector, bytes4(keccak256("InitializeSignatureFn()")));
    }

    /// `initialize(bytes data)` returns `bytes32 success` and is nonpayable.
    function testInitializeAbiPinned() external view {
        assertTrue(
            vm.contains(
                LibPublishedAbi.artifactJson(vm, "ICloneableV2", "ICloneableV2"),
                "{\"type\":\"function\",\"name\":\"initialize\",\"inputs\":["
                "{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}"
                "],\"outputs\":[{\"name\":\"success\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],"
                "\"stateMutability\":\"nonpayable\"}"
            ),
            "initialize(bytes data) returns (bytes32 success)"
        );
    }

    /// `InitializeSignatureFn` takes no parameters.
    function testInitializeSignatureFnAbiPinned() external view {
        assertTrue(
            vm.contains(
                LibPublishedAbi.artifactJson(vm, "ICloneableV2", "ICloneableV2"),
                "{\"type\":\"error\",\"name\":\"InitializeSignatureFn\",\"inputs\":[]}"
            ),
            "error InitializeSignatureFn()"
        );
    }
}
