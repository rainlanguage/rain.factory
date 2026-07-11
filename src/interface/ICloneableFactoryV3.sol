// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

import {ICloneableFactoryV2} from "./ICloneableFactoryV2.sol";

/// @title ICloneableFactoryV3
/// @notice Extends `ICloneableFactoryV2` with a deterministic clone whose address
/// is pre-computable. `clone` (inherited) deploys via `CREATE`, so the address is
/// nonce-dependent and only knowable after the fact; `cloneDeterministic` deploys
/// via `CREATE2`, so the address is a pure function of `(implementation, salt,
/// caller, factory)` and can be computed — and pinned — before deploying.
///
/// Cross-network determinism is inherited from the factory: when the factory is
/// itself deployed at the same address on every chain (a Zoltu deterministic
/// deploy), a `cloneDeterministic` address is identical on every chain for the
/// same caller, implementation and salt.
interface ICloneableFactoryV3 is ICloneableFactoryV2 {
    /// Deterministic variant of `clone`: deploys the EIP-1167 proxy via `CREATE2`.
    /// The factory MUST namespace `salt` by `msg.sender` before deriving the
    /// `CREATE2` salt, so a caller's `(implementation, salt)` address cannot be
    /// squatted or front-run by another account. Distinct salts from one caller
    /// yield distinct clones of the same implementation (many clones per impl).
    ///
    /// Same `initialize`/`NewClone` contract as `clone`: MUST emit `NewClone` and
    /// MUST only succeed if `ICloneableV2.initialize` returns
    /// `keccak256("ICloneableV2.initialize")`.
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
