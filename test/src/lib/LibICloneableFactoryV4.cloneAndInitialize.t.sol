// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {ICLONEABLE_V2_SUCCESS} from "src/interface/ICloneableV2.sol";
import {InitializationFailed} from "src/lib/LibICloneableFactoryV4.sol";
import {TestCloneFactory} from "test/concrete/TestCloneFactory.sol";
import {TestCloneableRawAnswer} from "test/concrete/TestCloneableRawAnswer.sol";

/// @title LibICloneableFactoryV4CloneAndInitializeTest
/// @notice How `cloneAndInitialize` treats each `initialize` answer, through
/// both clone entry points.
contract LibICloneableFactoryV4CloneAndInitializeTest is Test {
    TestCloneFactory internal immutable I_CLONE_FACTORY;

    constructor() {
        I_CLONE_FACTORY = new TestCloneFactory();
    }

    /// Both entry points revert with exactly `expected` when `initialize`
    /// reverts with (`reverts`) or returns `answer`.
    function checkBothEntryPointsRevert(bool reverts, bytes memory answer, bytes32 salt, bytes memory expected)
        internal
    {
        address implementation = address(new TestCloneableRawAnswer());
        bytes memory data = abi.encode(reverts, answer);
        vm.expectRevert(expected);
        I_CLONE_FACTORY.cloneDeterministic(implementation, data, salt);
        vm.expectRevert(expected);
        I_CLONE_FACTORY.cloneDeterministicOpenSalt(implementation, data, salt);
    }

    /// An empty return, as from an `ICloneableV1`, is `InitializationFailed`.
    function testInitializeReturnsNothingRevertsInitializationFailed(bytes32 salt) external {
        checkBothEntryPointsRevert(false, "", salt, abi.encodeWithSelector(InitializationFailed.selector));
    }

    /// The sentinel followed by any bytes is `InitializationFailed`.
    function testInitializeReturnsSentinelWithTrailingBytesRevertsInitializationFailed(
        bytes memory trailing,
        bytes32 salt
    ) external {
        vm.assume(trailing.length > 0);
        checkBothEntryPointsRevert(
            false,
            abi.encodePacked(ICLONEABLE_V2_SUCCESS, trailing),
            salt,
            abi.encodeWithSelector(InitializationFailed.selector)
        );
    }

    /// A revert with no data is `InitializationFailed`.
    function testInitializeRevertsWithoutDataRevertsInitializationFailed(bytes32 salt) external {
        checkBothEntryPointsRevert(true, "", salt, abi.encodeWithSelector(InitializationFailed.selector));
    }

    /// A revert whose data is the 32-byte sentinel bubbles verbatim.
    function testInitializeRevertsWithSentinelBubblesVerbatim(bytes32 salt) external {
        bytes memory sentinel = abi.encodePacked(ICLONEABLE_V2_SUCCESS);
        checkBothEntryPointsRevert(true, sentinel, salt, sentinel);
    }
}
