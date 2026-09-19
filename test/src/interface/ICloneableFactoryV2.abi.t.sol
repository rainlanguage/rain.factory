// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {ICloneableFactoryV2} from "src/interface/ICloneableFactoryV2.sol";
import {LibPublishedAbi} from "test/lib/LibPublishedAbi.sol";

/// @title ICloneableFactoryV2AbiTest
/// @notice Pins the published ABI of `ICloneableFactoryV2`: the `clone`
/// selector from its literal signature, and each ABI entry as it appears in
/// the compiled artifact.
contract ICloneableFactoryV2AbiTest is Test {
    /// `clone(address,bytes)` selector.
    function testCloneSelectorPinned() external pure {
        assertEq(ICloneableFactoryV2.clone.selector, bytes4(keccak256("clone(address,bytes)")));
    }

    /// `NewClone`: `sender`, `implementation`, `clone`, in that order, none
    /// indexed, not anonymous.
    function testNewCloneAbiPinned() external view {
        assertTrue(
            vm.contains(
                LibPublishedAbi.artifactJson(vm, "ICloneableFactoryV2", "ICloneableFactoryV2"),
                "{\"type\":\"event\",\"name\":\"NewClone\",\"inputs\":["
                "{\"name\":\"sender\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},"
                "{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},"
                "{\"name\":\"clone\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}"
                "],\"anonymous\":false}"
            ),
            "NewClone(address sender, address implementation, address clone)"
        );
    }

    /// `clone(address implementation, bytes data)` returns an unnamed
    /// `address` and is nonpayable.
    function testCloneAbiPinned() external view {
        assertTrue(
            vm.contains(
                LibPublishedAbi.artifactJson(vm, "ICloneableFactoryV2", "ICloneableFactoryV2"),
                "{\"type\":\"function\",\"name\":\"clone\",\"inputs\":["
                "{\"name\":\"implementation\",\"type\":\"address\",\"internalType\":\"address\"},"
                "{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}"
                "],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],"
                "\"stateMutability\":\"nonpayable\"}"
            ),
            "clone(address implementation, bytes data) returns (address)"
        );
    }
}
