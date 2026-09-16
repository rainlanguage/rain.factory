// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {
    LibICloneableFactoryV4,
    DelegatedImplementation,
    ZeroImplementationCodeSize
} from "src/lib/LibICloneableFactoryV4.sol";
import {TestCloneable} from "test/concrete/TestCloneable.sol";

/// @title LibICloneableFactoryV4CheckImplementationCodeTest
/// @notice Tests `LibICloneableFactoryV4.checkImplementationCode`: the guard
/// admits exactly the implementations that hold deployed contract code. A
/// codeless implementation — its clone would delegate every call,
/// `initialize` included, to nothing — and an EIP-7702 delegated account —
/// its clone would delegate to a pointer the account holder can repoint or
/// revoke — each revert with their own typed error before any deploy happens.
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

    /// Any nonempty code a `CREATE` could have deployed passes, whatever it
    /// does: the guard validates that the implementation holds deployed
    /// contract code, not what the code is.
    function testCheckImplementationCodeEtched(address implementation, bytes memory code) external {
        vm.assume(implementation.code.length == 0);
        vm.assume(uint160(implementation) > 0x0a);
        vm.assume(code.length > 0);
        // EIP-3541 forbids deploying any code whose first byte is `0xef`, so
        // this exclusion is exactly the deployable domain the guard admits.
        // The one `0xef`-leading code a real account can hold — an EIP-7702
        // delegation designator, `0xef0100 || address`, exactly 23 bytes — is
        // pinned by its own test below as the rejected case. `vm.etch`
        // rejects every other `0xef01`-leading blob ("Eip7702 is not 23 bytes
        // long"), so no such blob can reach the code under test from here.
        vm.assume(code[0] != 0xef);
        vm.etch(implementation, code);
        LibICloneableFactoryV4.checkImplementationCode(implementation);
    }

    /// The one `0xef`-leading code a real account can hold: an EIP-7702
    /// delegation designator, `0xef0100 || address`, exactly 23 bytes, which
    /// the fuzz test above cannot reach. `EXTCODESIZE` on a delegated account
    /// is 23, not zero, so the size check alone would admit it; the first
    /// byte reverts it with `DelegatedImplementation`, whatever the delegate.
    ///
    /// `foundry.toml` pins `evm_version = "cancun"`, which predates EIP-7702,
    /// so what is asserted is that the 23-byte designator is storable at an
    /// address and is rejected by the guard. The execution semantics of
    /// delegation are not exercised.
    function testCheckImplementationCodeEip7702Designator(address delegated, address delegate) external {
        vm.assume(delegated.code.length == 0);
        vm.assume(uint160(delegated) > 0x0a);

        bytes memory designator = abi.encodePacked(hex"ef0100", delegate);
        assertEq(designator.length, 23, "an EIP-7702 designator is 23 bytes");

        vm.etch(delegated, designator);

        assertEq(delegated.code.length, 23, "EXTCODESIZE sees the designator, not zero");
        vm.expectRevert(abi.encodeWithSelector(DelegatedImplementation.selector));
        this.checkImplementationCodeExternal(delegated);
    }
}
