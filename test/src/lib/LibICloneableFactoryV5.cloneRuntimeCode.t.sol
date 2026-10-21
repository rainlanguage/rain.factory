// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";

import {Clones} from "@openzeppelin-contracts-5.6.1/proxy/Clones.sol";
import {LibICloneableFactoryV5} from "../../../src/lib/LibICloneableFactoryV5.sol";

/// @title LibICloneableFactoryV5CloneRuntimeCodeTest
/// @notice Tests `LibICloneableFactoryV5.cloneRuntimeCode` and
/// `cloneRuntimeCodeHash` against the EIP-1167 bytes written out literally and
/// against the code OZ `Clones` actually deploys.
contract LibICloneableFactoryV5CloneRuntimeCodeTest is Test {
    /// The runtime code is the 45-byte EIP-1167 sequence: the 10-byte runtime
    /// prefix, the 20-byte implementation address and the 15-byte suffix.
    function testCloneRuntimeCodeIsEIP1167(address implementation) external pure {
        bytes memory expected =
            abi.encodePacked(hex"363d3d373d3d3d363d73", implementation, hex"5af43d82803e903d91602b57fd5bf3");
        bytes memory runtimeCode = LibICloneableFactoryV5.cloneRuntimeCode(implementation);
        assertEq(runtimeCode.length, 45);
        assertEq(runtimeCode, expected);
        assertEq(LibICloneableFactoryV5.cloneRuntimeCodeHash(implementation), keccak256(expected));
    }

    /// The EIP-1167 text's own example, for its placeholder implementation
    /// `0xbebe...be`. The hash is `cast keccak` of the EIP's hex.
    function testCloneRuntimeCodeEIP1167Example() external pure {
        address implementation = 0xBEbeBeBEbeBebeBeBEBEbebEBeBeBebeBeBebebe;
        assertEq(
            LibICloneableFactoryV5.cloneRuntimeCode(implementation),
            hex"363d3d373d3d3d363d73bebebebebebebebebebebebebebebebebebebebe5af43d82803e903d91602b57fd5bf3"
        );
        assertEq(
            LibICloneableFactoryV5.cloneRuntimeCodeHash(implementation),
            0xbd1ab8973fc701940fe1252ea00647970bf77e9e293777b24d10d4247adb44f1
        );
    }

    /// The code and `codehash` OZ `Clones` leaves at a clone of
    /// `implementation`.
    function testCloneRuntimeCodeMatchesOZClone(address implementation, bytes32 salt) external {
        address clone = Clones.cloneDeterministic(implementation, salt);
        assertEq(clone.code, LibICloneableFactoryV5.cloneRuntimeCode(implementation));
        assertEq(clone.codehash, LibICloneableFactoryV5.cloneRuntimeCodeHash(implementation));
    }

    /// Exactly what `CREATE2` of `cloneCreationCode` leaves at the clone.
    function testCloneRuntimeCodeIsDeployedCreationCode(address implementation, bytes32 salt) external {
        bytes memory creationCode = LibICloneableFactoryV5.cloneCreationCode(implementation);
        address child;
        assembly ("memory-safe") {
            child := create2(0, add(creationCode, 0x20), mload(creationCode), salt)
        }
        assertNotEq(child, address(0));
        assertEq(child.code, LibICloneableFactoryV5.cloneRuntimeCode(implementation));
        assertEq(child.codehash, LibICloneableFactoryV5.cloneRuntimeCodeHash(implementation));
    }
}
