// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {ICloneableV2} from "src/interface/ICloneableV2.sol";
import {TestCloneFactory} from "test/concrete/TestCloneFactory.sol";
import {TestCloneable, TestCloneableAlreadyInitialized} from "test/concrete/TestCloneable.sol";

/// @title ICloneableV2InitializeTest
/// @notice `ICloneableV2`'s two MUSTs on `initialize`, exercised on
/// `TestCloneable` and on clones of it that `TestCloneFactory` deployed and
/// initialized.
contract ICloneableV2InitializeTest is Test {
    /// The `TestCloneFactory` instance under test. Stateless, so reused
    /// everywhere.
    TestCloneFactory internal immutable iCloneFactory;

    constructor() {
        iCloneFactory = new TestCloneFactory();
    }

    /// `initialize` can NOT be called more than once: the factory's call is
    /// the one that succeeds, a second call on the clone reverts
    /// `TestCloneableAlreadyInitialized`, and the clone keeps the data the
    /// factory initialized it with.
    function testInitializeOnlyOnce(bytes32 salt, bytes memory data, bytes memory otherData) external {
        TestCloneable implementation = new TestCloneable();

        address child = iCloneFactory.cloneDeterministic(address(implementation), data, salt);
        assertEq(TestCloneable(child).sData(), data);

        vm.expectRevert(abi.encodeWithSelector(TestCloneableAlreadyInitialized.selector));
        TestCloneable(child).initialize(otherData);

        assertEq(TestCloneable(child).sData(), data);
    }

    /// The typed overload of `initialize` reverts `InitializeSignatureFn`
    /// always: on the never-initialized implementation, and on a clone the
    /// factory has initialized, for `value`, `0` and `type(uint256).max`.
    function testTypedOverloadRevertsInitializeSignatureFn(bytes32 salt, bytes memory data, uint256 value) external {
        TestCloneable implementation = new TestCloneable();
        address child = iCloneFactory.cloneDeterministic(address(implementation), data, salt);

        uint256[3] memory values = [value, 0, type(uint256).max];
        for (uint256 i = 0; i < values.length; i++) {
            vm.expectRevert(abi.encodeWithSelector(ICloneableV2.InitializeSignatureFn.selector));
            implementation.initialize(values[i]);

            vm.expectRevert(abi.encodeWithSelector(ICloneableV2.InitializeSignatureFn.selector));
            TestCloneable(child).initialize(values[i]);
        }
    }
}
