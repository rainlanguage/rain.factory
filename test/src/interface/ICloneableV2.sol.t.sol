// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.16.1/src/Test.sol";

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "src/interface/ICloneableV2.sol";
import {ICloneableV1} from "src/interface/deprecated/ICloneableV1.sol";
import {LibPublishedAbi} from "test/src/lib/LibPublishedAbi.sol";
import {TestCloneFactory} from "test/src/concrete/TestCloneFactory.sol";
import {TestCloneableConformant} from "test/src/concrete/TestCloneableConformant.sol";
import {TestCloneableEmitter} from "test/src/concrete/TestCloneableEmitter.sol";
import {TestCloneableReverter} from "test/src/concrete/TestCloneableReverter.sol";

/// @title ICloneableV2DeclarationTest
/// @notice Pins the PUBLISHED declaration of `ICloneableV2` and makes its two
/// normative MUSTs executable.
///
/// `initialize`'s selector is compile-guarded — retype or rename it and the
/// library stops compiling — but `InitializeSignatureFn` is not: nothing in
/// this repo referenced it before this file, so its selector could drift
/// freely while every test stayed green. It is the error every conforming
/// implementation is required to revert with, so its selector is exactly the
/// kind of value a downstream consumer decodes.
contract ICloneableV2DeclarationTest is Test {
    /// The `TestCloneFactory` instance under test. Stateless, so reused
    /// everywhere.
    TestCloneFactory internal immutable I_CLONE_FACTORY;

    constructor() {
        I_CLONE_FACTORY = new TestCloneFactory();
    }

    /// The generic entry point's selector — what `cloneAndInitialize` calls.
    function testInitializeSelectorPinned() external pure {
        assertEq(ICloneableV2.initialize.selector, bytes4(keccak256("initialize(bytes)")));
    }

    /// `ICloneableV1.initialize` and `ICloneableV2.initialize` publish the
    /// SAME selector and differ only in return arity — the whole of the V1/V2
    /// difference, and the reason a V4 factory cannot tell one from the other
    /// before calling it.
    function testInitializeSelectorSharedWithV1() external pure {
        assertEq(ICloneableV1.initialize.selector, ICloneableV2.initialize.selector);
    }

    /// The error every conforming implementation's typed overload must revert
    /// with, pinned from its literal signature.
    function testInitializeSignatureFnSelectorPinned() external pure {
        assertEq(ICloneableV2.InitializeSignatureFn.selector, bytes4(keccak256("InitializeSignatureFn()")));
    }

    /// The success sentinel is the hash of the documented string.
    function testSuccessSentinelPinned() external pure {
        assertEq(ICLONEABLE_V2_SUCCESS, keccak256("ICloneableV2.initialize"));
    }

    /// THE DECLARATION ITSELF: `initialize(bytes data)` returning a named
    /// `bytes32 success`, and a zero-parameter `InitializeSignatureFn` error.
    /// Return types and parameter names are outside the selector, so this is
    /// the only place they are pinned.
    function testAbiPinned() external view {
        string memory json = LibPublishedAbi.artifactJson("ICloneableV2", "ICloneableV2");
        assertTrue(
            vm.contains(
                json,
                "{\"type\":\"function\",\"name\":\"initialize\",\"inputs\":["
                "{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}"
                "],\"outputs\":[{\"name\":\"success\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],"
                "\"stateMutability\":\"nonpayable\"}"
            ),
            "initialize(bytes data) returns (bytes32 success)"
        );
        assertTrue(
            vm.contains(json, "{\"type\":\"error\",\"name\":\"InitializeSignatureFn\",\"inputs\":[]}"),
            "error InitializeSignatureFn() takes no parameters"
        );
    }

    /// MUST: `initialize` can NOT be called more than once. Exercised end to
    /// end on a clone the factory just produced, so the guard is proven where
    /// it matters — after the factory's own atomic initialization has already
    /// consumed the one permitted call. The stored data is unchanged by the
    /// rejected second call.
    function testInitializeOnlyOnce(bytes32 salt, bytes memory data, bytes memory otherData) external {
        TestCloneableConformant implementation = new TestCloneableConformant();

        address child = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);
        assertEq(TestCloneableConformant(child).sData(), data);

        vm.expectRevert(abi.encodeWithSelector(TestCloneableConformant.AlreadyInitialized.selector));
        TestCloneableConformant(child).initialize(otherData);

        assertEq(TestCloneableConformant(child).sData(), data);
    }

    /// MUST: a typed overload of `initialize` reverts `InitializeSignatureFn`
    /// always, so it is never accidentally called in place of the generic
    /// `initialize(bytes)` the factory calls. Asserted on a clone, uninitialized
    /// and initialized alike — "always" means both.
    function testTypedOverloadRevertsInitializeSignatureFn(bytes32 salt, bytes memory data, uint256 value) external {
        TestCloneableConformant implementation = new TestCloneableConformant();

        vm.expectRevert(abi.encodeWithSelector(ICloneableV2.InitializeSignatureFn.selector));
        implementation.initialize(value);

        address child = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);

        vm.expectRevert(abi.encodeWithSelector(ICloneableV2.InitializeSignatureFn.selector));
        TestCloneableConformant(child).initialize(value);
    }

    /// A revert inside `initialize` reaches the caller VERBATIM — the
    /// implementation's own typed error with its own data — rather than being
    /// flattened into the library's `InitializationFailed`, which is reserved
    /// for the case where `initialize` RETURNS the wrong sentinel. Nothing is
    /// deployed at the address either way.
    function testInitializeRevertBubblesVerbatim(bytes32 salt, bytes memory data) external {
        TestCloneableReverter implementation = new TestCloneableReverter();

        address predicted = I_CLONE_FACTORY.predictDeterministicAddress(address(implementation), salt, address(this));

        vm.expectRevert(abi.encodeWithSelector(TestCloneableReverter.InitializeReverted.selector, data));
        I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);

        assertEq(predicted.code.length, 0);
    }

    /// The factory calls `initialize(bytes)` and NOTHING ELSE on the fresh
    /// proxy, and `NewClone` is the FIRST log of the deploy. Both clauses are
    /// only observable through an implementation that emits, which is why this
    /// fixture exists: the log stream is exactly `NewClone` then the clone's
    /// own `Initialized`, with no `UnexpectedCall` anywhere, and the data the
    /// clone saw is the data the caller passed, byte for byte.
    function testNothingCalledBeforeInitialize(bytes32 salt, bytes memory data) external {
        TestCloneableEmitter implementation = new TestCloneableEmitter();

        vm.recordLogs();
        address child = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries.length, 2, "exactly NewClone and the clone's own Initialized");

        assertEq(entries[0].emitter, address(I_CLONE_FACTORY));
        assertEq(entries[0].topics[0], keccak256("NewClone(address,address,address,bytes32,bytes)"));

        assertEq(entries[1].emitter, child, "the second log is the clone's own");
        assertEq(entries[1].topics[0], keccak256("Initialized(bytes)"));
        assertEq(entries[1].data, abi.encode(data), "initialize received the caller's data verbatim");
    }
}
