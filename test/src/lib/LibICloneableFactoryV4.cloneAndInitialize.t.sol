// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.16.1/src/Test.sol";

import {ICLONEABLE_V2_SUCCESS} from "src/interface/ICloneableV2.sol";
import {CloneAddressOccupied, DelegatedImplementation, InitializationFailed} from "src/lib/LibICloneableFactoryV4.sol";
import {TestCloneFactory} from "test/concrete/TestCloneFactory.sol";
import {TestCloneable} from "test/concrete/TestCloneable.sol";
import {TestCloneableNestedClone} from "test/concrete/TestCloneableNestedClone.sol";
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

    /// The library holds no state, so a clone may clone through the same
    /// factory during its own `initialize` — an orchestrator deploying its own
    /// parts is the shape. Both clones land at their own derivation's address
    /// and are initialized with their own bytes, and the outer `NewClone` —
    /// emitted before `initialize` runs — precedes the nested one, whose sender
    /// is the outer clone.
    function testNestedCloneDuringInitialize(bytes32 outerSalt, bytes32 innerSalt, bytes memory innerData) external {
        TestCloneable innerImplementation = new TestCloneable();
        TestCloneableNestedClone outerImplementation = new TestCloneableNestedClone();

        bytes memory outerData =
            abi.encode(address(I_CLONE_FACTORY), address(innerImplementation), innerSalt, innerData);

        address predictedOuter =
            I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(address(outerImplementation), outerData, outerSalt);
        address predictedInner =
            I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(address(innerImplementation), innerData, innerSalt);

        vm.recordLogs();
        address outer = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(outerImplementation), outerData, outerSalt);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(outer, predictedOuter);
        assertEq(TestCloneableNestedClone(outer).sInner(), predictedInner);
        assertEq(TestCloneable(predictedInner).sData(), innerData);

        assertEq(entries.length, 2);
        assertEq(entries[0].emitter, address(I_CLONE_FACTORY));
        assertEq(entries[0].topics[0], bytes32(uint256(keccak256("NewClone(address,address,address,bytes32,bytes)"))));
        assertEq(entries[0].data, abi.encode(address(this), address(outerImplementation), outer, outerSalt, outerData));
        assertEq(entries[1].emitter, address(I_CLONE_FACTORY));
        assertEq(entries[1].topics[0], bytes32(uint256(keccak256("NewClone(address,address,address,bytes32,bytes)"))));
        assertEq(entries[1].data, abi.encode(outer, address(innerImplementation), predictedInner, innerSalt, innerData));
    }

    /// A nested clone that reverts takes the whole outer deploy with it.
    /// Re-entering at a salt the factory already occupies reverts
    /// `CloneAddressOccupied` with that address, and the outer clone is not
    /// left half-built: its `(deployer, salt)` is still free afterwards, so the
    /// same deploy at a free inner salt still lands at the address it always
    /// predicted. `data` is outside the namespaced derivation, which is what
    /// lets the retry change the inner salt and keep the outer address.
    function testNestedCloneAtOccupiedAddressUnwindsOuterDeploy(
        bytes32 outerSalt,
        bytes32 takenInnerSalt,
        bytes32 freeInnerSalt,
        bytes memory innerData
    ) external {
        vm.assume(takenInnerSalt != freeInnerSalt);
        TestCloneable innerImplementation = new TestCloneable();
        TestCloneableNestedClone outerImplementation = new TestCloneableNestedClone();

        address inner =
            I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(innerImplementation), innerData, takenInnerSalt);
        address predictedOuter =
            I_CLONE_FACTORY.predictDeterministicAddress(address(outerImplementation), outerSalt, address(this));

        vm.expectRevert(abi.encodeWithSelector(CloneAddressOccupied.selector, inner));
        I_CLONE_FACTORY.cloneDeterministic(
            address(outerImplementation),
            abi.encode(address(I_CLONE_FACTORY), address(innerImplementation), takenInnerSalt, innerData),
            outerSalt
        );

        address outer = I_CLONE_FACTORY.cloneDeterministic(
            address(outerImplementation),
            abi.encode(address(I_CLONE_FACTORY), address(innerImplementation), freeInnerSalt, innerData),
            outerSalt
        );

        assertEq(outer, predictedOuter);
        assertEq(TestCloneable(TestCloneableNestedClone(outer).sInner()).sData(), innerData);
        assertEq(TestCloneable(inner).sData(), innerData);
    }
}
