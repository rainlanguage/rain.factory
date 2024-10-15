// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity ^0.8.18;

/// @title ICloneableFactoryV1
/// @notice A minimal interface to create proxy clones of a reference bytecode
/// and emit events so that indexers can discover it. `ICloneableFactoryV1` knows
/// nothing about the contracts that it clones, instead relying only on the
/// minimal `ICloneableV1` interface being implemented on the reference bytecode.
interface ICloneableFactoryV1 {
    /// Emitted upon each `clone`.
    /// @param sender The `msg.sender` that called `clone`.
    /// @param implementation The reference bytecode to clone as a proxy.
    /// @param clone The address of the new proxy contract.
    event NewClone(address sender, address implementation, address clone);

    /// Clones an implementation using a proxy. EIP1167 proxy as used by Open
    /// Zeppelin is recommended but the exact cloning procedure is not specified
    /// by this interface. The factory MUST call `ICloneableV1.initialize`
    /// atomically with the cloning process and MUST NOT call any other functions
    /// on the cloned proxy before initialize completes successfully. If the
    /// initialize reverts then the `clone` MUST revert.
    /// MUST emit `NewClone` with the implementation and clone address.
    /// @param implementation The contract to clone.
    /// @param data As per `ICloneableV1`.
    /// @return New child contract address.
    function clone(address implementation, bytes calldata data) external returns (address);
}
