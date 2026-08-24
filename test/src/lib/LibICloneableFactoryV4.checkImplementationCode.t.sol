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
        // no CREATE or CREATE2 can put such code at an address. That leaves
        // exactly one way an account can hold it — an EIP-7702 delegation
        // designator, which is `0xef0100` followed by an address and is
        // therefore EXACTLY 23 bytes. That case is real, so it is not excluded
        // here, it is pinned by its own test below.
        //
        // What this exclusion drops is the rest: `0xef`-leading blobs of any
        // other length, which no chain can produce. It cannot weaken the
        // property under test, because the guard only ever looks at code
        // LENGTH.
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

    /// The one `0xef`-leading code a real account can hold: an EIP-7702
    /// delegation designator, `0xef0100 || address`, exactly 23 bytes. The
    /// fuzz test above cannot reach it, so it is pinned here as a fixed case.
    ///
    /// It PASSES the guard, and that is the point worth having on the record.
    /// `EXTCODESIZE` on a delegated EOA returns 23, not zero, so the size
    /// check cannot tell an ordinary implementation contract from an EOA that
    /// has delegated — and unlike a deployed contract, a delegation is
    /// REVOCABLE by the account holder at any time. A caller who wants an
    /// immutable implementation does not get that from this guard; the guard
    /// promises only that something is there.
    ///
    /// Scoped honestly: `foundry.toml` pins `evm_version = "cancun"`, which
    /// predates EIP-7702, so what is asserted here is that the 23-byte
    /// designator is storable at an address and passes the SIZE check. The
    /// execution semantics of delegation are not exercised and this test does
    /// not claim them.
    function testCheckImplementationCodeEip7702Designator(address delegated, address delegate) external {
        vm.assume(delegated.code.length == 0);
        vm.assume(uint160(delegated) > 0x0a);

        bytes memory designator = abi.encodePacked(hex"ef0100", delegate);
        assertEq(designator.length, 23, "an EIP-7702 designator is 23 bytes");

        vm.etch(delegated, designator);

        assertEq(delegated.code.length, 23, "EXTCODESIZE sees the designator, not zero");
        LibICloneableFactoryV4.checkImplementationCode(delegated);
    }
}
