// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {ICloneableFactoryV4} from "src/interface/ICloneableFactoryV4.sol";
import {LibICloneableFactoryV4} from "src/lib/LibICloneableFactoryV4.sol";
import {TestCloneFactory} from "test/src/concrete/TestCloneFactory.sol";
import {TestCloneable} from "test/src/concrete/TestCloneable.sol";

/// @title TestCloneFactoryTest
/// @notice `TestCloneFactory` is the executable stand-in for the real
/// `CloneFactory` in rain.factory.deploy, and the claim it exists to prove is
/// STRUCTURAL: the library surface suffices for a concrete that adds no
/// behaviour of its own. The 22 flow tests use it as a means to reach the
/// library; nothing asserted the delegation property itself, so a concrete
/// that quietly added behaviour — or that transposed two same-typed arguments
/// on the way through — would still have looked fine.
///
/// This pins it: each of the four entry points equals the library function it
/// claims to be, computed independently here, and the two predictions really
/// are `view`.
contract TestCloneFactoryTest is Test {
    /// The `TestCloneFactory` instance under test. Stateless, so reused
    /// everywhere.
    TestCloneFactory internal immutable I_CLONE_FACTORY;

    constructor() {
        I_CLONE_FACTORY = new TestCloneFactory();
    }

    /// The concrete is an `ICloneableFactoryV4`, and therefore also carries
    /// `ICloneableFactoryV3`'s two functions. Asserted as a real cast rather
    /// than left to the inheritance list.
    function testImplementsICloneableFactoryV4() external view {
        ICloneableFactoryV4 factory = ICloneableFactoryV4(address(I_CLONE_FACTORY));
        assertEq(address(factory), address(I_CLONE_FACTORY));
    }

    /// `predictDeterministicAddress` is the library function, argument for
    /// argument. `implementation` and `deployer` are both `address` and sit in
    /// different positions, so transposing them would compile silently; fuzzing
    /// them independently is what makes this discriminating.
    function testPredictDeterministicAddressIsPureDelegation(address implementation, bytes32 salt, address deployer)
        external
        view
    {
        assertEq(
            I_CLONE_FACTORY.predictDeterministicAddress(implementation, salt, deployer),
            LibICloneableFactoryV4.predictCloneAddress(
                address(I_CLONE_FACTORY), implementation, LibICloneableFactoryV4.effectiveSalt(deployer, salt)
            )
        );
    }

    /// `predictDeterministicAddressOpenSalt` is the library function, argument
    /// for argument.
    function testPredictDeterministicAddressOpenSaltIsPureDelegation(
        address implementation,
        bytes memory data,
        bytes32 salt
    ) external view {
        assertEq(
            I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(implementation, data, salt),
            LibICloneableFactoryV4.predictCloneAddress(
                address(I_CLONE_FACTORY), implementation, LibICloneableFactoryV4.effectiveOpenSalt(salt, data)
            )
        );
    }

    /// Both predictions are `external view` as the interface declares: a
    /// `staticcall` to each succeeds and returns the same answer the ordinary
    /// call does. A concrete that widened either to `nonpayable` — adding
    /// behaviour the interface forbids — would fail the staticcall.
    function testPredictionsAreStatic(address implementation, bytes memory data, bytes32 salt, address deployer)
        external
        view
    {
        (bool okNamespaced, bytes memory namespaced) = address(I_CLONE_FACTORY).staticcall(
            abi.encodeCall(I_CLONE_FACTORY.predictDeterministicAddress, (implementation, salt, deployer))
        );
        assertTrue(okNamespaced, "predictDeterministicAddress is not static");
        assertEq(
            abi.decode(namespaced, (address)),
            I_CLONE_FACTORY.predictDeterministicAddress(implementation, salt, deployer)
        );

        (bool okOpen, bytes memory open) = address(I_CLONE_FACTORY).staticcall(
            abi.encodeCall(I_CLONE_FACTORY.predictDeterministicAddressOpenSalt, (implementation, data, salt))
        );
        assertTrue(okOpen, "predictDeterministicAddressOpenSalt is not static");
        assertEq(
            abi.decode(open, (address)),
            I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(implementation, data, salt)
        );
    }

    /// The two deploying entry points route to the two DIFFERENT library
    /// derivations, each landing where that derivation says and nowhere else.
    /// Together with the prediction tests this covers all four delegations and
    /// pins that none of them is wired to the other's derivation.
    function testCloneEntryPointsRouteToTheirOwnDerivation(bytes32 salt, bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        address namespaced = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);
        address open = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt);

        assertEq(
            namespaced,
            LibICloneableFactoryV4.predictCloneAddress(
                address(I_CLONE_FACTORY),
                address(implementation),
                LibICloneableFactoryV4.effectiveSalt(address(this), salt)
            )
        );
        assertEq(
            open,
            LibICloneableFactoryV4.predictCloneAddress(
                address(I_CLONE_FACTORY),
                address(implementation),
                LibICloneableFactoryV4.effectiveOpenSalt(salt, data)
            )
        );
    }
}
