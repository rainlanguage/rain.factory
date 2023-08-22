// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import "forge-std/Test.sol";

import "rain.interpreter/abstract/DeployerDiscoverableMetaV2.sol";
import "rain.extrospection/src/lib/LibExtrospectERC1167Proxy.sol";

import "src/concrete/CloneFactory.sol";
import {CloneFactory} from "src/concrete/CloneFactory.sol";

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
    CloneFactory internal immutable _iCloneFactory;

    /// Construct a new `CloneFactory` instance for testing.
    constructor() {
        // Deployer address is arbitrary, we're going to mock the call anyway.
        address deployer = address(uint160(uint256(keccak256("deployer"))));
        // Need to provide some bytecode for the mock call to succeed.
        vm.etch(deployer, hex"00");
        // This is the real metadata, it will be checked against the hash in the
        // constructor. If the metadata on file becomes stale then the CI
        // deployment will fail due to a hash mismatch as the github action
        // builds from source.
        bytes memory meta = vm.readFileBinary("meta/CloneFactory.rain.meta");
        console2.log("meta hash:");
        console2.logBytes32(keccak256(meta));

        // We only mock the call so that it doesn't error and prevent the
        // constructor from completing. We don't care about the return value.
        vm.mockCall(
            deployer,
            abi.encodeWithSelector(IExpressionDeployerV2.deployExpression.selector),
            abi.encode(address(0), address(0), address(0))
        );
        // We do care that the call is made, however. If we never touch an
        // expression deployer then the `CloneFactory` will not be discoverable.
        vm.expectCall(address(deployer), abi.encodeWithSelector(IExpressionDeployerV2.deployExpression.selector));
        _iCloneFactory = new CloneFactory(DeployerDiscoverableMetaV2ConstructionConfig(deployer, meta));
    }

    /// The bytecode of the implementation contract is irrelevant to the child.
    /// The child will always have the same bytecode, which is the EIP1167 proxy
    /// standard, including the implementation address.
    function testCloneBytecode(bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        address child = _iCloneFactory.clone(address(implementation), data);

        (bool result, address proxyImplementation) = LibExtrospectERC1167Proxy.isERC1167Proxy(child.code);
        assertEq(result, true);
        assertEq(proxyImplementation, address(implementation));
    }

    /// The child should be initialized with the data passed to `clone`.
    function testCloneInitializeData(bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        address child = _iCloneFactory.clone(address(implementation), data);
        assertEq(TestCloneable(child).sData(), data);
    }

    /// The clone factory should emit a `NewClone` event including the address
    /// of the newly cloned child.
    function testCloneInitializeEvent(bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        vm.recordLogs();
        address child = _iCloneFactory.clone(address(implementation), data);
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
        _iCloneFactory.clone(implementation, data);
    }

    /// In the case an implementation is initialized but returns a failure code,
    /// we should revert with `InitializationFailed`.
    function testCloneInitializeFailureFails(bytes32 notSuccess) external {
        vm.assume(notSuccess != ICLONEABLE_V2_SUCCESS);
        TestCloneableFailure implementation = new TestCloneableFailure();

        vm.expectRevert(abi.encodeWithSelector(InitializationFailed.selector));
        _iCloneFactory.clone(address(implementation), abi.encode(notSuccess));
    }

    /// If the implementation has zero code size then this is always an error.
    function testZeroImplementationCodeSizeError(address implementation, bytes memory data) public {
        vm.assume(implementation.code.length == 0);
        vm.expectRevert(abi.encodeWithSelector(ZeroImplementationCodeSize.selector));
        _iCloneFactory.clone(implementation, data);
    }
}
