// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.16.1/src/Test.sol";

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "src/interface/ICloneableV2.sol";
import {ICloneableV1} from "src/interface/deprecated/ICloneableV1.sol";
import {LibPublishedAbi} from "test/lib/LibPublishedAbi.sol";
import {TestCloneFactory} from "test/concrete/TestCloneFactory.sol";
import {TestCloneable, TestCloneableAlreadyInitialized} from "test/concrete/TestCloneable.sol";
import {TestCloneableRevert, TestCloneableRevertInitialize} from "test/concrete/TestCloneableRevert.sol";
import {TestCloneableCallRecorder} from "test/concrete/TestCloneableCallRecorder.sol";
import {TestCloneableV1Shaped} from "test/concrete/TestCloneableV1Shaped.sol";

/// @title ICloneableV2InitializeTest
/// @notice Pins the PUBLISHED declaration of `ICloneableV2.initialize` and
/// makes the interface's two normative MUSTs executable.
///
/// `initialize`'s selector is compile-guarded — retype or rename it and the
/// library stops compiling — but `InitializeSignatureFn` is not: nothing in
/// this repo referenced it before this file, so its selector could drift
/// freely while every test stayed green. It is the error every conforming
/// implementation is required to revert with, so its selector is exactly the
/// kind of value a downstream consumer decodes.
contract ICloneableV2InitializeTest is Test {
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
        TestCloneable implementation = new TestCloneable();

        address child = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);
        assertEq(TestCloneable(child).sData(), data);

        vm.expectRevert(abi.encodeWithSelector(TestCloneableAlreadyInitialized.selector));
        TestCloneable(child).initialize(otherData);

        assertEq(TestCloneable(child).sData(), data);
    }

    /// MUST: a typed overload of `initialize` reverts `InitializeSignatureFn`
    /// always, so it is never accidentally called in place of the generic
    /// `initialize(bytes)` the factory calls. Asserted on a clone, uninitialized
    /// and initialized alike — "always" means both.
    function testTypedOverloadRevertsInitializeSignatureFn(bytes32 salt, bytes memory data, uint256 value) external {
        TestCloneable implementation = new TestCloneable();

        vm.expectRevert(abi.encodeWithSelector(ICloneableV2.InitializeSignatureFn.selector));
        implementation.initialize(value);

        address child = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);

        vm.expectRevert(abi.encodeWithSelector(ICloneableV2.InitializeSignatureFn.selector));
        TestCloneable(child).initialize(value);
    }

    /// A revert inside `initialize` reaches the caller VERBATIM — the
    /// implementation's own typed error with its own data — rather than being
    /// flattened into the library's `InitializationFailed`, which is reserved
    /// for the case where `initialize` RETURNS the wrong sentinel. Nothing is
    /// deployed at the address either way.
    function testInitializeRevertBubblesVerbatim(bytes32 salt, bytes memory data) external {
        TestCloneableRevert implementation = new TestCloneableRevert();

        address predicted = I_CLONE_FACTORY.predictDeterministicAddress(address(implementation), salt, address(this));

        vm.expectRevert(abi.encodeWithSelector(TestCloneableRevertInitialize.selector, data));
        I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);

        assertEq(predicted.code.length, 0);
    }

    /// The factory calls `initialize(bytes)` and NOTHING ELSE on the fresh
    /// proxy, and `NewClone` is the FIRST log of the deploy.
    ///
    /// Two separate oracles, because the fixture carries two. The recorded
    /// SELECTOR SEQUENCE is the direct evidence for the MUST NOT: exactly one
    /// call reached the clone and it was `initialize(bytes)`, so a stray call
    /// cannot hide in a log stream that happens to look right. The LOG STREAM
    /// is what orders `NewClone` against the clone's own initialization, which
    /// no amount of end-state inspection can show.
    function testNothingCalledBeforeInitialize(bytes32 salt, bytes memory data) external {
        TestCloneableCallRecorder implementation = new TestCloneableCallRecorder();

        vm.recordLogs();
        address child = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes4[] memory selectors = TestCloneableCallRecorder(child).selectors();
        assertEq(selectors.length, 1, "exactly one call reached the clone");
        assertEq(selectors[0], ICloneableV2.initialize.selector, "and it was initialize(bytes)");

        assertEq(entries.length, 2, "exactly NewClone and the clone's own Initializing");

        assertEq(entries[0].emitter, address(I_CLONE_FACTORY));
        assertEq(entries[0].topics[0], keccak256("NewClone(address,address,address,bytes32,bytes)"));

        assertEq(entries[1].emitter, child, "the second log is the clone's own");
        assertEq(entries[1].topics[0], keccak256("Initializing(bytes)"));
        assertEq(entries[1].data, abi.encode(data), "initialize received the caller's data verbatim");
    }

    /// The V1/V2 selector collision above is only half a hazard statement. A
    /// V4 factory calls `initialize(bytes)` on whatever address it is handed,
    /// and an `ICloneableV1` answers that selector — so the question the
    /// collision raises is whether a legacy implementation gets SILENTLY
    /// accepted, leaving a live clone that was never really initialized.
    ///
    /// It does not. `initialize` returns nothing on V1, so the factory's
    /// decode of a `bytes32` return finds an empty returndata buffer and
    /// reverts before it ever reaches the sentinel comparison. The revert
    /// carries NO data — it is the ABI decoder, not a typed error — which is
    /// asserted here as the actual observed behaviour rather than assumed to
    /// be `InitializationFailed`. Nothing is deployed at the address.
    function testV1ShapedImplementationIsRejected(bytes32 salt, bytes memory data) external {
        TestCloneableV1Shaped implementation = new TestCloneableV1Shaped();

        address predicted = I_CLONE_FACTORY.predictDeterministicAddress(address(implementation), salt, address(this));

        vm.expectRevert(bytes(""));
        I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);

        assertEq(predicted.code.length, 0);
    }
}
