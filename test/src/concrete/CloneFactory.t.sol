// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.16.1/src/Test.sol";

import {LibExtrospectERC1167Proxy} from "rain-extrospection-0.1.1/src/lib/LibExtrospectERC1167Proxy.sol";
import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "../../../src/interface/ICloneableV2.sol";
import {CloneFactory, ZeroImplementationCodeSize, InitializationFailed} from "../../../src/concrete/CloneFactory.sol";

/// @title TestCloneable
/// @notice A cloneable contract that implements `ICloneableV2`. Initializes
/// whatever data is passed to `initialize` as `sData`. As `sData` is public,
/// we can easily test that it is set correctly.
contract TestCloneable is ICloneableV2 {
    bytes public sData;

    /// @inheritdoc ICloneableV2
    function initialize(bytes memory data) external returns (bytes32) {
        sData = data;
        return ICLONEABLE_V2_SUCCESS;
    }
}

/// @title TestCloneableFailure
/// @notice A cloneable contract that implements `ICloneableV2` but always
/// fails initialization. Specifically, it returns whatever data is passed to
/// `initialize`, which is expected NOT to be `ICLONEABLE_V2_SUCCESS` for the
/// purposes of testing.
contract TestCloneableFailure is ICloneableV2 {
    /// @inheritdoc ICloneableV2
    function initialize(bytes memory data) external pure returns (bytes32 notSuccess) {
        (notSuccess) = abi.decode(data, (bytes32));
    }
}

/// @title CloneFactoryCloneTest
/// @notice A test suite for `CloneFactory` that tests the `clone` function.
contract CloneFactoryCloneTest is Test {
    /// The `CloneFactory` instance under test. As `CloneFactory` is
    /// stateless, we can reuse the same instance for all tests.
    CloneFactory internal immutable I_CLONE_FACTORY;

    /// Construct a new `CloneFactory` instance for testing.
    constructor() {
        I_CLONE_FACTORY = new CloneFactory();
    }

    /// The bytecode of the implementation contract is irrelevant to the child.
    /// The child will always have the same bytecode, which is the EIP1167 proxy
    /// standard, including the implementation address.
    function testCloneBytecode(bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        address child = I_CLONE_FACTORY.clone(address(implementation), data);

        (bool result, address proxyImplementation) = LibExtrospectERC1167Proxy.isERC1167Proxy(child.code);
        assertEq(result, true);
        assertEq(proxyImplementation, address(implementation));
    }

    /// The child should be initialized with the data passed to `clone`.
    function testCloneInitializeData(bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        address child = I_CLONE_FACTORY.clone(address(implementation), data);
        assertEq(TestCloneable(child).sData(), data);
    }

    /// The clone factory should emit a `NewClone` event including the address
    /// of the newly cloned child.
    function testCloneInitializeEvent(bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        vm.recordLogs();
        address child = I_CLONE_FACTORY.clone(address(implementation), data);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries.length, 1);
        assertEq(entries[0].topics[0], bytes32(uint256(keccak256("NewClone(address,address,address)"))));
        assertEq(entries[0].data, abi.encode(address(this), address(implementation), child));
    }

    /// If the implementation is uninitializable as a cloned child then this is
    /// always an error. A bare `vm.expectRevert()` is used here intentionally
    /// because the fuzzed implementation address could fail for several
    /// different reasons (zero code size, missing initialize function,
    /// initialize reverting, etc.) and we cannot predict which error will be
    /// thrown. The purpose of this test is to confirm that cloning an arbitrary
    /// address always reverts, regardless of the specific reason. More specific
    /// error paths are tested individually by the other test functions.
    function testCloneUninitializableFails(address implementation, bytes memory data) external {
        vm.expectRevert();
        I_CLONE_FACTORY.clone(implementation, data);
    }

    /// In the case an implementation is initialized but returns a failure code,
    /// we should revert with `InitializationFailed`.
    function testCloneInitializeFailureFails(bytes32 notSuccess) external {
        vm.assume(notSuccess != ICLONEABLE_V2_SUCCESS);
        TestCloneableFailure implementation = new TestCloneableFailure();

        vm.expectRevert(abi.encodeWithSelector(InitializationFailed.selector));
        I_CLONE_FACTORY.clone(address(implementation), abi.encode(notSuccess));
    }

    /// If the implementation has zero code size then this is always an error.
    function testZeroImplementationCodeSizeError(address implementation, bytes memory data) external {
        vm.assume(implementation.code.length == 0);
        vm.expectRevert(abi.encodeWithSelector(ZeroImplementationCodeSize.selector));
        I_CLONE_FACTORY.clone(implementation, data);
    }
}

/// @title CloneFactoryCloneDeterministicTest
/// @notice A test suite for `CloneFactory`'s `cloneDeterministic` /
/// `predictDeterministicAddress` functions.
contract CloneFactoryCloneDeterministicTest is Test {
    /// The `CloneFactory` instance under test. Stateless, so reused everywhere.
    CloneFactory internal immutable I_CLONE_FACTORY;

    constructor() {
        I_CLONE_FACTORY = new CloneFactory();
    }

    /// The deployed clone lands at the predicted address, is an EIP1167 proxy of
    /// the implementation, and is initialized with the data. `predict` therefore
    /// lets a caller pin the address before deploying.
    function testCloneDeterministicMatchesPredict(bytes32 salt, bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        address predicted = I_CLONE_FACTORY.predictDeterministicAddress(address(implementation), salt, address(this));
        address child = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);

        assertEq(child, predicted);
        (bool isProxy, address proxyImplementation) = LibExtrospectERC1167Proxy.isERC1167Proxy(child.code);
        assertEq(isProxy, true);
        assertEq(proxyImplementation, address(implementation));
        assertEq(TestCloneable(child).sData(), data);
    }

    /// Distinct salts yield distinct clones of the same implementation — many
    /// clones per impl (unlike a salt-free / one-per-impl deterministic deploy).
    function testCloneDeterministicManyClonesPerImpl(bytes32 salt1, bytes32 salt2, bytes memory data) external {
        vm.assume(salt1 != salt2);
        TestCloneable implementation = new TestCloneable();

        address child1 = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt1);
        address child2 = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt2);
        assertTrue(child1 != child2);
    }

    /// The same `(implementation, salt)` from different callers yields different
    /// addresses: the salt is namespaced by `msg.sender`, so no caller can squat
    /// or front-run another's address. `predict` reflects the deployer.
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

    /// `NewClone` is emitted with the caller, implementation and child.
    function testCloneDeterministicEvent(bytes32 salt, bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        vm.recordLogs();
        address child = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries.length, 1);
        assertEq(entries[0].topics[0], bytes32(uint256(keccak256("NewClone(address,address,address)"))));
        assertEq(entries[0].data, abi.encode(address(this), address(implementation), child));
    }

    /// An implementation that initializes to a non-success code reverts
    /// `InitializationFailed`.
    function testCloneDeterministicInitializeFailureFails(bytes32 notSuccess, bytes32 salt) external {
        vm.assume(notSuccess != ICLONEABLE_V2_SUCCESS);
        TestCloneableFailure implementation = new TestCloneableFailure();

        vm.expectRevert(abi.encodeWithSelector(InitializationFailed.selector));
        I_CLONE_FACTORY.cloneDeterministic(address(implementation), abi.encode(notSuccess), salt);
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
