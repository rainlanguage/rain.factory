// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {Clones} from "@openzeppelin-contracts-5.6.1/proxy/Clones.sol";
import {LibICloneableFactoryV4} from "src/lib/LibICloneableFactoryV4.sol";

/// @title LibICloneableFactoryV4CloneRuntimeCodeTest
/// @notice Tests `LibICloneableFactoryV4.cloneRuntimeCode` and
/// `cloneRuntimeCodeHash` against three independent oracles: the EIP-1167 bytes
/// written out literally here, from the EIP; the chain itself, which decides
/// what a `CREATE2` of the creation code actually leaves at the clone address;
/// and a clone deployed by OZ `Clones`, a foreign implementation of the same
/// standard. The library's own creation code is never the only witness, so a
/// drift between the creation prefix and the runtime prefix — the ten bytes
/// they share — fails here rather than passing against itself.
contract LibICloneableFactoryV4CloneRuntimeCodeTest is Test {
    /// The runtime code is the canonical 45-byte EIP-1167 sequence: the 10-byte
    /// runtime prefix, the 20-byte implementation address and the 15-byte
    /// runtime suffix. The 10-byte deploy preamble that leads the creation code
    /// is NOT part of it.
    function testCloneRuntimeCodeIsEIP1167(address implementation) external pure {
        bytes memory expected =
            abi.encodePacked(hex"363d3d373d3d3d363d73", implementation, hex"5af43d82803e903d91602b57fd5bf3");
        bytes memory runtimeCode = LibICloneableFactoryV4.cloneRuntimeCode(implementation);
        assertEq(runtimeCode.length, 45);
        assertEq(runtimeCode, expected);
    }

    /// The runtime code is the creation code with the 10-byte deploy preamble
    /// removed and nothing else changed. Pins the prefix offset itself: a
    /// preamble one byte longer or shorter than ten fails here.
    function testCloneRuntimeCodeIsTheCreationCodeWithoutThePreamble(address implementation) external pure {
        bytes memory creationCode = LibICloneableFactoryV4.cloneCreationCode(implementation);
        bytes memory runtimeCode = LibICloneableFactoryV4.cloneRuntimeCode(implementation);
        assertEq(creationCode.length - runtimeCode.length, 10);
        assertEq(creationCode, abi.encodePacked(hex"3d602d80600a3d3981f3", runtimeCode));
    }

    /// The implementation address sits at bytes 10 through 29 of the runtime,
    /// read out of the bytes longhand. A clone whose address landed at a
    /// different offset would delegate somewhere other than `implementation`
    /// while still being 45 bytes long.
    function testCloneRuntimeCodeEmbedsTheImplementation(address implementation) external pure {
        bytes memory runtimeCode = LibICloneableFactoryV4.cloneRuntimeCode(implementation);
        uint160 embedded;
        for (uint256 i = 0; i < 20; i++) {
            embedded = (embedded << 8) | uint160(uint8(runtimeCode[10 + i]));
        }
        assertEq(address(embedded), implementation);
    }

    /// A real `CREATE2` of the creation code leaves exactly `cloneRuntimeCode`
    /// at the clone address. This is the oracle that makes the helper true by
    /// the EVM's behaviour and not by the library's own arithmetic.
    function testCloneRuntimeCodeIsWhatCreate2Leaves(address implementation, bytes32 salt) external {
        bytes memory creationCode = LibICloneableFactoryV4.cloneCreationCode(implementation);
        address child;
        assembly ("memory-safe") {
            child := create2(0, add(creationCode, 0x20), mload(creationCode), salt)
        }
        assertTrue(child != address(0));
        assertEq(child.code, LibICloneableFactoryV4.cloneRuntimeCode(implementation));
    }

    /// A clone deployed by OZ `Clones` — a foreign implementation of the same
    /// standard, which never sees our bytes — carries the same runtime code.
    function testCloneRuntimeCodeMatchesOZClone(address implementation, bytes32 salt) external {
        address ozClone = Clones.cloneDeterministic(implementation, salt);
        assertEq(ozClone.code, LibICloneableFactoryV4.cloneRuntimeCode(implementation));
    }

    /// Implementation `0` and `max` are the EIP bytes over those addresses.
    function testCloneRuntimeCodeBoundaryImplementations() external pure {
        assertEq(
            LibICloneableFactoryV4.cloneRuntimeCode(address(0)),
            abi.encodePacked(hex"363d3d373d3d3d363d73", address(0), hex"5af43d82803e903d91602b57fd5bf3")
        );
        assertEq(
            LibICloneableFactoryV4.cloneRuntimeCode(address(type(uint160).max)),
            abi.encodePacked(hex"363d3d373d3d3d363d73", address(type(uint160).max), hex"5af43d82803e903d91602b57fd5bf3")
        );
    }

    /// The implementation is in the runtime code: two implementations, two
    /// different runtimes.
    function testCloneRuntimeCodeImplementationSensitive(address alice, address bob) external pure {
        vm.assume(alice != bob);
        assertTrue(
            keccak256(LibICloneableFactoryV4.cloneRuntimeCode(alice))
                != keccak256(LibICloneableFactoryV4.cloneRuntimeCode(bob))
        );
    }

    /// The code hash is `keccak256` of the runtime code and of nothing else —
    /// not of the creation code, which is the easy thing to hash by mistake.
    function testCloneRuntimeCodeHashIsKeccakOfRuntime(address implementation) external pure {
        assertEq(
            LibICloneableFactoryV4.cloneRuntimeCodeHash(implementation),
            keccak256(LibICloneableFactoryV4.cloneRuntimeCode(implementation))
        );
        assertTrue(
            LibICloneableFactoryV4.cloneRuntimeCodeHash(implementation)
                != keccak256(LibICloneableFactoryV4.cloneCreationCode(implementation))
        );
    }

    /// The code hash is the EIP bytes hashed, written out literally here, so it
    /// is pinned to the standard rather than to the library's own constants.
    function testCloneRuntimeCodeHashIsEIP1167(address implementation) external pure {
        assertEq(
            LibICloneableFactoryV4.cloneRuntimeCodeHash(implementation),
            keccak256(abi.encodePacked(hex"363d3d373d3d3d363d73", implementation, hex"5af43d82803e903d91602b57fd5bf3"))
        );
    }

    /// The code hash is the `codehash` a deployed clone reports, which is the
    /// whole reason to want it: a consumer pinning this value is pinning what
    /// the chain will answer.
    function testCloneRuntimeCodeHashIsTheDeployedCodehash(address implementation, bytes32 salt) external {
        bytes memory creationCode = LibICloneableFactoryV4.cloneCreationCode(implementation);
        address child;
        assembly ("memory-safe") {
            child := create2(0, add(creationCode, 0x20), mload(creationCode), salt)
        }
        assertTrue(child != address(0));
        assertEq(child.codehash, LibICloneableFactoryV4.cloneRuntimeCodeHash(implementation));
    }

    /// Implementation `0` and `max` hash to the EIP bytes over those addresses.
    function testCloneRuntimeCodeHashBoundaryImplementations() external pure {
        assertEq(
            LibICloneableFactoryV4.cloneRuntimeCodeHash(address(0)),
            keccak256(abi.encodePacked(hex"363d3d373d3d3d363d73", address(0), hex"5af43d82803e903d91602b57fd5bf3"))
        );
        assertEq(
            LibICloneableFactoryV4.cloneRuntimeCodeHash(address(type(uint160).max)),
            keccak256(
                abi.encodePacked(
                    hex"363d3d373d3d3d363d73", address(type(uint160).max), hex"5af43d82803e903d91602b57fd5bf3"
                )
            )
        );
    }

    /// The implementation is in the code hash: two implementations, two
    /// different hashes, so a pinned hash cannot be satisfied by a clone of
    /// anything else.
    function testCloneRuntimeCodeHashImplementationSensitive(address alice, address bob) external pure {
        vm.assume(alice != bob);
        assertTrue(
            LibICloneableFactoryV4.cloneRuntimeCodeHash(alice) != LibICloneableFactoryV4.cloneRuntimeCodeHash(bob)
        );
    }
}
