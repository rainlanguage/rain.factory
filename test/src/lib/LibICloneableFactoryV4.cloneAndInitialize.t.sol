// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {InitializationFailed} from "src/lib/LibICloneableFactoryV4.sol";
import {TestCloneFactory} from "test/concrete/TestCloneFactory.sol";
import {TestNotCloneable} from "test/concrete/TestNotCloneable.sol";
import {TestFallbackRawReturn} from "test/concrete/TestFallbackRawReturn.sol";
import {TestCloneableRawRevert} from "test/concrete/TestCloneableRawRevert.sol";

/// @title LibICloneableFactoryV4CloneAndInitializeTest
/// @notice Tests the `ICloneableV2.initialize` check in
/// `LibICloneableFactoryV4.cloneAndInitialize`, the tail shared by both clone
/// entry points, through `TestCloneFactory`. Every case is run through BOTH
/// `cloneDeterministic` and `cloneDeterministicOpenSalt`, so the check is
/// pinned as a property of the shared tail and not of one entry point.
///
/// The property: the clone is created only if `initialize` returns exactly
/// the 32-byte word `keccak256("ICloneableV2.initialize")`. Every other answer
/// that carries no diagnosis of its own — a revert with no data, a return of
/// any other length, a wrong word — is `InitializationFailed`; a revert WITH
/// data is the implementation's own and bubbles out verbatim. The sentinel is
/// written out from the literal string the interface names, never imported.
contract LibICloneableFactoryV4CloneAndInitializeTest is Test {
    /// The `TestCloneFactory` instance under test. Stateless, so reused
    /// everywhere.
    TestCloneFactory internal immutable I_CLONE_FACTORY;

    constructor() {
        I_CLONE_FACTORY = new TestCloneFactory();
    }

    /// Runs `cloneDeterministic` and `cloneDeterministicOpenSalt` for
    /// `(implementation, data, salt)`, expects each to revert with EXACTLY
    /// `expectedRevertData`, and checks each left its predicted address empty:
    /// nothing is created on a failed initialize.
    function checkBothEntryPointsRevert(
        address implementation,
        bytes memory data,
        bytes32 salt,
        bytes memory expectedRevertData
    ) internal {
        address predicted = I_CLONE_FACTORY.predictDeterministicAddress(implementation, salt, address(this));
        vm.expectRevert(expectedRevertData);
        I_CLONE_FACTORY.cloneDeterministic(implementation, data, salt);
        assertEq(predicted.code.length, 0);

        address predictedOpenSalt = I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(implementation, data, salt);
        vm.expectRevert(expectedRevertData);
        I_CLONE_FACTORY.cloneDeterministicOpenSalt(implementation, data, salt);
        assertEq(predictedOpenSalt.code.length, 0);
    }

    /// An implementation that has code but no `initialize(bytes)` and no
    /// fallback: the call reverts with no data and the factory reports it as
    /// `InitializationFailed`, not as a bare `0x`.
    function testInitializeAbsentRevertsInitializationFailed(bytes memory data, bytes32 salt) external {
        TestNotCloneable implementation = new TestNotCloneable();
        checkBothEntryPointsRevert(
            address(implementation), data, salt, abi.encodeWithSelector(InitializationFailed.selector)
        );
    }

    /// An implementation whose fallback answers `initialize` with no return
    /// data at all is `InitializationFailed`.
    function testInitializeReturnsNothingRevertsInitializationFailed(bytes32 salt) external {
        TestFallbackRawReturn implementation = new TestFallbackRawReturn();
        checkBothEntryPointsRevert(
            address(implementation), "", salt, abi.encodeWithSelector(InitializationFailed.selector)
        );
    }

    /// Any return that is not exactly 32 bytes — shorter or longer — is
    /// `InitializationFailed`, whatever the bytes are.
    function testInitializeReturnsWrongLengthRevertsInitializationFailed(bytes memory rawReturn, bytes32 salt)
        external
    {
        vm.assume(rawReturn.length != 32);
        TestFallbackRawReturn implementation = new TestFallbackRawReturn();
        checkBothEntryPointsRevert(
            address(implementation), rawReturn, salt, abi.encodeWithSelector(InitializationFailed.selector)
        );
    }

    /// The sentinel followed by anything at all is not the sentinel: a return
    /// whose first word is the success hash but that is longer than one word is
    /// `InitializationFailed`. The check is on the exact 32 bytes, not on a
    /// decoded first word.
    function testInitializeReturnsSentinelWithTrailingBytesRevertsInitializationFailed(
        bytes memory trailing,
        bytes32 salt
    ) external {
        vm.assume(trailing.length > 0);
        TestFallbackRawReturn implementation = new TestFallbackRawReturn();
        bytes memory rawReturn = abi.encodePacked(keccak256("ICloneableV2.initialize"), trailing);
        checkBothEntryPointsRevert(
            address(implementation), rawReturn, salt, abi.encodeWithSelector(InitializationFailed.selector)
        );
    }

    /// A 32-byte word that is not the sentinel is `InitializationFailed`.
    function testInitializeReturnsWrongWordRevertsInitializationFailed(bytes32 notSuccess, bytes32 salt) external {
        vm.assume(notSuccess != keccak256("ICloneableV2.initialize"));
        TestFallbackRawReturn implementation = new TestFallbackRawReturn();
        checkBothEntryPointsRevert(
            address(implementation),
            abi.encodePacked(notSuccess),
            salt,
            abi.encodeWithSelector(InitializationFailed.selector)
        );
    }

    /// Exactly the 32-byte sentinel is the one answer that creates the clone,
    /// through both entry points: each lands at its predicted address as an
    /// EIP-1167 proxy of the implementation. Pins that the raw-return fixture
    /// and the check agree on what success looks like, so the failing cases
    /// above fail for their shape and not for the fixture.
    function testInitializeReturnsSentinelSucceeds(bytes32 salt) external {
        TestFallbackRawReturn implementation = new TestFallbackRawReturn();
        bytes memory data = abi.encodePacked(keccak256("ICloneableV2.initialize"));
        bytes memory runtime =
            abi.encodePacked(hex"363d3d373d3d3d363d73", address(implementation), hex"5af43d82803e903d91602b57fd5bf3");

        address predicted = I_CLONE_FACTORY.predictDeterministicAddress(address(implementation), salt, address(this));
        address child = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);
        assertEq(child, predicted);
        assertEq(child.code, runtime);

        address predictedOpenSalt =
            I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(address(implementation), data, salt);
        address childOpenSalt = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt);
        assertEq(childOpenSalt, predictedOpenSalt);
        assertEq(childOpenSalt.code, runtime);
    }

    /// An `initialize` that reverts with NO data — a bare `revert()` — is
    /// `InitializationFailed`: there is no diagnosis of the implementation's
    /// own to bubble, so the factory supplies its typed one.
    function testInitializeRevertsWithoutDataRevertsInitializationFailed(bytes32 salt) external {
        TestCloneableRawRevert implementation = new TestCloneableRawRevert();
        checkBothEntryPointsRevert(
            address(implementation), "", salt, abi.encodeWithSelector(InitializationFailed.selector)
        );
    }

    /// An `initialize` that reverts WITH data bubbles that data out of the
    /// factory byte for byte — the implementation's own diagnosis is never
    /// replaced by `InitializationFailed`.
    function testInitializeRevertsWithDataBubblesVerbatim(bytes memory revertData, bytes32 salt) external {
        vm.assume(revertData.length > 0);
        TestCloneableRawRevert implementation = new TestCloneableRawRevert();
        checkBothEntryPointsRevert(address(implementation), revertData, salt, revertData);
    }
}
