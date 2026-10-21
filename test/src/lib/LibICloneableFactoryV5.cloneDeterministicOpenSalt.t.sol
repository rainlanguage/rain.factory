// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.17.0/src/Test.sol";

import {Clones} from "@openzeppelin-contracts-5.6.1/proxy/Clones.sol";
import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "../../../src/interface/ICloneableV2.sol";
import {
    ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN,
    ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN
} from "../../../src/interface/deprecated/ICloneableFactoryV4.sol";
import {
    LibICloneableFactoryV5,
    CloneAddressOccupied,
    CloneDeploymentFailed,
    InitializationFailed,
    ZeroImplementationCodeSize
} from "../../../src/lib/LibICloneableFactoryV5.sol";
import {CloneFactoryTest} from "../../abstract/CloneFactoryTest.sol";
import {TestCloneFactory} from "../../../src/test/TestCloneFactory.sol";
import {TestCloneable} from "../../../src/test/TestCloneable.sol";
import {TestCloneableCallRecorder} from "../../concrete/TestCloneableCallRecorder.sol";
import {TestCloneableFailure} from "../../../src/test/TestCloneableFailure.sol";

/// @title LibICloneableFactoryV5CloneDeterministicOpenSaltTest
/// @notice Tests `LibICloneableFactoryV5.cloneDeterministicOpenSalt` /
/// `predictDeterministicAddressOpenSalt` through `TestCloneFactory`, a
/// pure-delegation concrete. The defining property is that the address commits
/// to WHAT is deployed — `(implementation, data, salt)` — and to nothing about
/// WHO deploys it, which is the exact opposite of what `cloneDeterministic`
/// guarantees. So the two derivations are also tested against each other here,
/// including the one squat that the pair of distinct domain tags exists to
/// close.
contract LibICloneableFactoryV5CloneDeterministicOpenSaltTest is CloneFactoryTest {
    /// The effective `CREATE2` salt is exactly the derivation
    /// `ICloneableFactoryV4` fixes:
    /// `keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data)))`.
    /// Pinned against OZ's own prediction under an independently constructed
    /// salt, so an off-chain caller can reproduce the address from
    /// `(implementation, data, salt, factory)` alone and the test does not
    /// restate the library's arithmetic back to itself.
    function testCloneDeterministicOpenSaltIsDomainTaggedHash(address implementation, bytes memory data, bytes32 salt)
        external
        view
    {
        bytes32 effectiveSalt = keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data)));
        address expected = Clones.predictDeterministicAddress(implementation, effectiveSalt, address(iCloneFactory));
        assertEq(iCloneFactory.predictDeterministicAddressOpenSalt(implementation, data, salt), expected);
    }

    /// The deployed clone lands at the predicted address, is an EIP-1167 proxy
    /// of the implementation — its runtime code compared against the EIP's
    /// bytes written out literally — and is initialized with the data.
    /// `predict` therefore lets a caller pin the address before deploying —
    /// but only once `data` is final, since `data` is in the derivation.
    function testCloneDeterministicOpenSaltMatchesPredict(bytes32 salt, bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        address predicted = iCloneFactory.predictDeterministicAddressOpenSalt(address(implementation), data, salt);
        address child = iCloneFactory.cloneDeterministicOpenSalt(address(implementation), data, salt);

        assertEq(child, predicted);
        assertEq(
            child.code,
            abi.encodePacked(hex"363d3d373d3d3d363d73", address(implementation), hex"5af43d82803e903d91602b57fd5bf3")
        );
        assertEq(TestCloneable(child).sData(), data);
    }

    /// THE POINT OF THIS VARIANT. The same `(implementation, data, salt)` from
    /// two different callers lands on the SAME address. State is snapshotted
    /// and rolled back between the two deploys so both callers genuinely
    /// deploy from the same starting state — the addresses are compared, not
    /// merely predicted. This is exactly what `cloneDeterministic` forbids.
    function testCloneDeterministicOpenSaltCallerIndependent(
        bytes32 salt,
        bytes memory data,
        address alice,
        address bob
    ) external {
        vm.assume(alice != bob);
        TestCloneable implementation = new TestCloneable();

        address predicted = iCloneFactory.predictDeterministicAddressOpenSalt(address(implementation), data, salt);

        uint256 snapshot = vm.snapshotState();

        vm.prank(alice);
        address childAlice = iCloneFactory.cloneDeterministicOpenSalt(address(implementation), data, salt);

        vm.revertToState(snapshot);

        vm.prank(bob);
        address childBob = iCloneFactory.cloneDeterministicOpenSalt(address(implementation), data, salt);

        assertEq(childAlice, childBob);
        assertEq(childAlice, predicted);
    }

    /// The prediction takes no deployer, so it cannot vary with one.
    /// Predicting the same `(implementation, data, salt)` from two different
    /// callers returns the same address, the derivation's — a caller pinning
    /// an address offchain does not need to know who will deploy it.
    function testCloneDeterministicOpenSaltPredictCallerIndependent(
        address implementation,
        bytes memory data,
        bytes32 salt,
        address alice,
        address bob
    ) external {
        vm.assume(alice != bob);
        bytes32 effectiveSalt = keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data)));
        address expected = Clones.predictDeterministicAddress(implementation, effectiveSalt, address(iCloneFactory));

        vm.prank(alice);
        address predictedAlice = iCloneFactory.predictDeterministicAddressOpenSalt(implementation, data, salt);

        vm.prank(bob);
        address predictedBob = iCloneFactory.predictDeterministicAddressOpenSalt(implementation, data, salt);

        assertEq(predictedAlice, predictedBob);
        assertEq(predictedAlice, expected);
    }

    /// The address depends on no chain state: a funded factory at an arbitrary
    /// block and timestamp predicts and deploys at the derivation's address.
    function testCloneDeterministicOpenSaltAddressIgnoresChainState(
        bytes32 salt,
        bytes memory data,
        uint256 balance,
        uint256 timestamp,
        uint256 blockNumber
    ) external {
        balance = bound(balance, 1, type(uint256).max);
        timestamp = bound(timestamp, 2, type(uint64).max);
        blockNumber = bound(blockNumber, 2, type(uint64).max);
        TestCloneable implementation = new TestCloneable();
        vm.deal(address(iCloneFactory), balance);
        vm.warp(timestamp);
        vm.roll(blockNumber);

        bytes32 effectiveSalt = keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data)));
        address expected =
            Clones.predictDeterministicAddress(address(implementation), effectiveSalt, address(iCloneFactory));

        assertEq(iCloneFactory.predictDeterministicAddressOpenSalt(address(implementation), data, salt), expected);
        assertEq(iCloneFactory.cloneDeterministicOpenSalt(address(implementation), data, salt), expected);
    }

    /// `data` IS IN THE DERIVATION, which is what makes losing the
    /// `msg.sender` namespacing safe. Two different `data` at the SAME
    /// `(implementation, salt)` are two different addresses, and both clones
    /// exist independently with their own initialization. So a front-runner
    /// who passes anything other than the intended bytes deploys their own
    /// contract at their own address and at their own expense, leaving the
    /// address that was pinned untouched and still deployable.
    function testCloneDeterministicOpenSaltDataInDerivation(bytes32 salt, bytes memory dataA, bytes memory dataB)
        external
    {
        vm.assume(keccak256(dataA) != keccak256(dataB));
        TestCloneable implementation = new TestCloneable();

        address predictedA = iCloneFactory.predictDeterministicAddressOpenSalt(address(implementation), dataA, salt);
        address predictedB = iCloneFactory.predictDeterministicAddressOpenSalt(address(implementation), dataB, salt);
        assertNotEq(predictedA, predictedB);

        address childA = iCloneFactory.cloneDeterministicOpenSalt(address(implementation), dataA, salt);
        address childB = iCloneFactory.cloneDeterministicOpenSalt(address(implementation), dataB, salt);

        assertEq(childA, predictedA);
        assertEq(childB, predictedB);
        assertEq(TestCloneable(childA).sData(), dataA);
        assertEq(TestCloneable(childB).sData(), dataB);
    }

    /// The two derivations are disjoint under freely varying inputs on BOTH
    /// sides: no `(data, openSalt)` open-salt address is any `(namespacedSalt,
    /// deployer)` sender-namespaced address. Adding the open variant therefore
    /// cannot reach, block or collide with an address that `cloneDeterministic`
    /// promised to a specific caller, or vice versa.
    ///
    /// This is the broad statement, and on its own it is weak: a collision it
    /// could catch needs a keccak256 collision, so no realistic mutation of
    /// the derivation makes it fail. It is kept as the plain form of the
    /// interface's claim. The reachable case that actually discriminates the
    /// two domain tags is the next test.
    function testCloneDeterministicOpenSaltDiffersFromSenderNamespaced(
        address implementation,
        bytes memory data,
        bytes32 openSalt,
        bytes32 namespacedSalt,
        address deployer
    ) external view {
        address open = iCloneFactory.predictDeterministicAddressOpenSalt(implementation, data, openSalt);
        address namespaced = iCloneFactory.predictDeterministicAddress(implementation, namespacedSalt, deployer);
        assertNotEq(open, namespaced);
    }

    /// THE SQUAT THE DISTINCT DOMAIN TAGS CLOSE, stated as an attack rather
    /// than as an absence.
    ///
    /// `ICloneableFactoryV4` makes it a MUST NOT on the factory that no other
    /// entry point can `CREATE2` in the open-salt derivation's image with
    /// caller-supplied `data`. `cloneDeterministic` is precisely such an entry
    /// point. Both preimages are 96 bytes and the caller chooses words 1 and 2
    /// of each: on the namespaced path `(msg.sender, salt)` and on the open
    /// path `(salt, keccak256(data))`. Were the two tags ONE WORD — the same
    /// tag on both derivations — an account `A` would reach EVERY open-salt
    /// address whose `salt` equals `bytes32(uint256(uint160(A)))`, the
    /// abi-encoding of `A`, by calling
    /// `cloneDeterministic(implementation, evilData, keccak256(data))`. No
    /// preimage search, just a choice of salt. Only the first word — the tag
    /// no caller can set — separates the two preimages at that point.
    ///
    /// The premise is proven, not narrated: the attacker's namespaced words 1
    /// and 2, re-hashed under the OPEN tag, land byte for byte on the honest
    /// party's open-salt effective salt. Then the guarantee: under the two
    /// DISTINCT tags the real predictions differ, the attacker's deploy lands
    /// at their own namespaced address, and the pinned open-salt address is
    /// still free and still deploys the intended clone with the intended
    /// bytes.
    function testCloneDeterministicOpenSaltDisjointTagsCloseTheSquat(
        address attacker,
        bytes memory data,
        bytes memory evilData
    ) external {
        vm.assume(keccak256(evilData) != keccak256(data));
        TestCloneable implementation = new TestCloneable();

        // The open salt an honest party pinned, which happens to be the
        // abi-encoding of the attacker's own address. Nothing stops a salt
        // taking this value; the attacker is free to go looking for one that
        // does.
        bytes32 openSalt = bytes32(uint256(uint160(attacker)));
        address open = iCloneFactory.predictDeterministicAddressOpenSalt(address(implementation), data, openSalt);

        // The attacker's namespaced salt is just `keccak256(data)`, read off
        // the honest deploy they are front-running. From `attacker` the
        // namespaced preimage is then
        // `(NAMESPACED_DOMAIN, attacker, keccak256(data))`.
        bytes32 attackerSalt = keccak256(data);
        address namespaced = iCloneFactory.predictDeterministicAddress(address(implementation), attackerSalt, attacker);

        // ATTACK PREMISE. `abi.encode` left-pads `attacker` into exactly the
        // word `openSalt` already is, so the attacker's namespaced preimage
        // re-tagged with the OPEN tag is byte for byte the honest open
        // preimage: with one shared tag the squat lands exactly on the address
        // the honest party pinned.
        bytes32 sharedTagCounterfactual =
            keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, attacker, attackerSalt));
        assertEq(
            sharedTagCounterfactual,
            LibICloneableFactoryV5.effectiveOpenSalt(openSalt, data),
            "the attacker's words re-tagged ARE the open effective salt"
        );

        // And symmetrically under the NAMESPACED tag: the honest open words
        // re-tagged are byte for byte the attacker's namespaced effective
        // salt. Same two unknowns, solved from the other side, closed by the
        // same word.
        bytes32 sharedTagCounterfactualNamespaced =
            keccak256(abi.encode(ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN, openSalt, keccak256(data)));
        assertEq(
            sharedTagCounterfactualNamespaced,
            LibICloneableFactoryV5.effectiveSalt(attacker, attackerSalt),
            "the open words re-tagged ARE the namespaced effective salt"
        );

        // THE GUARANTEE. The two distinct tags move the real open-salt address
        // off the one `cloneDeterministic` can reach.
        assertNotEq(open, namespaced);

        // End to end, not just in prediction: the attacker really deploys, at
        // their own address, with their own data, and the honest open-salt
        // address is still free afterwards and still deploys the intended
        // clone with the intended bytes.
        vm.prank(attacker);
        address childAttacker = iCloneFactory.cloneDeterministic(address(implementation), evilData, attackerSalt);
        assertEq(childAttacker, namespaced);
        assertEq(TestCloneable(childAttacker).sData(), evilData);
        assertEq(open.code.length, 0);

        address childOpen = iCloneFactory.cloneDeterministicOpenSalt(address(implementation), data, openSalt);
        assertEq(childOpen, open);
        assertEq(TestCloneable(childOpen).sData(), data);
    }

    /// REGRESSION GUARD on the guarantee that must not break, in the other
    /// direction. Taking a salt via the open variant does not consume it for
    /// `cloneDeterministic`: the same caller can still deploy at the same
    /// `salt` through the namespaced derivation, at the address it always
    /// predicted, and both clones exist independently.
    function testCloneDeterministicOpenSaltDoesNotConsumeNamespacedSalt(bytes32 salt, bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        address predictedNamespaced =
            iCloneFactory.predictDeterministicAddress(address(implementation), salt, address(this));

        address childOpen = iCloneFactory.cloneDeterministicOpenSalt(address(implementation), data, salt);
        address childNamespaced = iCloneFactory.cloneDeterministic(address(implementation), data, salt);

        assertEq(childNamespaced, predictedNamespaced);
        assertNotEq(childOpen, childNamespaced);
        assertGt(childOpen.code.length, 0);
        assertGt(childNamespaced.code.length, 0);
    }

    /// Distinct salts yield distinct clones of the same implementation and the
    /// same `data` — many clones per impl, as with the namespaced variant. The
    /// other half of "distinct `(salt, data)` pairs yield distinct clones";
    /// the `data` half is `…DataInDerivation`.
    function testCloneDeterministicOpenSaltManyClonesPerImpl(bytes32 salt1, bytes32 salt2, bytes memory data) external {
        vm.assume(salt1 != salt2);
        TestCloneable implementation = new TestCloneable();

        address child1 = iCloneFactory.cloneDeterministicOpenSalt(address(implementation), data, salt1);
        address child2 = iCloneFactory.cloneDeterministicOpenSalt(address(implementation), data, salt2);
        assertNotEq(child1, child2);
    }

    /// A second deploy of the same `(implementation, data, salt)`, from any
    /// caller, reverts `CloneAddressOccupied` with the predicted address.
    function testCloneDeterministicOpenSaltSecondDeployReverts(
        bytes32 salt,
        bytes memory data,
        address alice,
        address bob
    ) external {
        vm.assume(alice != bob);
        TestCloneable implementation = new TestCloneable();

        vm.prank(alice);
        address child = iCloneFactory.cloneDeterministicOpenSalt(address(implementation), data, salt);
        assertEq(child, iCloneFactory.predictDeterministicAddressOpenSalt(address(implementation), data, salt));

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(CloneAddressOccupied.selector, child));
        iCloneFactory.cloneDeterministicOpenSalt(address(implementation), data, salt);

        // The first deploy's state is untouched by the failed second one.
        assertEq(TestCloneable(child).sData(), data);
    }

    /// `NewClone` is emitted with the caller, implementation, child, salt and
    /// data. The event is shared with `cloneDeterministic` and carries the RAW
    /// salt in both cases, never the effective one. `salt` and `data` together
    /// are the whole of the open derivation, so the event carries enough to
    /// recompute the address — an indexer picks the derivation by trying both
    /// and keeping the match, which is well defined precisely because the two
    /// images are disjoint.
    function testCloneDeterministicOpenSaltEvent(bytes32 salt, bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        vm.recordLogs();
        address child = iCloneFactory.cloneDeterministicOpenSalt(address(implementation), data, salt);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries.length, 1);
        assertNewClone(entries[0], address(this), address(implementation), child, salt, data);
    }

    /// An implementation that initializes to a non-success code reverts
    /// `InitializationFailed`, and clone-and-initialize stays atomic: the
    /// address is left free rather than occupied by an uninitialized clone, so
    /// the same `(implementation, data, salt)` still deploys there afterwards.
    /// `data` is inside this derivation and cannot change between the attempts,
    /// but the clone address commits to the implementation's ADDRESS and not to
    /// its code, so the code there is swapped for one that initializes instead.
    /// Reading `predicted.code.length` instead would assert nothing: the revert
    /// has already rolled the `CREATE2` back whatever the library did.
    function testCloneDeterministicOpenSaltInitializeFailureFails(bytes32 notSuccess, bytes32 salt) external {
        vm.assume(notSuccess != ICLONEABLE_V2_SUCCESS);
        TestCloneableFailure implementation = new TestCloneableFailure();

        bytes memory data = abi.encode(notSuccess);
        address predicted = iCloneFactory.predictDeterministicAddressOpenSalt(address(implementation), data, salt);

        vm.expectRevert(abi.encodeWithSelector(InitializationFailed.selector));
        iCloneFactory.cloneDeterministicOpenSalt(address(implementation), data, salt);

        vm.etch(address(implementation), address(new TestCloneable()).code);
        assertEq(iCloneFactory.cloneDeterministicOpenSalt(address(implementation), data, salt), predicted);
        assertEq(TestCloneable(predicted).sData(), data);
    }

    /// A zero-code implementation reverts `ZeroImplementationCodeSize`.
    function testCloneDeterministicOpenSaltZeroImplementationCodeSize(
        address implementation,
        bytes memory data,
        bytes32 salt
    ) external {
        vm.assume(implementation.code.length == 0);
        vm.expectRevert(abi.encodeWithSelector(ZeroImplementationCodeSize.selector));
        iCloneFactory.cloneDeterministicOpenSalt(implementation, data, salt);
    }

    /// Empty `data` deploys where predicted and initializes with empty `data`.
    function testCloneDeterministicOpenSaltEmptyData(bytes32 salt) external {
        TestCloneable implementation = new TestCloneable();

        address predicted = iCloneFactory.predictDeterministicAddressOpenSalt(address(implementation), "", salt);
        address child = iCloneFactory.cloneDeterministicOpenSalt(address(implementation), "", salt);

        assertEq(child, predicted);
        assertEq(TestCloneable(child).sData(), "");
    }

    /// 10,000 bytes of `data` deploy where predicted and initialize with
    /// `data`, and its last byte moves the address.
    function testCloneDeterministicOpenSaltLargeData(bytes32 salt, bytes1 fill) external {
        TestCloneable implementation = new TestCloneable();

        bytes memory data = new bytes(10_000);
        for (uint256 i = 0; i < data.length; i++) {
            data[i] = fill;
        }

        address predicted = iCloneFactory.predictDeterministicAddressOpenSalt(address(implementation), data, salt);
        address child = iCloneFactory.cloneDeterministicOpenSalt(address(implementation), data, salt);

        assertEq(child, predicted);
        assertEq(TestCloneable(child).sData(), data);

        data[9_999] = ~fill;
        assertNotEq(iCloneFactory.predictDeterministicAddressOpenSalt(address(implementation), data, salt), predicted);
    }

    /// Salts `0` and `max` deploy where predicted.
    function testCloneDeterministicOpenSaltExtremeSalts(bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        address predictedZero =
            iCloneFactory.predictDeterministicAddressOpenSalt(address(implementation), data, bytes32(0));
        address predictedMax = iCloneFactory.predictDeterministicAddressOpenSalt(
            address(implementation), data, bytes32(type(uint256).max)
        );

        assertEq(iCloneFactory.cloneDeterministicOpenSalt(address(implementation), data, bytes32(0)), predictedZero);
        assertEq(
            iCloneFactory.cloneDeterministicOpenSalt(address(implementation), data, bytes32(type(uint256).max)),
            predictedMax
        );
    }

    /// `initialize` is the FIRST thing called on the fresh proxy, and the only
    /// thing: "MUST NOT call anything else on the proxy first", which
    /// `ICloneableFactoryV4` states on this function. `TestCloneable` only
    /// exposes its end state, so the recorder is used instead — it appends the
    /// selector of every call the proxy receives, including ones whose result
    /// the factory would discard, and the whole recorded sequence is asserted
    /// rather than just its first entry.
    function testCloneDeterministicOpenSaltInitializeIsTheOnlyCall(bytes32 salt, bytes memory data) external {
        TestCloneableCallRecorder implementation = new TestCloneableCallRecorder();

        address child = iCloneFactory.cloneDeterministicOpenSalt(address(implementation), data, salt);

        bytes4[] memory selectors = TestCloneableCallRecorder(child).selectors();
        assertEq(selectors.length, 1);
        assertEq(selectors[0], ICloneableV2.initialize.selector);
        assertEq(TestCloneableCallRecorder(child).sData(), data);
    }

    /// `NewClone` is emitted BEFORE `initialize` runs, so an indexer replaying
    /// the log stream sees the clone announced before anything the clone itself
    /// says about being initialized. The recorder logs from inside `initialize`,
    /// which is what makes the relative order observable at all;
    /// `…OpenSaltEvent` asserts the count alone and cannot see it.
    function testCloneDeterministicOpenSaltEventPrecedesInitialize(bytes32 salt, bytes memory data) external {
        TestCloneableCallRecorder implementation = new TestCloneableCallRecorder();

        vm.recordLogs();
        address child = iCloneFactory.cloneDeterministicOpenSalt(address(implementation), data, salt);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries.length, 2);

        assertNewClone(entries[0], address(this), address(implementation), child, salt, data);

        assertEq(entries[1].emitter, child);
        assertEq(entries[1].topics[0], keccak256("Initializing(bytes)"));
        assertEq(entries[1].data, abi.encode(data));
    }

    /// A codeless clone address with a nonzero nonce fails the `CREATE2`
    /// itself: `CloneDeploymentFailed`.
    function testCloneDeterministicOpenSaltNonceOnlyCollisionReverts(bytes32 salt, bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        address predicted = iCloneFactory.predictDeterministicAddressOpenSalt(address(implementation), data, salt);
        vm.setNonce(predicted, 1);

        vm.expectRevert(abi.encodeWithSelector(CloneDeploymentFailed.selector));
        iCloneFactory.cloneDeterministicOpenSalt(address(implementation), data, salt);
    }

    /// The implementation-code guard runs before the occupancy check: with the
    /// salt taken and the implementation codeless,
    /// `ZeroImplementationCodeSize` reverts, not `CloneAddressOccupied`.
    function testCloneDeterministicOpenSaltCodeGuardRunsBeforeCreate2(bytes32 salt, bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        address child = iCloneFactory.cloneDeterministicOpenSalt(address(implementation), data, salt);
        assertTrue(child.code.length > 0);

        vm.etch(address(implementation), "");
        assertEq(address(implementation).code.length, 0);

        vm.expectRevert(abi.encodeWithSelector(ZeroImplementationCodeSize.selector));
        iCloneFactory.cloneDeterministicOpenSalt(address(implementation), data, salt);
    }

    /// `CREATE2` is given a literal `0` value, so a factory that is holding ETH
    /// endows the clone with none of it. Balances on both sides are asserted,
    /// so neither "the clone got funded" nor "the factory got drained" can
    /// pass.
    function testCloneDeterministicOpenSaltNoEthForwarded(bytes32 salt, bytes memory data, uint256 balance) external {
        balance = bound(balance, 1, type(uint128).max);
        TestCloneable implementation = new TestCloneable();
        vm.deal(address(iCloneFactory), balance);

        address child = iCloneFactory.cloneDeterministicOpenSalt(address(implementation), data, salt);

        assertEq(child.balance, 0);
        assertEq(address(iCloneFactory).balance, balance);
    }
}
