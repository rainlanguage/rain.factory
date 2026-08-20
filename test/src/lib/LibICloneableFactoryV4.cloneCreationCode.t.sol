// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {LibICloneableFactoryV4} from "src/lib/LibICloneableFactoryV4.sol";

/// @title LibICloneableFactoryV4CloneCreationCodeTest
/// @notice Tests `LibICloneableFactoryV4.cloneCreationCode` against the EIP-1167
/// bytes written out literally here, from the EIP, so the library's constants
/// are pinned against the standard rather than against themselves.
contract LibICloneableFactoryV4CloneCreationCodeTest is Test {
    /// The creation code is the canonical 55-byte EIP-1167 sequence: the
    /// 10-byte deploy preamble, the 10-byte runtime prefix, the 20-byte
    /// implementation address and the 15-byte runtime suffix.
    function testCloneCreationCodeIsEIP1167(address implementation) external pure {
        bytes memory expected = abi.encodePacked(
            hex"3d602d80600a3d3981f3363d3d373d3d3d363d73", implementation, hex"5af43d82803e903d91602b57fd5bf3"
        );
        bytes memory creationCode = LibICloneableFactoryV4.cloneCreationCode(implementation);
        assertEq(creationCode.length, 55);
        assertEq(creationCode, expected);
    }

    /// Deploying the creation code really produces the EIP-1167 RUNTIME code
    /// for the implementation: the same bytes minus the 10-byte deploy
    /// preamble. This pins the preamble's semantics (codecopy of the trailing
    /// 45 bytes) and not just its bytes.
    function testCloneCreationCodeDeploysEIP1167Runtime(address implementation, bytes32 salt) external {
        bytes memory creationCode = LibICloneableFactoryV4.cloneCreationCode(implementation);
        address child;
        assembly ("memory-safe") {
            child := create2(0, add(creationCode, 0x20), mload(creationCode), salt)
        }
        assertTrue(child != address(0));
        bytes memory expectedRuntime =
            abi.encodePacked(hex"363d3d373d3d3d363d73", implementation, hex"5af43d82803e903d91602b57fd5bf3");
        assertEq(child.code, expectedRuntime);
    }
}
