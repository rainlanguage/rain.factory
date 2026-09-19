// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {ICloneableFactoryV3} from "src/interface/ICloneableFactoryV3.sol";
import {LibPublishedAbi} from "test/lib/LibPublishedAbi.sol";

/// @title ICloneableFactoryV3AbiTest
/// @notice Pins the published ABI of `ICloneableFactoryV3`: function
/// selectors from their literal signatures, and each ABI entry as it appears
/// in the compiled artifact.
contract ICloneableFactoryV3AbiTest is Test {
    /// `cloneDeterministic(address,bytes,bytes32)` and
    /// `predictDeterministicAddress(address,bytes32,address)` selectors.
    function testFunctionSelectorsPinned() external pure {
        assertEq(
            ICloneableFactoryV3.cloneDeterministic.selector,
            bytes4(keccak256("cloneDeterministic(address,bytes,bytes32)"))
        );
        assertEq(
            ICloneableFactoryV3.predictDeterministicAddress.selector,
            bytes4(keccak256("predictDeterministicAddress(address,bytes32,address)"))
        );
    }

    /// `NewClone`: `sender`, `implementation`, `clone`, `salt`, `data`, in
    /// that order, none indexed, not anonymous.
    function testNewCloneAbiPinned() external view {
        assertTrue(
            vm.contains(
                LibPublishedAbi.artifactJson(vm, "ICloneableFactoryV3", "ICloneableFactoryV3"),
                "{\"type\":\"event\",\"name\":\"NewClone\",\"inputs\":["
                "{\"name\":\"sender\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},"
                "{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},"
                "{\"name\":\"clone\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},"
                "{\"name\":\"salt\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},"
                "{\"name\":\"data\",\"type\":\"bytes\",\"indexed\":false,\"internalType\":\"bytes\"}"
                "],\"anonymous\":false}"
            ),
            "NewClone(address sender, address implementation, address clone, bytes32 salt, bytes data)"
        );
    }

    /// `cloneDeterministic(address implementation, bytes data, bytes32 salt)`
    /// returns an unnamed `address` and is nonpayable.
    function testCloneDeterministicAbiPinned() external view {
        assertTrue(
            vm.contains(
                LibPublishedAbi.artifactJson(vm, "ICloneableFactoryV3", "ICloneableFactoryV3"),
                "{\"type\":\"function\",\"name\":\"cloneDeterministic\",\"inputs\":["
                "{\"name\":\"implementation\",\"type\":\"address\",\"internalType\":\"address\"},"
                "{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"},"
                "{\"name\":\"salt\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}"
                "],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],"
                "\"stateMutability\":\"nonpayable\"}"
            ),
            "cloneDeterministic(address implementation, bytes data, bytes32 salt) returns (address)"
        );
    }

    /// `predictDeterministicAddress(address implementation, bytes32 salt,
    /// address deployer)` returns an unnamed `address` and is view.
    function testPredictDeterministicAddressAbiPinned() external view {
        assertTrue(
            vm.contains(
                LibPublishedAbi.artifactJson(vm, "ICloneableFactoryV3", "ICloneableFactoryV3"),
                "{\"type\":\"function\",\"name\":\"predictDeterministicAddress\",\"inputs\":["
                "{\"name\":\"implementation\",\"type\":\"address\",\"internalType\":\"address\"},"
                "{\"name\":\"salt\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},"
                "{\"name\":\"deployer\",\"type\":\"address\",\"internalType\":\"address\"}"
                "],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],"
                "\"stateMutability\":\"view\"}"
            ),
            "predictDeterministicAddress(address implementation, bytes32 salt, address deployer) view returns (address)"
        );
    }
}
