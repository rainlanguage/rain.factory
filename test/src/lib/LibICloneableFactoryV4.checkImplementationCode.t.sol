// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {LibICloneableFactoryV4, ZeroImplementationCodeSize} from "src/lib/LibICloneableFactoryV4.sol";
import {TestCloneable} from "test/concrete/TestCloneable.sol";

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
        // EIP-3541 forbids DEPLOYING any code whose first byte is `0xef`, so
        // no implementation on any chain can have such code and the guard is
        // never specified over it. The exclusion narrows the fuzz domain to
        // code that could actually exist at an address; it cannot weaken the
        // property, because the guard only ever looks at code LENGTH.
        //
        // It is also what keeps this test from failing for a harness reason:
        // `vm.etch` parses a `0xef01` prefix as an EIP-7702 delegation
        // designator and rejects it unless the blob is exactly 23 bytes
        // ("Eip7702 is not 23 bytes long"), so a fuzz run that drew one died
        // in the cheatcode rather than in the code under test.
        vm.assume(code[0] != 0xef);
        vm.etch(implementation, code);
        LibICloneableFactoryV4.checkImplementationCode(implementation);
    }
}
