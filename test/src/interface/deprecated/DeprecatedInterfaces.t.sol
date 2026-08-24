// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {ICloneableV1} from "src/interface/deprecated/ICloneableV1.sol";
import {ICloneableFactoryV1} from "src/interface/deprecated/ICloneableFactoryV1.sol";
import {IFactory} from "src/interface/deprecated/IFactory.sol";
import {LibPublishedAbi} from "test/src/lib/LibPublishedAbi.sol";

/// @title DeprecatedInterfacesDeclarationTest
/// @notice `src/interface/deprecated/` is imported by nothing in this repo and
/// carries no logic, but it SHIPS in the soldeer package: contracts deployed
/// years ago are still described by these ABIs and indexers still decode
/// against them. Deprecated means "do not use for new work", not "free to
/// change" — a deprecated declaration that drifts silently breaks consumers
/// that cannot be redeployed. Everything here is therefore pinned.
contract DeprecatedInterfacesDeclarationTest is Test {
    /// `ICloneableV1.initialize` has NO return value. That is the entire
    /// V1/V2 difference, and it is invisible in the selector, so the ABI is
    /// the only place it can be pinned.
    function testICloneableV1AbiPinned() external view {
        assertEq(ICloneableV1.initialize.selector, bytes4(keccak256("initialize(bytes)")));
        assertTrue(
            vm.contains(
                LibPublishedAbi.artifactJson("ICloneableV1", "ICloneableV1"),
                "{\"type\":\"function\",\"name\":\"initialize\",\"inputs\":["
                "{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}"
                "],\"outputs\":[],\"stateMutability\":\"nonpayable\"}"
            ),
            "ICloneableV1.initialize(bytes) returns NOTHING"
        );
    }

    /// `ICloneableFactoryV1`: the three-parameter `NewClone` and `clone`.
    function testICloneableFactoryV1AbiPinned() external view {
        assertEq(ICloneableFactoryV1.NewClone.selector, keccak256("NewClone(address,address,address)"));
        assertEq(ICloneableFactoryV1.clone.selector, bytes4(keccak256("clone(address,bytes)")));

        string memory json = LibPublishedAbi.artifactJson("ICloneableFactoryV1", "ICloneableFactoryV1");
        assertTrue(
            vm.contains(
                json,
                "{\"type\":\"event\",\"name\":\"NewClone\",\"inputs\":["
                "{\"name\":\"sender\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},"
                "{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},"
                "{\"name\":\"clone\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}"
                "],\"anonymous\":false}"
            ),
            "ICloneableFactoryV1.NewClone: sender, implementation, clone, none indexed"
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
            "ICloneableFactoryV1.clone(implementation, data) returns address"
        );
    }

    /// `IFactory`: the two events and the two functions. `isChild` returning
    /// `bool` is load-bearing — the interface calls it CRITICAL to the
    /// security guarantees of any implementation — and a return type is not
    /// part of a selector, so only the ABI pins it.
    function testIFactoryAbiPinned() external view {
        assertEq(IFactory.NewChild.selector, keccak256("NewChild(address,address)"));
        assertEq(IFactory.Implementation.selector, keccak256("Implementation(address,address)"));
        assertEq(IFactory.createChild.selector, bytes4(keccak256("createChild(bytes)")));
        assertEq(IFactory.isChild.selector, bytes4(keccak256("isChild(address)")));

        string memory json = LibPublishedAbi.artifactJson("IFactory", "IFactory");
        assertTrue(
            vm.contains(
                json,
                "{\"type\":\"event\",\"name\":\"NewChild\",\"inputs\":["
                "{\"name\":\"sender\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},"
                "{\"name\":\"child\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}"
                "],\"anonymous\":false}"
            ),
            "IFactory.NewChild: sender, child, none indexed"
        );
        assertTrue(
            vm.contains(
                json,
                "{\"type\":\"event\",\"name\":\"Implementation\",\"inputs\":["
                "{\"name\":\"sender\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},"
                "{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}"
                "],\"anonymous\":false}"
            ),
            "IFactory.Implementation: sender, implementation, none indexed"
        );
        assertTrue(
            vm.contains(
                json,
                "{\"type\":\"function\",\"name\":\"createChild\",\"inputs\":["
                "{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}"
                "],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],"
                "\"stateMutability\":\"nonpayable\"}"
            ),
            "IFactory.createChild(data) returns address"
        );
        assertTrue(
            vm.contains(
                json,
                "{\"type\":\"function\",\"name\":\"isChild\",\"inputs\":["
                "{\"name\":\"maybeChild\",\"type\":\"address\",\"internalType\":\"address\"}"
                "],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],"
                "\"stateMutability\":\"view\"}"
            ),
            "IFactory.isChild(maybeChild) returns bool, view"
        );
    }
}
