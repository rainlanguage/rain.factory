// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {ICloneableV1} from "src/interface/deprecated/ICloneableV1.sol";
import {LibPublishedAbi} from "test/lib/LibPublishedAbi.sol";

/// @title ICloneableV1DeclarationTest
/// @notice Pins the PUBLISHED declaration of `ICloneableV1`.
///
/// `src/interface/deprecated/` is imported by nothing in this repo and carries
/// no logic, but it SHIPS in the soldeer package: contracts deployed years ago
/// are still described by these ABIs and indexers still decode against them.
/// Deprecated means "do not use for new work", not "free to change" — a
/// deprecated declaration that drifts silently breaks consumers that cannot be
/// redeployed.
contract ICloneableV1DeclarationTest is Test {
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
}
