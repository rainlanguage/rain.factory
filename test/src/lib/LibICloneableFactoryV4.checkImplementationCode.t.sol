// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";

import {
    LibICloneableFactoryV4,
    DelegatedImplementation,
    ZeroImplementationCodeSize
} from "src/lib/LibICloneableFactoryV4.sol";
import {TestCloneable} from "test/concrete/TestCloneable.sol";

/// @title LibICloneableFactoryV4CheckImplementationCodeTest
/// @notice Tests `LibICloneableFactoryV4.checkImplementationCode`.
contract LibICloneableFactoryV4CheckImplementationCodeTest is Test {
    /// External wrapper so `vm.expectRevert` sees the internal library call at
    /// its own call depth.
    function checkImplementationCodeExternal(address implementation) external view {
        LibICloneableFactoryV4.checkImplementationCode(implementation);
    }

    /// Any address without code reverts `ZeroImplementationCodeSize`.
    function testCheckImplementationCodeZero(address implementation) external {
        vm.assume(implementation.code.length == 0);
        vm.expectRevert(abi.encodeWithSelector(ZeroImplementationCodeSize.selector));
        this.checkImplementationCodeExternal(implementation);
    }

    /// A deployed contract passes.
    function testCheckImplementationCodeContract() external {
        TestCloneable implementation = new TestCloneable();
        LibICloneableFactoryV4.checkImplementationCode(address(implementation));
    }

    /// Any nonempty code not beginning with `0xef` passes.
    function testCheckImplementationCodeEtched(address implementation, bytes memory code) external {
        vm.assume(implementation.code.length == 0);
        vm.assume(uint160(implementation) > 0x0a);
        vm.assume(code.length > 0);
        vm.assume(code[0] != 0xef);
        vm.etch(implementation, code);
        LibICloneableFactoryV4.checkImplementationCode(implementation);
    }

    /// One byte of code passes when that byte is not `0xef`, including the
    /// bytes either side of it.
    function testCheckImplementationCodeSingleByte() external {
        bytes1[4] memory codes = [bytes1(0x00), 0xee, 0xf0, 0xff];
        for (uint256 i = 0; i < codes.length; i++) {
            address implementation = makeAddr(string.concat("single-byte-", vm.toString(i)));
            vm.etch(implementation, abi.encodePacked(codes[i]));
            this.checkImplementationCodeExternal(implementation);
        }
    }

    /// One byte of code that is `0xef` reverts `DelegatedImplementation`.
    function testCheckImplementationCodeSingleByteEf() external {
        address implementation = makeAddr("single-byte-ef");
        vm.etch(implementation, hex"ef");
        vm.expectRevert(abi.encodeWithSelector(DelegatedImplementation.selector));
        this.checkImplementationCodeExternal(implementation);
    }

    /// An EIP-7702 delegation designator reverts `DelegatedImplementation`.
    function testCheckImplementationCodeEip7702Designator(address delegated, address delegate) external {
        vm.assume(delegated.code.length == 0);
        vm.assume(uint160(delegated) > 0x0a);
        vm.etch(delegated, abi.encodePacked(hex"ef0100", delegate));
        vm.expectRevert(abi.encodeWithSelector(DelegatedImplementation.selector));
        this.checkImplementationCodeExternal(delegated);
    }
}
