// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.16.1/src/Test.sol";

import {Clones} from "@openzeppelin-contracts-5.6.1/proxy/Clones.sol";
import {ICLONEABLE_V2_SUCCESS} from "src/interface/ICloneableV2.sol";
import {ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN} from "src/interface/ICloneableFactoryV4.sol";
import {
    CloneDeploymentFailed,
    InitializationFailed,
    ZeroImplementationCodeSize
} from "src/lib/LibICloneableFactoryV4.sol";
import {TestCloneFactory} from "test/concrete/TestCloneFactory.sol";
import {TestCloneable} from "test/concrete/TestCloneable.sol";
import {TestCloneableFailure} from "test/concrete/TestCloneableFailure.sol";

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

    /// The PREDICTION does not read the caller. `predictDeterministicAddress`
    /// takes the deployer as a parameter precisely so that anyone can predict
    /// on anyone's behalf, so the same `(implementation, salt, deployer)` asked
    /// from two different accounts must give the same answer. This is the
    /// namespaced mirror of
    /// `testCloneDeterministicOpenSaltPredictCallerIndependent`: without it the
    /// only thing pinning `deployer` against `msg.sender` is that
    /// `…SaltIsDomainTaggedHash` happens to fuzz `deployer` from one fixed
    /// caller.
    function testCloneDeterministicPredictCallerIndependent(
        address implementation,
        bytes32 salt,
        address deployer,
        address alice,
        address bob
    ) external {
        vm.assume(alice != bob);

        vm.prank(alice);
        address predictedFromAlice = I_CLONE_FACTORY.predictDeterministicAddress(implementation, salt, deployer);

        vm.prank(bob);
        address predictedFromBob = I_CLONE_FACTORY.predictDeterministicAddress(implementation, salt, deployer);

        assertEq(predictedFromAlice, predictedFromBob);

        // And the answer is the deployer's, not either caller's: asking about
        // `alice` gives a different address than asking about `bob`, no matter
        // who asks.
        vm.assume(deployer != alice);
        vm.prank(bob);
        assertTrue(I_CLONE_FACTORY.predictDeterministicAddress(implementation, salt, alice) != predictedFromBob);
    }

    /// `deployer` is an arbitrary account identifier, not a live caller, so
    /// `address(0)` is a perfectly well-defined input and gets the pinned
    /// formula like any other. A prediction that quietly substituted
    /// `msg.sender` for a zero deployer would be a plausible "helpful default"
    /// and is ruled out here.
    function testCloneDeterministicPredictZeroDeployer(address implementation, bytes32 salt) external view {
        bytes32 effectiveSalt = keccak256(abi.encode(ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN, address(0), salt));
        address expected = Clones.predictDeterministicAddress(implementation, effectiveSalt, address(I_CLONE_FACTORY));
        assertEq(I_CLONE_FACTORY.predictDeterministicAddress(implementation, salt, address(0)), expected);

        // And it is not the caller's answer wearing a disguise.
        assertTrue(
            I_CLONE_FACTORY.predictDeterministicAddress(implementation, salt, address(0))
                != I_CLONE_FACTORY.predictDeterministicAddress(implementation, salt, address(this))
        );
    }

    /// The FACTORY is in the address too — `address(this)`, read inside the
    /// library. Two factories, everything else held equal, are two different
    /// addresses, and each really deploys at its own. A pinned clone address
    /// is only meaningful against a named factory.
    function testCloneDeterministicFactoryScoped(bytes32 salt, bytes memory data) external {
        TestCloneFactory otherFactory = new TestCloneFactory();
        TestCloneable implementation = new TestCloneable();

        address predictedHere =
            I_CLONE_FACTORY.predictDeterministicAddress(address(implementation), salt, address(this));
        address predictedThere = otherFactory.predictDeterministicAddress(address(implementation), salt, address(this));
        assertTrue(predictedHere != predictedThere);

        assertEq(I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt), predictedHere);
        assertEq(otherFactory.cloneDeterministic(address(implementation), data, salt), predictedThere);
    }

    /// The extremes of the salt space are ordinary salts. `bytes32(0)` and
    /// `type(uint256).max` both predict, both deploy where predicted, and are
    /// distinct from each other — the salt goes into a `keccak256` preimage, so
    /// there is no edge to fall off, and this states that rather than leaving it
    /// to a fuzzer that may never pick either.
    function testCloneDeterministicExtremeSalts(bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        address predictedZero =
            I_CLONE_FACTORY.predictDeterministicAddress(address(implementation), bytes32(0), address(this));
        address predictedMax = I_CLONE_FACTORY.predictDeterministicAddress(
            address(implementation), bytes32(type(uint256).max), address(this)
        );
        assertTrue(predictedZero != predictedMax);

        address childZero = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, bytes32(0));
        address childMax = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, bytes32(type(uint256).max));

        assertEq(childZero, predictedZero);
        assertEq(childMax, predictedMax);
        assertEq(TestCloneable(childZero).sData(), data);
        assertEq(TestCloneable(childMax).sData(), data);
    }

    /// The prediction writes no state: called through a raw `STATICCALL` it
    /// still answers, and answers the same thing the typed call does. The
    /// library function is `view` and the compiler enforces that on the
    /// delegating concrete, but nothing else in the suite exercises the
    /// prediction at the EVM boundary where a state write would actually
    /// revert.
    function testCloneDeterministicPredictIsStaticCallable(address implementation, bytes32 salt, address deployer)
        external
        view
    {
        (bool ok, bytes memory ret) = address(I_CLONE_FACTORY)
            .staticcall(abi.encodeCall(I_CLONE_FACTORY.predictDeterministicAddress, (implementation, salt, deployer)));
        assertTrue(ok);
        assertEq(
            abi.decode(ret, (address)), I_CLONE_FACTORY.predictDeterministicAddress(implementation, salt, deployer)
        );
    }
}
