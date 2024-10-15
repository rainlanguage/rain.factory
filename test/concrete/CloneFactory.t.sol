// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {Test, Vm, console2} from "forge-std/Test.sol";

import {LibExtrospectERC1167Proxy} from "rain.extrospection/src/lib/LibExtrospectERC1167Proxy.sol";
import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "src/interface/ICloneableV2.sol";
import {CloneFactory, ZeroImplementationCodeSize, InitializationFailed} from "src/concrete/CloneFactory.sol";

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
    CloneFactory internal immutable iCloneFactory;

    /// Construct a new `CloneFactory` instance for testing.
    constructor() {
        iCloneFactory = new CloneFactory();
    }

    /// The bytecode of the implementation contract is irrelevant to the child.
    /// The child will always have the same bytecode, which is the EIP1167 proxy
    /// standard, including the implementation address.
    function testCloneBytecode(bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        address child = iCloneFactory.clone(address(implementation), data);

        (bool result, address proxyImplementation) = LibExtrospectERC1167Proxy.isERC1167Proxy(child.code);
        assertEq(result, true);
        assertEq(proxyImplementation, address(implementation));
    }

    /// The child should be initialized with the data passed to `clone`.
    function testCloneInitializeData(bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        address child = iCloneFactory.clone(address(implementation), data);
        assertEq(TestCloneable(child).sData(), data);
    }

    /// The clone factory should emit a `NewClone` event including the address
    /// of the newly cloned child.
    function testCloneInitializeEvent(bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        vm.recordLogs();
        address child = iCloneFactory.clone(address(implementation), data);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries.length, 1);
        assertEq(entries[0].topics[0], bytes32(uint256(keccak256("NewClone(address,address,address)"))));
        assertEq(entries[0].data, abi.encode(address(this), address(implementation), child));
    }

    /// If the implementation is uninitializable as a cloned child then this is
    /// always an error. For the sake of fuzzing, the implementation could error
    /// for unrelated reasons so we can't directly assert the error message.
    function testCloneUninitializableFails(address implementation, bytes memory data) external {
        vm.expectRevert();
        iCloneFactory.clone(implementation, data);
    }

    /// In the case an implementation is initialized but returns a failure code,
    /// we should revert with `InitializationFailed`.
    function testCloneInitializeFailureFails(bytes32 notSuccess) external {
        vm.assume(notSuccess != ICLONEABLE_V2_SUCCESS);
        TestCloneableFailure implementation = new TestCloneableFailure();

        vm.expectRevert(abi.encodeWithSelector(InitializationFailed.selector));
        iCloneFactory.clone(address(implementation), abi.encode(notSuccess));
    }

    /// If the implementation has zero code size then this is always an error.
    function testZeroImplementationCodeSizeError(address implementation, bytes memory data) public {
        vm.assume(implementation.code.length == 0);
        vm.expectRevert(abi.encodeWithSelector(ZeroImplementationCodeSize.selector));
        iCloneFactory.clone(implementation, data);
    }
}
