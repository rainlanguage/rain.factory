// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";

import {Clones} from "@openzeppelin-contracts-5.7.0/proxy/Clones.sol";
import {LibICloneableFactoryV5} from "../../../src/lib/LibICloneableFactoryV5.sol";

/// @title LibICloneableFactoryV5PredictCloneAddressTest
/// @notice Tests `LibICloneableFactoryV5.predictCloneAddress` against oracles
/// independent of the library.
contract LibICloneableFactoryV5PredictCloneAddressTest is Test {
    /// Byte-for-byte equivalence with OZ Clones for every (factory,
    /// implementation, derivedSalt): same creation code, same formula, same
    /// address. This is the equivalence oracle that lets the deploy half swap
    /// its OZ-backed concrete for a delegation into this library.
    function testPredictCloneAddressMatchesOZ(address factory, address implementation, bytes32 derivedSalt)
        external
        pure
    {
        assertEq(
            LibICloneableFactoryV5.predictCloneAddress(factory, implementation, derivedSalt),
            Clones.predictDeterministicAddress(implementation, derivedSalt, factory)
        );
    }

    /// The raw CREATE2 formula, written out longhand:
    /// `address(keccak256(0xff ++ factory ++ salt ++ keccak256(creationCode)))`
    /// over the EIP-1167 creation bytes written out literally.
    function testPredictCloneAddressIsCreate2Formula(address factory, address implementation, bytes32 derivedSalt)
        external
        pure
    {
        bytes memory creationCode = abi.encodePacked(
            hex"3d602d80600a3d3981f3363d3d373d3d3d363d73", implementation, hex"5af43d82803e903d91602b57fd5bf3"
        );
        address expected = address(
            uint160(uint256(keccak256(abi.encodePacked(hex"ff", factory, derivedSalt, keccak256(creationCode)))))
        );
        assertEq(LibICloneableFactoryV5.predictCloneAddress(factory, implementation, derivedSalt), expected);
    }

    /// A real CREATE2 deploy of the creation code lands exactly where the
    /// prediction says, from a live factory address (this test contract).
    function testPredictCloneAddressMatchesRealDeploy(address implementation, bytes32 derivedSalt) external {
        address predicted = LibICloneableFactoryV5.predictCloneAddress(address(this), implementation, derivedSalt);
        bytes memory creationCode = LibICloneableFactoryV5.cloneCreationCode(implementation);
        address child;
        assembly ("memory-safe") {
            child := create2(0, add(creationCode, 0x20), mload(creationCode), derivedSalt)
        }
        assertEq(child, predicted);
    }

    /// Factory `0` and `max` predict as OZ `Clones` does.
    function testPredictCloneAddressBoundaryFactories(address implementation, bytes32 derivedSalt) external pure {
        assertEq(
            LibICloneableFactoryV5.predictCloneAddress(address(0), implementation, derivedSalt),
            Clones.predictDeterministicAddress(implementation, derivedSalt, address(0))
        );
        assertEq(
            LibICloneableFactoryV5.predictCloneAddress(address(type(uint160).max), implementation, derivedSalt),
            Clones.predictDeterministicAddress(implementation, derivedSalt, address(type(uint160).max))
        );
    }

    /// Implementation `0` and `max` predict as OZ `Clones` does.
    function testPredictCloneAddressBoundaryImplementations(address factory, bytes32 derivedSalt) external pure {
        assertEq(
            LibICloneableFactoryV5.predictCloneAddress(factory, address(0), derivedSalt),
            Clones.predictDeterministicAddress(address(0), derivedSalt, factory)
        );
        assertEq(
            LibICloneableFactoryV5.predictCloneAddress(factory, address(type(uint160).max), derivedSalt),
            Clones.predictDeterministicAddress(address(type(uint160).max), derivedSalt, factory)
        );
    }

    /// Derived salt `0` and `max` predict as OZ `Clones` does.
    function testPredictCloneAddressBoundarySalts(address factory, address implementation) external pure {
        assertEq(
            LibICloneableFactoryV5.predictCloneAddress(factory, implementation, bytes32(0)),
            Clones.predictDeterministicAddress(implementation, bytes32(0), factory)
        );
        assertEq(
            LibICloneableFactoryV5.predictCloneAddress(factory, implementation, bytes32(type(uint256).max)),
            Clones.predictDeterministicAddress(implementation, bytes32(type(uint256).max), factory)
        );
    }
}
