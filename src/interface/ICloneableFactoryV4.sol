// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

import {ICloneableFactoryV3} from "./ICloneableFactoryV3.sol";

/// @title ICloneableFactoryV4
/// @notice Extends `ICloneableFactoryV3` with an "open salt" deterministic
/// clone. Everything `ICloneableFactoryV3` specifies is unchanged and still
/// required — `cloneDeterministic` keeps namespacing its salt by `msg.sender`,
/// and `predictDeterministicAddress` keeps taking a `deployer`. This interface
/// only ADDS a second derivation alongside it, so a factory may offer both and
/// the caller picks per deploy.
///
/// The two derivations trade off against each other and neither dominates:
///
/// - `cloneDeterministic` derives the `CREATE2` salt from
///   `(msg.sender, salt)`, so nobody but the caller can reach the caller's
///   address. It buys squat-resistance and pays for it with an identity baked
///   into an address: retire the deploying account and every address derived
///   from it becomes unreachable, so a pinned address can never be
///   re-established from a different account.
/// - `cloneDeterministicOpenSalt` uses `salt` verbatim, so the address is a
///   function of `(implementation, salt)` and the factory alone. It buys
///   portability — anyone can deploy it, from any account, on any chain the
///   factory exists at the same address on, forever — and pays for it with
///   squat-resistance: the address is reachable by everybody, and whoever gets
///   there first initializes it.
///
/// Cross-network determinism is inherited from the factory, as in
/// `ICloneableFactoryV3`: when the factory is itself at the same address on
/// every chain (a Zoltu deterministic deploy), an open-salt clone address is
/// the same address on every chain, for every deployer.
interface ICloneableFactoryV4 is ICloneableFactoryV3 {
    /// Deploys an EIP-1167 proxy clone of `implementation` via `CREATE2`, using
    /// the caller-supplied `salt` DIRECTLY as the `CREATE2` salt. The factory
    /// MUST NOT mix `msg.sender`, `tx.origin`, or any other caller-derived value
    /// into the salt, so the deployed address is
    /// `CREATE2(factory, salt, EIP1167(implementation))` — the same address for
    /// every caller.
    ///
    /// Initialization is unchanged from `ICloneableFactoryV3.cloneDeterministic`
    /// and MUST stay atomic with the clone: the factory MUST call
    /// `ICloneableV2.initialize`, MUST NOT call anything else on the proxy
    /// first, and MUST ONLY consider the clone created if `initialize` returns
    /// keccak256("ICloneableV2.initialize"). MUST emit `NewClone`.
    ///
    /// # ONLY FOR IMPLEMENTATIONS WHOSE `initialize` TAKES NO CALLER-CONTROLLED AUTHORITY
    ///
    /// Dropping the `msg.sender` namespacing means anybody can deploy at this
    /// address, with THEIR OWN `data`, before the party that intended to. Since
    /// clone-and-initialize is atomic and `initialize` runs exactly once, the
    /// first deployer's `data` sets the clone's state permanently — including
    /// whatever authority that state confers. There is no recovery: the address
    /// is occupied and nobody can redeploy over it.
    ///
    /// So this variant is safe under exactly one condition: **there must be
    /// nothing for a squatter to vary.** Concretely, for every `data` any
    /// account could pass at a given `salt`, the resulting contract must be the
    /// contract that was intended. If two different `data` values at the same
    /// salt can produce clones that differ in who controls them, what they
    /// trust, or any other property that matters, the implementation does NOT
    /// qualify and MUST use `cloneDeterministic` instead.
    ///
    /// In practice that means `initialize` MUST NOT read any address, key,
    /// role, owner, admin, or other authority out of `data` (nor out of
    /// `msg.sender`, which for a clone is the factory anyway). An `initialize`
    /// that takes an `owner` address argument is disqualified by that argument
    /// alone: a squatter passes their own address and owns the contract that
    /// everybody else has already pinned.
    ///
    /// This is the same property that makes permissionless deterministic
    /// (Zoltu-style) deployment harmless. A Zoltu deploy has no arguments at
    /// all, so a stranger front-running it produces byte-for-byte the intended
    /// contract and has done nothing but pay the gas. An open-salt clone has
    /// arguments, so it must reach that same position by construction rather
    /// than by having none.
    ///
    /// The intended pairing that does reach it is an address registry — such as
    /// rain.deploy's — resolving authority by NAME:
    ///
    /// - `initialize` takes a NAME, not an address, and resolves the admin by
    ///   looking that name up in the registry. A squatter cannot substitute a
    ///   different admin, because the clone never accepts an admin address; the
    ///   registry decides who the name resolves to.
    /// - The `salt` COMMITS to that name (it is derived from it). A squatter
    ///   cannot pass a different name either, because a different name is a
    ///   different salt, which is a different address — not the one anyone
    ///   pinned.
    ///
    /// With both halves in place the squatter's only reachable move at the
    /// pinned address is to deploy exactly the intended contract. Either half
    /// alone is insufficient: an admin address in `data` is substitutable even
    /// if the salt commits to something, and a name that the salt does not
    /// commit to is substitutable even though it goes through the registry.
    ///
    /// # Events
    ///
    /// `NewClone` is shared with `cloneDeterministic` and is emitted
    /// identically, so its `sender` field is only whoever paid for this deploy;
    /// for an open-salt clone it is NOT part of the address derivation, and an
    /// indexer reconstructing the address MUST use `CREATE2(factory, salt,
    /// EIP1167(implementation))` for clones deployed through this function.
    ///
    /// @param implementation The contract to clone.
    /// @param data As per `ICloneableV2`. MUST NOT carry authority — see above.
    /// @param salt Used verbatim as the `CREATE2` salt; distinct salts yield
    /// distinct clones.
    /// @return New child contract address.
    function cloneDeterministicOpenSalt(address implementation, bytes calldata data, bytes32 salt)
        external
        returns (address);

    /// The address `cloneDeterministicOpenSalt(implementation, _, salt)` deploys
    /// to. Takes no `deployer` because there is none in the derivation — that is
    /// the entire difference from `predictDeterministicAddress`. A pure function
    /// of its inputs and this factory, so it is computable (and pinnable) before
    /// deploying, by anyone, and identical on every chain this factory exists at
    /// the same address on.
    ///
    /// A non-zero code size at the returned address means the salt is already
    /// taken and `cloneDeterministicOpenSalt` will revert there. Callers who
    /// care WHICH contract occupies it MUST check that as well as the code
    /// size — see the authority warning on `cloneDeterministicOpenSalt`.
    ///
    /// @param implementation The contract to clone.
    /// @param salt The caller-chosen salt.
    /// @return The predicted clone address.
    function predictDeterministicAddressOpenSalt(address implementation, bytes32 salt) external view returns (address);
}
