// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {ICloneableFactoryV4} from "src/interface/ICloneableFactoryV4.sol";
import {LibPublishedAbi} from "test/lib/LibPublishedAbi.sol";

/// @title ICloneableFactoryV4AbiTest
/// @notice Pins the published ABI of the two functions `ICloneableFactoryV4`
/// declares: selectors from their literal signatures, and each ABI entry as it
/// appears in the compiled artifact. The entries it inherits are pinned in
/// `ICloneableFactoryV3AbiTest`.
contract ICloneableFactoryV4AbiTest is Test {
    /// `cloneDeterministicOpenSalt(address,bytes,bytes32)` and
    /// `predictDeterministicAddressOpenSalt(address,bytes,bytes32)` selectors.
    function testFunctionSelectorsPinned() external pure {
        assertEq(
            ICloneableFactoryV4.cloneDeterministicOpenSalt.selector,
            bytes4(keccak256("cloneDeterministicOpenSalt(address,bytes,bytes32)"))
        );
        assertEq(
            ICloneableFactoryV4.predictDeterministicAddressOpenSalt.selector,
            bytes4(keccak256("predictDeterministicAddressOpenSalt(address,bytes,bytes32)"))
        );
    }

    /// `cloneDeterministicOpenSalt(address implementation, bytes data, bytes32
    /// salt)` returns an unnamed `address` and is nonpayable.
    function testCloneDeterministicOpenSaltAbiPinned() external view {
        assertTrue(
            vm.contains(
                LibPublishedAbi.artifactJson(vm, "ICloneableFactoryV4", "ICloneableFactoryV4"),
                "{\"type\":\"function\",\"name\":\"cloneDeterministicOpenSalt\",\"inputs\":["
                "{\"name\":\"implementation\",\"type\":\"address\",\"internalType\":\"address\"},"
                "{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"},"
                "{\"name\":\"salt\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}"
                "],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],"
                "\"stateMutability\":\"nonpayable\"}"
            ),
            "cloneDeterministicOpenSalt(address implementation, bytes data, bytes32 salt) returns (address)"
        );
    }

    /// `predictDeterministicAddressOpenSalt(address implementation, bytes
    /// data, bytes32 salt)` returns an unnamed `address` and is view.
    function testPredictDeterministicAddressOpenSaltAbiPinned() external view {
        assertTrue(
            vm.contains(
                LibPublishedAbi.artifactJson(vm, "ICloneableFactoryV4", "ICloneableFactoryV4"),
                "{\"type\":\"function\",\"name\":\"predictDeterministicAddressOpenSalt\",\"inputs\":["
                "{\"name\":\"implementation\",\"type\":\"address\",\"internalType\":\"address\"},"
                "{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"},"
                "{\"name\":\"salt\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}"
                "],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],"
                "\"stateMutability\":\"view\"}"
            ),
            "predictDeterministicAddressOpenSalt(address implementation, bytes data, bytes32 salt) view returns (address)"
        );
    }
}
