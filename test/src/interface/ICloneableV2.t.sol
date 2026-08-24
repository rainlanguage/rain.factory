// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {ICLONEABLE_V2_SUCCESS} from "src/interface/ICloneableV2.sol";
import {
    ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN,
    ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN
} from "src/interface/ICloneableFactoryV4.sol";
import {InitializationFailed} from "src/lib/LibICloneableFactoryV4.sol";
import {TestCloneFactory} from "test/concrete/TestCloneFactory.sol";
import {TestCloneable} from "test/concrete/TestCloneable.sol";
import {TestCloneableFailure} from "test/concrete/TestCloneableFailure.sol";

/// @title ICloneableV2Test
/// @notice Pins `ICLONEABLE_V2_SUCCESS`, the initialization success sentinel.
///
/// The sentinel is a value THIRD PARTIES REPRODUCE. `ICloneableV2` tells an
/// implementer to "return the keccak256 hash of the string
/// `ICloneableV2.initialize`", so every `ICloneableV2` in the world hard-codes
/// that hash, and a factory that compares against anything else rejects all of
/// them. It is therefore consensus-critical in exactly the way the two factory
/// domain tags are, and is pinned the same way `testDomainTagsPinned` pins
/// those: recomputed from the literal string, never read back from the
/// constant.
///
/// The end-to-end tests here are what stop the constant drifting undetected.
/// `TestCloneable` hard-codes the literal hash rather than importing
/// `ICLONEABLE_V2_SUCCESS` precisely so that it stands in for an independent
/// third-party implementation: were it to import the constant the library
/// compares against, both sides of that comparison would move together and the
/// whole suite would stay green under a changed sentinel. These tests say so
/// deliberately, on both derivations, rather than leaving it to be an
/// accidental property of the flow tests.
contract ICloneableV2Test is Test {
    /// The `TestCloneFactory` instance under test. Stateless, so reused
    /// everywhere.
    TestCloneFactory internal immutable I_CLONE_FACTORY;

    constructor() {
        I_CLONE_FACTORY = new TestCloneFactory();
    }

    /// The sentinel is exactly the pinned string hash. Recomputed from the
    /// literal so this is independent of the constant, and of anything that
    /// imports it.
    function testCloneableV2SuccessPinned() external pure {
        assertEq(ICLONEABLE_V2_SUCCESS, keccak256("ICloneableV2.initialize"));
    }

    /// The sentinel is its own value, distinct from the two factory domain
    /// tags: three separate string-derived constants that must never be
    /// conflated.
    function testCloneableV2SuccessDistinctFromDomainTags() external pure {
        assertTrue(ICLONEABLE_V2_SUCCESS != ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN);
        assertTrue(ICLONEABLE_V2_SUCCESS != ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN);
    }

    /// THE CONTRACT WITH THIRD PARTIES, namespaced path. An implementation
    /// that returns the LITERAL hash — not the imported constant — initializes
    /// successfully through a real factory, and the child really holds the
    /// data it was initialized with. If the sentinel the library accepts ever
    /// stopped being `keccak256("ICloneableV2.initialize")`, every independent
    /// `ICloneableV2` would start reverting `InitializationFailed` here.
    function testCloneableV2SuccessLiteralIsAcceptedNamespaced(bytes32 salt, bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        address predicted = I_CLONE_FACTORY.predictDeterministicAddress(address(implementation), salt, address(this));
        address child = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);

        assertEq(child, predicted);
        assertEq(TestCloneable(child).sData(), data);
    }

    /// The same contract with third parties, open-salt path.
    function testCloneableV2SuccessLiteralIsAcceptedOpenSalt(bytes32 salt, bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        address predicted = I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(address(implementation), data, salt);
        address child = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt);

        assertEq(child, predicted);
        assertEq(TestCloneable(child).sData(), data);
    }

    /// The comparison is over the EXACT hash, not over "returned a plausible
    /// 32-byte word". `TestCloneableFailure` returns whatever `bytes32` its
    /// initialization data decodes to, so handing it the hash of a string ONE
    /// CHARACTER away from the one the spec names produces exactly the near
    /// miss: a well-formed 32-byte return that reaches the comparison rather
    /// than reverting earlier. It is rejected, and the address is left free
    /// rather than occupied by an uninitialized clone.
    function testCloneableV2SuccessNearMissIsRejected(bytes32 salt) external {
        TestCloneableFailure implementation = new TestCloneableFailure();
        bytes memory nearMissData = abi.encode(keccak256("ICloneableV2.initialise"));

        address predicted = I_CLONE_FACTORY.predictDeterministicAddress(address(implementation), salt, address(this));

        vm.expectRevert(abi.encodeWithSelector(InitializationFailed.selector));
        I_CLONE_FACTORY.cloneDeterministic(address(implementation), nearMissData, salt);

        assertEq(predicted.code.length, 0);
    }

    /// The near miss really is a near miss and not some degenerate value: it
    /// is a nonzero word that differs from the sentinel. Stated here so the
    /// rejection above cannot be passing for an uninteresting reason.
    function testCloneableV2SuccessNearMissIsWellFormed() external pure {
        bytes32 nearMiss = keccak256("ICloneableV2.initialise");
        assertTrue(nearMiss != bytes32(0));
        assertTrue(nearMiss != ICLONEABLE_V2_SUCCESS);
    }
}
