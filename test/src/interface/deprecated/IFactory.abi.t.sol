// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {IFactory} from "src/interface/deprecated/IFactory.sol";
import {LibPublishedAbi} from "test/lib/LibPublishedAbi.sol";

/// @title IFactoryAbiTest
/// @notice Pins the published ABI of `IFactory`: event topics and function
/// selectors from their literal signatures, and each ABI entry as it appears
/// in the compiled artifact.
contract IFactoryAbiTest is Test {
    /// `NewChild(address,address)` and `Implementation(address,address)`
    /// topics.
    function testEventTopicsPinned() external pure {
        assertEq(IFactory.NewChild.selector, keccak256("NewChild(address,address)"));
        assertEq(IFactory.Implementation.selector, keccak256("Implementation(address,address)"));
    }

    /// `createChild(bytes)` and `isChild(address)` selectors.
    function testFunctionSelectorsPinned() external pure {
        assertEq(IFactory.createChild.selector, bytes4(keccak256("createChild(bytes)")));
        assertEq(IFactory.isChild.selector, bytes4(keccak256("isChild(address)")));
    }

    /// `NewChild`: `sender`, `child`, in that order, none indexed, not
    /// anonymous.
    function testNewChildAbiPinned() external view {
        assertTrue(
            vm.contains(
                LibPublishedAbi.artifactJson(vm, "IFactory", "IFactory"),
                "{\"type\":\"event\",\"name\":\"NewChild\",\"inputs\":["
                "{\"name\":\"sender\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},"
                "{\"name\":\"child\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}"
                "],\"anonymous\":false}"
            ),
            "NewChild(address sender, address child)"
        );
    }

    /// `Implementation`: `sender`, `implementation`, in that order, none
    /// indexed, not anonymous.
    function testImplementationAbiPinned() external view {
        assertTrue(
            vm.contains(
                LibPublishedAbi.artifactJson(vm, "IFactory", "IFactory"),
                "{\"type\":\"event\",\"name\":\"Implementation\",\"inputs\":["
                "{\"name\":\"sender\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},"
                "{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}"
                "],\"anonymous\":false}"
            ),
            "Implementation(address sender, address implementation)"
        );
    }

    /// `createChild(bytes data)` returns an unnamed `address` and is
    /// nonpayable.
    function testCreateChildAbiPinned() external view {
        assertTrue(
            vm.contains(
                LibPublishedAbi.artifactJson(vm, "IFactory", "IFactory"),
                "{\"type\":\"function\",\"name\":\"createChild\",\"inputs\":["
                "{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}"
                "],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],"
                "\"stateMutability\":\"nonpayable\"}"
            ),
            "createChild(bytes data) returns (address)"
        );
    }

    /// `isChild(address maybeChild)` returns an unnamed `bool` and is view.
    function testIsChildAbiPinned() external view {
        assertTrue(
            vm.contains(
                LibPublishedAbi.artifactJson(vm, "IFactory", "IFactory"),
                "{\"type\":\"function\",\"name\":\"isChild\",\"inputs\":["
                "{\"name\":\"maybeChild\",\"type\":\"address\",\"internalType\":\"address\"}"
                "],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],"
                "\"stateMutability\":\"view\"}"
            ),
            "isChild(address maybeChild) view returns (bool)"
        );
    }
}
