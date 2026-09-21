// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.16.1/src/Test.sol";

import {TestCloneFactory} from "test/concrete/TestCloneFactory.sol";

/// @title CloneFactoryTest
/// @notice Base for the tests that drive the library through
/// `TestCloneFactory`. Holds the factory instance they all need and the
/// `NewClone` log assertion, so the event signature is written out once.
abstract contract CloneFactoryTest is Test {
    /// The `TestCloneFactory` instance under test. Stateless, so reused
    /// everywhere.
    TestCloneFactory internal immutable I_CLONE_FACTORY;

    constructor() {
        I_CLONE_FACTORY = new TestCloneFactory();
    }

    /// Asserts `entry` is the factory's `NewClone` for this deploy: the
    /// factory as emitter, the event signature as topic 0, and the five
    /// arguments as the data.
    /// @param entry The recorded log to check.
    /// @param sender The caller the event should name.
    /// @param implementation The implementation the clone delegates to.
    /// @param clone The deployed clone.
    /// @param salt The raw caller salt.
    /// @param data The initialization data.
    function assertNewClone(
        Vm.Log memory entry,
        address sender,
        address implementation,
        address clone,
        bytes32 salt,
        bytes memory data
    ) internal view {
        assertEq(entry.emitter, address(I_CLONE_FACTORY));
        assertEq(entry.topics[0], keccak256("NewClone(address,address,address,bytes32,bytes)"));
        assertEq(entry.data, abi.encode(sender, implementation, clone, salt, data));
    }
}
