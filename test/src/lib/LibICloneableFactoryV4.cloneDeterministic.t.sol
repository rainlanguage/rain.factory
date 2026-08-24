// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.16.1/src/Test.sol";

import {Clones} from "@openzeppelin-contracts-5.6.1/proxy/Clones.sol";
import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "src/interface/ICloneableV2.sol";
import {ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN} from "src/interface/ICloneableFactoryV4.sol";
import {
    CloneDeploymentFailed,
    InitializationFailed,
    ZeroImplementationCodeSize
} from "src/lib/LibICloneableFactoryV4.sol";
import {TestCloneFactory} from "test/src/concrete/TestCloneFactory.sol";
import {TestCloneable} from "test/src/concrete/TestCloneable.sol";
import {TestCloneableCallRecorder} from "test/src/concrete/TestCloneableCallRecorder.sol";
import {TestCloneableFailure} from "test/src/concrete/TestCloneableFailure.sol";
import {TestCloneableRevert, TestCloneableRevertInitialize} from "test/src/concrete/TestCloneableRevert.sol";

/// @title LibICloneableFactoryV4CloneDeterministicTest
/// @notice Tests `LibICloneableFactoryV4.cloneDeterministic` /
/// `predictDeterministicAddress` — the namespaced pair — through
/// `TestCloneFactory`, a pure-delegation concrete, because `msg.sender`
/// namespacing and the `NewClone` event only exist across an external call.
/// The defining property is that the address commits to WHO deployed —
/// `(deployer, salt)` — and not to WHAT was initialized.
contract LibICloneableFactoryV4CloneDeterministicTest is Test {
    /// The `TestCloneFactory` instance under test. Stateless, so reused
    /// everywhere.
    TestCloneFactory internal immutable I_CLONE_FACTORY;

    constructor() {
        I_CLONE_FACTORY = new TestCloneFactory();
    }

    /// The effective `CREATE2` salt is exactly the derivation
    /// `ICloneableFactoryV4` fixes:
    /// `keccak256(abi.encode(ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN, msg.sender, salt))`.
    /// Pinned against OZ's own prediction under an independently constructed
    /// salt, so an off-chain caller can reproduce the address from
    /// `(implementation, deployer, salt, factory)` alone and the test does not
    /// restate the library's arithmetic back to itself.
    function testCloneDeterministicSaltIsDomainTaggedHash(address implementation, bytes32 salt, address deployer)
        external
        view
    {
        bytes32 effectiveSalt = keccak256(abi.encode(ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN, deployer, salt));
        address expected = Clones.predictDeterministicAddress(implementation, effectiveSalt, address(I_CLONE_FACTORY));
        assertEq(I_CLONE_FACTORY.predictDeterministicAddress(implementation, salt, deployer), expected);
    }

    /// The deployed clone lands at the predicted address, is an EIP-1167 proxy
    /// of the implementation — its runtime code compared against the EIP's
    /// bytes written out literally — and is initialized with the data.
    /// `predict` therefore lets a caller pin the address before deploying.
    function testCloneDeterministicMatchesPredict(bytes32 salt, bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        address predicted = I_CLONE_FACTORY.predictDeterministicAddress(address(implementation), salt, address(this));
        address child = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);

        assertEq(child, predicted);
        assertEq(
            child.code,
            abi.encodePacked(hex"363d3d373d3d3d363d73", address(implementation), hex"5af43d82803e903d91602b57fd5bf3")
        );
        assertEq(TestCloneable(child).sData(), data);
    }

    /// Distinct salts yield distinct clones of the same implementation — many
    /// clones per impl (unlike a salt-free / one-per-impl deterministic
    /// deploy).
    function testCloneDeterministicManyClonesPerImpl(bytes32 salt1, bytes32 salt2, bytes memory data) external {
        vm.assume(salt1 != salt2);
        TestCloneable implementation = new TestCloneable();

        address child1 = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt1);
        address child2 = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt2);
        assertTrue(child1 != child2);
    }

    /// The same `(implementation, salt)` from different callers yields
    /// different addresses: the salt is namespaced by `msg.sender`, so no
    /// caller can squat or front-run another's address. `predict` reflects the
    /// deployer.
    function testCloneDeterministicSenderScoped(bytes32 salt, bytes memory data, address alice, address bob) external {
        vm.assume(alice != bob);
        TestCloneable implementation = new TestCloneable();

        address predictedAlice = I_CLONE_FACTORY.predictDeterministicAddress(address(implementation), salt, alice);
        address predictedBob = I_CLONE_FACTORY.predictDeterministicAddress(address(implementation), salt, bob);
        assertTrue(predictedAlice != predictedBob);

        vm.prank(alice);
        address childAlice = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);
        assertEq(childAlice, predictedAlice);

        vm.prank(bob);
        address childBob = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);
        assertEq(childBob, predictedBob);

        assertTrue(childAlice != childBob);
    }

    /// `data` is NOT in the derivation: the same caller and salt with two
    /// different `data` land on the SAME address, each initialized with its
    /// own bytes. State is snapshotted and rolled back between the two deploys
    /// so both genuinely happen from the same starting state. This is the
    /// namespaced pair's trade documented on `ICloneableFactoryV4`: the
    /// deployer alone decides the clone's initial state at an address that
    /// says nothing about it.
    function testCloneDeterministicDataNotInDerivation(bytes32 salt, bytes memory dataA, bytes memory dataB) external {
        vm.assume(keccak256(dataA) != keccak256(dataB));
        TestCloneable implementation = new TestCloneable();

        uint256 snapshot = vm.snapshotState();

        address childA = I_CLONE_FACTORY.cloneDeterministic(address(implementation), dataA, salt);
        bytes memory sDataA = TestCloneable(childA).sData();

        vm.revertToState(snapshot);

        address childB = I_CLONE_FACTORY.cloneDeterministic(address(implementation), dataB, salt);

        assertEq(childA, childB);
        assertEq(sDataA, dataA);
        assertEq(TestCloneable(childB).sData(), dataB);
    }

    /// A second deploy at an already-taken `(deployer, salt)` reverts with the
    /// library's own typed error: a caller can never mistake an
    /// already-initialized contract for their own fresh deploy.
    function testCloneDeterministicSecondDeployReverts(bytes32 salt, bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        address child = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);

        vm.expectRevert(abi.encodeWithSelector(CloneDeploymentFailed.selector));
        I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);

        // The first deploy's state is untouched by the failed second one.
        assertEq(TestCloneable(child).sData(), data);
    }

    /// `NewClone` is emitted with the caller, implementation, child, salt and
    /// data — the full deterministic deploy, reconstructable from the event
    /// alone. The salt is the RAW caller salt, not the effective one.
    function testCloneDeterministicEvent(bytes32 salt, bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        vm.recordLogs();
        address child = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries.length, 1);
        assertEq(entries[0].emitter, address(I_CLONE_FACTORY));
        assertEq(entries[0].topics[0], bytes32(uint256(keccak256("NewClone(address,address,address,bytes32,bytes)"))));
        assertEq(entries[0].data, abi.encode(address(this), address(implementation), child, salt, data));
    }

    /// An implementation that initializes to a non-success code reverts
    /// `InitializationFailed`, so clone-and-initialize stays atomic and the
    /// address is left free rather than occupied by an uninitialized clone.
    function testCloneDeterministicInitializeFailureFails(bytes32 notSuccess, bytes32 salt) external {
        vm.assume(notSuccess != ICLONEABLE_V2_SUCCESS);
        TestCloneableFailure implementation = new TestCloneableFailure();

        address predicted = I_CLONE_FACTORY.predictDeterministicAddress(address(implementation), salt, address(this));

        vm.expectRevert(abi.encodeWithSelector(InitializationFailed.selector));
        I_CLONE_FACTORY.cloneDeterministic(address(implementation), abi.encode(notSuccess), salt);

        assertEq(predicted.code.length, 0);
    }

    /// A zero-code implementation reverts `ZeroImplementationCodeSize`.
    function testCloneDeterministicZeroImplementationCodeSize(address implementation, bytes memory data, bytes32 salt)
        external
    {
        vm.assume(implementation.code.length == 0);
        vm.expectRevert(abi.encodeWithSelector(ZeroImplementationCodeSize.selector));
        I_CLONE_FACTORY.cloneDeterministic(implementation, data, salt);
    }

    /// The implementation-code guard runs BEFORE the `CREATE2`, not after it.
    /// The ordering is only observable when both failure conditions hold at
    /// once — the effective salt is already taken AND the implementation is
    /// codeless — so that is the state built here: an ordinary deploy takes
    /// the salt, then the implementation loses its code. Guarding first, the
    /// caller is told the mistake they actually made
    /// (`ZeroImplementationCodeSize`); a guard that ran after the deploy would
    /// report the occupied address (`CloneDeploymentFailed`) instead and send
    /// them looking for a salt collision that is not their problem.
    function testCloneDeterministicCodeGuardRunsBeforeCreate2(bytes32 salt, bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        address child = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);
        assertTrue(child.code.length > 0);

        vm.etch(address(implementation), "");
        assertEq(address(implementation).code.length, 0);

        vm.expectRevert(abi.encodeWithSelector(ZeroImplementationCodeSize.selector));
        I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);
    }

    /// `CREATE2` is given a literal `0` value, so a factory that is holding ETH
    /// endows the clone with none of it. The factory has no payable surface,
    /// but a balance can still arrive by `SELFDESTRUCT` or by being a block
    /// reward or withdrawal recipient, and a factory that forwarded whatever it
    /// happened to hold would hand a windfall to whoever cloned next. Balances
    /// on both sides are asserted, so neither "the clone got funded" nor "the
    /// factory got drained" can pass.
    function testCloneDeterministicNoEthForwarded(bytes32 salt, bytes memory data, uint256 balance) external {
        balance = bound(balance, 1, type(uint128).max);
        TestCloneable implementation = new TestCloneable();
        vm.deal(address(I_CLONE_FACTORY), balance);

        address child = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);

        assertEq(child.balance, 0);
        assertEq(address(I_CLONE_FACTORY).balance, balance);
    }

    /// `initialize` is the FIRST thing called on the fresh proxy, and the only
    /// thing: "MUST NOT call any other functions on the cloned proxy before
    /// `initialize` completes successfully". `TestCloneable` only exposes its
    /// end state, so the recorder is used instead — it appends the selector of
    /// every call the proxy receives, including ones whose result the factory
    /// would discard, and the whole recorded sequence is asserted rather than
    /// just its first entry.
    function testCloneDeterministicInitializeIsTheOnlyCall(bytes32 salt, bytes memory data) external {
        TestCloneableCallRecorder implementation = new TestCloneableCallRecorder();

        address child = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);

        bytes4[] memory selectors = TestCloneableCallRecorder(child).selectors();
        assertEq(selectors.length, 1);
        assertEq(selectors[0], ICloneableV2.initialize.selector);
        assertEq(TestCloneableCallRecorder(child).sData(), data);
    }

    /// `NewClone` is emitted BEFORE `initialize` runs, so an indexer replaying
    /// the log stream sees the clone announced before anything the clone itself
    /// says about being initialized. The recorder logs from inside `initialize`,
    /// which is what makes the relative order observable at all; asserting the
    /// count alone cannot see it.
    function testCloneDeterministicEventPrecedesInitialize(bytes32 salt, bytes memory data) external {
        TestCloneableCallRecorder implementation = new TestCloneableCallRecorder();

        vm.recordLogs();
        address child = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries.length, 2);

        assertEq(entries[0].emitter, address(I_CLONE_FACTORY));
        assertEq(entries[0].topics[0], bytes32(uint256(keccak256("NewClone(address,address,address,bytes32,bytes)"))));
        assertEq(entries[0].data, abi.encode(address(this), address(implementation), child, salt, data));

        assertEq(entries[1].emitter, child);
        assertEq(entries[1].topics[0], bytes32(uint256(keccak256("Initializing(bytes)"))));
        assertEq(entries[1].data, abi.encode(data));
    }

    /// An implementation whose `initialize` REVERTS bubbles that revert
    /// verbatim — error selector and arguments — rather than being swallowed or
    /// re-wrapped, and the clone-and-initialize stays atomic: the predicted
    /// address is left codeless, so the salt is still free. `…InitializeFailureFails`
    /// covers the other half of initialization failure, where `initialize`
    /// returns a non-success value instead of refusing.
    function testCloneDeterministicInitializeRevertBubbles(bytes32 salt, bytes memory data) external {
        TestCloneableRevert implementation = new TestCloneableRevert();

        address predicted = I_CLONE_FACTORY.predictDeterministicAddress(address(implementation), salt, address(this));

        vm.expectRevert(abi.encodeWithSelector(TestCloneableRevertInitialize.selector, data));
        I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);

        assertEq(predicted.code.length, 0);
    }
}
