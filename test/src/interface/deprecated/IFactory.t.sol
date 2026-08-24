// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {IFactory} from "src/interface/deprecated/IFactory.sol";
import {LibPublishedAbi} from "test/lib/LibPublishedAbi.sol";

/// @title IFactoryDeclarationTest
/// @notice Pins the PUBLISHED declaration of `IFactory`.
///
/// `src/interface/deprecated/` is imported by nothing in this repo and carries
/// no logic, but it SHIPS in the soldeer package: contracts deployed years ago
/// are still described by these ABIs and indexers still decode against them.
/// Deprecated means "do not use for new work", not "free to change" — a
/// deprecated declaration that drifts silently breaks consumers that cannot be
/// redeployed.
contract IFactoryDeclarationTest is Test {
    /// `IFactory`: the two events and the two functions. `isChild` returning
    /// `bool` is load-bearing — the interface calls it CRITICAL to the
    /// security guarantees of any implementation — and a return type is not
    /// part of a selector, so only the ABI pins it.
    function testAbiPinned() external view {
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
