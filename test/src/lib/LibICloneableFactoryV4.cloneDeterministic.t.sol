// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.16.1/src/Test.sol";

import {Clones} from "@openzeppelin-contracts-5.6.1/proxy/Clones.sol";
import {ICLONEABLE_V2_SUCCESS} from "src/interface/ICloneableV2.sol";
import {ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN} from "src/interface/ICloneableFactoryV4.sol";
import {CloneDeploymentFailed, InitializationFailed, ZeroImplementationCodeSize} from "src/lib/LibICloneableFactoryV4.sol";
import {TestCloneFactory} from "test/src/concrete/TestCloneFactory.sol";
import {TestCloneable} from "test/src/concrete/TestCloneable.sol";
import {TestCloneableFailure} from "test/src/concrete/TestCloneableFailure.sol";

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
}
