// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

/// @title ICloneableFactoryV2
/// @notice A minimal interface to create proxy clones of a reference bytecode
/// and emit events so that indexers can discover it. `ICloneableFactoryV2` knows
/// nothing about the contracts that it clones, instead relying only on the
/// minimal `ICloneableV2` interface being implemented on the reference bytecode.
///
/// Superseded by `ICloneableFactoryV3`, which deploys only via `CREATE2` and
/// has no `clone`. Published for consumers of factories that implement this
/// interface; nothing in this package implements it.
interface ICloneableFactoryV2 {
    /// Emitted upon each `clone`. Same signature, and so the same topic, as
    /// `ICloneableFactoryV1.NewClone`: a log with this topic does not say which
    /// of the two interfaces the emitting factory implements. Shares only its
    /// NAME with `ICloneableFactoryV3.NewClone`, whose signature and topic
    /// differ.
    /// @param sender The `msg.sender` that called `clone`.
    /// @param implementation The reference bytecode to clone as a proxy.
    /// @param clone The address of the new proxy contract.
    event NewClone(address sender, address implementation, address clone);

    /// Clones an implementation using a proxy. EIP1167 proxy is recommended but
    /// the exact cloning procedure is not specified by this interface.
    ///
    /// The factory MUST call `ICloneableV2.initialize` atomically with the
    /// cloning process and MUST NOT call any other functions on the cloned proxy
    /// before `initialize` completes successfully. The factory MUST ONLY
    /// consider the clone to be successfully created if `initialize` returns the
    /// keccak256 hash of the string "ICloneableV2.initialize".
    ///
    /// MUST emit `NewClone` with the implementation and clone address.
    ///
    /// @param implementation The contract to clone.
    /// @param data As per `ICloneableV2`.
    /// @return New child contract address.
    function clone(address implementation, bytes calldata data) external returns (address);
}
