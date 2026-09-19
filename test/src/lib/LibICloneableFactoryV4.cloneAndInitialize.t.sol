// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {ICLONEABLE_V2_SUCCESS} from "src/interface/ICloneableV2.sol";
import {DelegatedImplementation, InitializationFailed} from "src/lib/LibICloneableFactoryV4.sol";
import {TestCloneFactory} from "test/concrete/TestCloneFactory.sol";
import {TestCloneable} from "test/concrete/TestCloneable.sol";
import {TestCloneableRawAnswer} from "test/concrete/TestCloneableRawAnswer.sol";

/// @title LibICloneableFactoryV4CloneAndInitializeTest
/// @notice How `cloneAndInitialize` guards the implementation and treats each
/// `initialize` answer, through both clone entry points.
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

    /// A revert with 1, 4 or 31 bytes of data bubbles verbatim.
    function testInitializeRevertsWithSubWordDataBubblesVerbatim(bytes32 salt) external {
        bytes memory oneByte = hex"01";
        checkBothEntryPointsRevert(true, oneByte, salt, oneByte);
        bytes memory selector = hex"deadbeef";
        checkBothEntryPointsRevert(true, selector, salt, selector);
        bytes memory thirtyOneBytes = new bytes(31);
        thirtyOneBytes[30] = 0x01;
        checkBothEntryPointsRevert(true, thirtyOneBytes, salt, thirtyOneBytes);
    }

    /// A revert with any nonempty data bubbles verbatim.
    function testInitializeRevertsWithDataBubblesVerbatim(bytes memory revertData, bytes32 salt) external {
        vm.assume(revertData.length > 0);
        checkBothEntryPointsRevert(true, revertData, salt, revertData);
    }

    /// A return of 1 to 31 bytes, even a prefix of the sentinel, is
    /// `InitializationFailed`.
    function testInitializeReturnsSubWordRevertsInitializationFailed(uint256 length, bytes32 salt) external {
        length = bound(length, 1, 31);
        bytes32 sentinel = ICLONEABLE_V2_SUCCESS;
        bytes memory answer = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            answer[i] = sentinel[i];
        }
        checkBothEntryPointsRevert(false, answer, salt, abi.encodeWithSelector(InitializationFailed.selector));
    }

    /// An implementation whose code is an EIP-7702 delegation designator is
    /// `DelegatedImplementation`.
    function testDelegatedImplementationRevertsDelegatedImplementation(
        address delegate,
        bytes memory data,
        bytes32 salt
    ) external {
        address implementation = makeAddr("delegated-implementation");
        vm.etch(implementation, abi.encodePacked(hex"ef0100", delegate));
        vm.expectRevert(abi.encodeWithSelector(DelegatedImplementation.selector));
        I_CLONE_FACTORY.cloneDeterministic(implementation, data, salt);
        vm.expectRevert(abi.encodeWithSelector(DelegatedImplementation.selector));
        I_CLONE_FACTORY.cloneDeterministicOpenSalt(implementation, data, salt);
    }

    /// A clone address that holds ETH but no code deploys through both entry
    /// points, and the clone keeps that ETH.
    function testPrefundedCloneAddressDeploys(uint256 balance, bytes memory data, bytes32 salt) external {
        balance = bound(balance, 1, type(uint128).max);
        address implementation = address(new TestCloneable());

        address predicted = I_CLONE_FACTORY.predictDeterministicAddress(implementation, salt, address(this));
        vm.deal(predicted, balance);
        assertEq(I_CLONE_FACTORY.cloneDeterministic(implementation, data, salt), predicted);
        assertEq(predicted.balance, balance);

        address predictedOpenSalt = I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(implementation, data, salt);
        vm.deal(predictedOpenSalt, balance);
        assertEq(I_CLONE_FACTORY.cloneDeterministicOpenSalt(implementation, data, salt), predictedOpenSalt);
        assertEq(predictedOpenSalt.balance, balance);
    }
}
