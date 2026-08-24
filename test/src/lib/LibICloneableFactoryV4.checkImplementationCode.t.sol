// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {LibICloneableFactoryV4, ZeroImplementationCodeSize} from "src/lib/LibICloneableFactoryV4.sol";
import {TestCloneable} from "test/src/concrete/TestCloneable.sol";

/// @title LibICloneableFactoryV4CheckImplementationCodeTest
/// @notice Tests `LibICloneableFactoryV4.checkImplementationCode`: a codeless
/// implementation is always a mistake — its clone would delegate every call,
/// `initialize` included, to nothing — so it reverts with a typed error
/// before any deploy happens.
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

    /// Any nonempty code is enough to pass: the guard is a code-size check,
    /// not a validation of what the code is.
    function testCheckImplementationCodeEtched(address implementation, bytes memory code) external {
        vm.assume(implementation.code.length == 0);
        vm.assume(uint160(implementation) > 0x0a);
        vm.assume(code.length > 0);
        // `vm.etch` refuses any code whose first byte is `0xef`: `0xef00` is
        // the EOF magic and `0xef01` the EIP-7702 delegation magic, and the
        // cheatcode parses both rather than installing them verbatim — an
        // `0xef01…` blob that is not exactly the 23-byte designator is
        // rejected by the cheatcode, not by the guard under test, so a fuzz
        // run that happened to draw one failed for a harness reason.
        vm.assume(code[0] != bytes1(0xef));
        vm.etch(implementation, code);
        LibICloneableFactoryV4.checkImplementationCode(implementation);
    }
}
