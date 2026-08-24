// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {ICloneableFactoryV1} from "src/interface/deprecated/ICloneableFactoryV1.sol";
import {LibPublishedAbi} from "test/lib/LibPublishedAbi.sol";

/// @title ICloneableFactoryV1DeclarationTest
/// @notice Pins the PUBLISHED declaration of `ICloneableFactoryV1`.
///
/// `src/interface/deprecated/` is imported by nothing in this repo and carries
/// no logic, but it SHIPS in the soldeer package: contracts deployed years ago
/// are still described by these ABIs and indexers still decode against them.
/// Deprecated means "do not use for new work", not "free to change" — a
/// deprecated declaration that drifts silently breaks consumers that cannot be
/// redeployed.
contract ICloneableFactoryV1DeclarationTest is Test {
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
}
