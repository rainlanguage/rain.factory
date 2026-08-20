// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {Clones} from "@openzeppelin-contracts-5.6.1/proxy/Clones.sol";
import {LibICloneableFactoryV4} from "src/lib/LibICloneableFactoryV4.sol";

/// @title LibICloneableFactoryV4PredictCloneAddressTest
/// @notice Tests `LibICloneableFactoryV4.predictCloneAddress` against two independent
/// oracles: OpenZeppelin's `Clones.predictDeterministicAddress` — a foreign
/// implementation of the same EIP-1167 CREATE2 prediction, so any divergence
/// in our creation-code bytes or hashing shows up as a different address —
/// and the raw CREATE2 formula computed longhand here.
contract LibICloneableFactoryV4PredictCloneAddressTest is Test {
    /// Byte-for-byte equivalence with OZ Clones for every (factory,
    /// implementation, effectiveSalt): same creation code, same formula, same
    /// address. This is the equivalence oracle that lets the deploy half swap
    /// its OZ-backed concrete for a delegation into this library.
    function testPredictCloneAddressMatchesOZ(address factory, address implementation, bytes32 effectiveSalt)
        external
        pure
    {
        assertEq(
            LibICloneableFactoryV4.predictCloneAddress(factory, implementation, effectiveSalt),
            Clones.predictDeterministicAddress(implementation, effectiveSalt, factory)
        );
    }

    /// The raw CREATE2 formula, written out longhand:
    /// `address(keccak256(0xff ++ factory ++ salt ++ keccak256(creationCode)))`
    /// over the EIP-1167 creation bytes written out literally.
    function testPredictCloneAddressIsCreate2Formula(address factory, address implementation, bytes32 effectiveSalt)
        external
        pure
    {
        bytes memory creationCode = abi.encodePacked(
            hex"3d602d80600a3d3981f3363d3d373d3d3d363d73", implementation, hex"5af43d82803e903d91602b57fd5bf3"
        );
        address expected = address(
            uint160(uint256(keccak256(abi.encodePacked(hex"ff", factory, effectiveSalt, keccak256(creationCode)))))
        );
        assertEq(LibICloneableFactoryV4.predictCloneAddress(factory, implementation, effectiveSalt), expected);
    }

    /// A real CREATE2 deploy of the creation code lands exactly where the
    /// prediction says, from a live factory address (this test contract).
    function testPredictCloneAddressMatchesRealDeploy(address implementation, bytes32 effectiveSalt) external {
        address predicted = LibICloneableFactoryV4.predictCloneAddress(address(this), implementation, effectiveSalt);
        bytes memory creationCode = LibICloneableFactoryV4.cloneCreationCode(implementation);
        address child;
        assembly ("memory-safe") {
            child := create2(0, add(creationCode, 0x20), mload(creationCode), effectiveSalt)
        }
        assertEq(child, predicted);
    }
}
