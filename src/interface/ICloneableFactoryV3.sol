// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

/// @title ICloneableFactoryV3
/// @notice Creates EIP-1167 proxy clones of a reference bytecode at a
/// deterministic, pre-computable address, and emits events so indexers can
/// discover them. Supersedes `ICloneableFactoryV2`, whose `clone` deployed via
/// `CREATE` (nonce-dependent, only knowable after the fact); this interface
/// deploys exclusively via `CREATE2`, so a clone's address is a pure function of
/// `(implementation, salt, caller, factory)` and can be computed — and pinned —
/// before deploying. It knows nothing about the contracts it clones, relying only
/// on the minimal `ICloneableV2` interface being implemented on the reference
/// bytecode.
///
/// Cross-network determinism is inherited from the factory: when the factory is
/// itself deployed at the same address on every chain (a Zoltu deterministic
/// deploy), a `cloneDeterministic` address is identical on every chain for the
/// same caller, implementation and salt.
interface ICloneableFactoryV3 {
    /// Emitted upon each `cloneDeterministic`. Carries the full deterministic
    /// deploy so an indexer can reconstruct it from the event alone — without
    /// reading calldata or relying on the implementation to emit its own init
    /// event: the clone address is a pure function of `(implementation, sender,
    /// salt)`, and the clone's initial state is a function of `data`.
    /// @param sender The `msg.sender` that called `cloneDeterministic`.
    /// @param implementation The reference bytecode cloned as a proxy.
    /// @param clone The address of the new proxy contract.
    /// @param salt The caller-supplied salt (before `msg.sender` namespacing).
    /// @param data The initialization data forwarded to `ICloneableV2.initialize`.
    event NewClone(address sender, address implementation, address clone, bytes32 salt, bytes data);

    /// Deploys an EIP-1167 proxy clone of `implementation` via `CREATE2`. The
    /// factory MUST namespace `salt` by `msg.sender` before deriving the `CREATE2`
    /// salt, so a caller's `(implementation, salt)` address cannot be squatted or
    /// front-run by another account. Distinct salts from one caller yield distinct
    /// clones of the same implementation (many clones per impl).
    ///
    /// The factory MUST call `ICloneableV2.initialize` atomically with the cloning
    /// process and MUST NOT call any other functions on the cloned proxy before
    /// `initialize` completes successfully. The factory MUST ONLY consider the
    /// clone successfully created if `initialize` returns the keccak256 hash of
    /// the string "ICloneableV2.initialize". MUST emit `NewClone` with the
    /// implementation and clone address.
    ///
    /// @param implementation The contract to clone.
    /// @param data As per `ICloneableV2`.
    /// @param salt Caller-chosen salt; distinct salts yield distinct clones.
    /// @return New child contract address.
    function cloneDeterministic(address implementation, bytes calldata data, bytes32 salt) external returns (address);

    /// The address `cloneDeterministic(implementation, _, salt)` deploys to when
    /// called by `deployer`. A pure function of its inputs and this factory, so it
    /// is computable (and pinnable) before deploying, and identical on every chain
    /// this factory exists at the same address on.
    /// @param implementation The contract to clone.
    /// @param salt The caller-chosen salt.
    /// @param deployer The account that will call `cloneDeterministic`.
    /// @return The predicted clone address.
    function predictDeterministicAddress(address implementation, bytes32 salt, address deployer)
        external
        view
        returns (address);
}
