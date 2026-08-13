// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

import {ICloneableFactoryV3} from "./ICloneableFactoryV3.sol";

/// @dev Domain separator mixed into every `cloneDeterministicOpenSalt` effective
/// salt. Its only job is to keep the open-salt derivation's image disjoint from
/// every other derivation the same factory offers, so no other entry point on
/// the factory can be aimed at an open-salt address. See `ICloneableFactoryV4`.
bytes32 constant ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN = keccak256("ICloneableFactoryV4.cloneDeterministicOpenSalt");

/// @title ICloneableFactoryV4
/// @notice Extends `ICloneableFactoryV3` with an "open salt" deterministic
/// clone. Everything `ICloneableFactoryV3` specifies is unchanged and still
/// required — `cloneDeterministic` keeps namespacing its salt by `msg.sender`,
/// and `predictDeterministicAddress` keeps taking a `deployer`. This interface
/// only ADDS a second derivation alongside it, so a factory may offer both and
/// the caller picks per deploy.
///
/// The difference between the two is which of the deployer and the
/// initialization data the clone's address commits to:
///
/// - `cloneDeterministic` derives the `CREATE2` salt from `(msg.sender, salt)`.
///   The address commits to WHO deployed and not to WHAT was deployed. It buys
///   squat-resistance — nobody but that account can reach that address — and
///   pays with an identity baked into an address: retire the deploying account
///   and every address derived from it becomes unreachable, so a pinned address
///   can never be re-established from a different account. It also leaves
///   `data` outside the derivation, so the deployer alone decides the clone's
///   initial state at an address that says nothing about it.
/// - `cloneDeterministicOpenSalt` derives the `CREATE2` salt from
///   `(salt, data)`. The address commits to WHAT was deployed and not to WHO
///   deployed it. Every account reaches the same address — and so can anyone —
///   but every account that reaches it deploys the same contract, initialized
///   with the same bytes, because varying either input lands somewhere else.
///
/// Neither dominates. Open-salt costs the ability to choose an address before
/// the initialization data is final: the address is not knowable until `data`
/// is, and re-deploying "the same" clone with corrected `data` is a different
/// address. Sender-namespacing costs portability across accounts. A consumer
/// pinning an open-salt address must be able to reproduce the exact `data`
/// bytes, ABI encoding and all, since a byte of difference is a different
/// address.
///
/// The open-salt effective `CREATE2` salt is fixed by this interface as
///
/// ```
/// keccak256(abi.encode(
///     ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data)
/// ))
/// ```
///
/// so third parties can recompute it, and `predictDeterministicAddressOpenSalt`
/// is the factory saying the same thing.
///
/// Cross-network determinism is NOT a property of either derivation on its own.
/// `CREATE2` hashes the deploying factory's address, and the EIP-1167 creation
/// code it hashes contains the implementation's address, so an open-salt clone
/// is at the same address on two chains only when BOTH the factory and the
/// implementation are at the same address on both — each deployed
/// deterministically (Zoltu-style), all the way down. Dropping `msg.sender` from
/// the derivation removes the deployer as a third thing that has to match; it
/// does not make the other two match. If the implementation is deployed by an
/// ordinary nonce-dependent `CREATE` on each chain, its address differs per
/// chain and so does every clone of it, on both derivations.
interface ICloneableFactoryV4 is ICloneableFactoryV3 {
    /// Deploys an EIP-1167 proxy clone of `implementation` via `CREATE2` at an
    /// address that does not depend on the caller and does depend on the
    /// initialization data.
    ///
    /// The factory MUST use
    /// `keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data)))`
    /// as the `CREATE2` salt, so the deployed address is a pure function of
    /// `(factory, implementation, salt, data)`. The factory MUST NOT mix
    /// `msg.sender`, `tx.origin`, or any other caller-derived value into it.
    ///
    /// Initialization is unchanged from `ICloneableFactoryV3.cloneDeterministic`
    /// and MUST stay atomic with the clone: the factory MUST call
    /// `ICloneableV2.initialize` with `data` verbatim, MUST NOT call anything
    /// else on the proxy first, and MUST ONLY consider the clone created if
    /// `initialize` returns keccak256("ICloneableV2.initialize"). MUST emit
    /// `NewClone`.
    ///
    /// # Why hashing `data` into the salt is the whole point
    ///
    /// Without the `msg.sender` namespacing, anybody can deploy at this address
    /// before the party that intended to, and since clone-and-initialize is
    /// atomic and `initialize` runs exactly once, whoever gets there first sets
    /// the clone's state permanently. There is no recovery: the address is
    /// occupied and nobody can redeploy over it.
    ///
    /// That is only dangerous if the first deployer has anything to vary.
    /// Because `data` is inside the derivation, they do not:
    ///
    /// - A front-runner passing DIFFERENT `data` derives a DIFFERENT address.
    ///   The address anyone pinned is untouched; the front-runner has deployed
    ///   their own contract at their own address, at their own expense.
    /// - A front-runner passing the SAME `data` produces the contract that was
    ///   intended, initialized with the bytes that were intended, and has done
    ///   nothing but pay the gas.
    ///
    /// This is the same position that makes permissionless deterministic
    /// (Zoltu-style) deployment harmless — a Zoltu deploy has no arguments, so
    /// front-running it produces byte-for-byte the intended contract — reached
    /// WITH arguments, by putting the arguments in the address rather than by
    /// having none. It is a property of this signature, not a condition on the
    /// implementation being cloned, so there is no per-implementation audit of
    /// "could a squatter pass something worse" to get wrong.
    ///
    /// # What the address does NOT fix, which implementations MUST respect
    ///
    /// The address fixes `data`. It cannot fix anything `initialize` reads that
    /// is not `data`, so the deployer keeps exactly one lever: WHEN the deploy
    /// lands, and therefore which chain state `initialize` observes.
    ///
    /// - The implementation MUST NOT read `tx.origin`, directly or through
    ///   anything it calls during initialization. `tx.origin` is the deployer,
    ///   and it is the one remaining channel by which the deployer could reach
    ///   initial state. (`msg.sender` during `initialize` is the factory, which
    ///   is the same for every caller and therefore harmless.)
    /// - Anything else `initialize` resolves from chain state resolves the same
    ///   way for every caller at a given block. An address registry — such as
    ///   rain.deploy's — is the intended shape here: `initialize` resolves the
    ///   admin by NAME from the registry rather than taking an admin address,
    ///   and the name, being part of `data`, is committed to by the address.
    ///   A front-runner resolves the same admin the intended deployer would
    ///   have. While the name is unbound the registry read reverts, so the
    ///   clone cannot be deployed at all, and the front-running window only
    ///   opens once the binding exists. A clone that resolves once during
    ///   `initialize` and stores the answer is unaffected by any later
    ///   rebinding.
    /// - Registry-resolved authority is now the ordinary case rather than a
    ///   special one: it is simply `data` that names things instead of naming
    ///   addresses. `data` MAY be empty, and an implementation that resolves
    ///   everything from the registry will pass empty `data`.
    ///
    /// # Obligation on the factory, not on the consumer
    ///
    /// The guarantee above holds only while no OTHER entry point on the same
    /// factory can `CREATE2` at an effective salt in this derivation's image
    /// with caller-supplied initialization data. A factory implementing this
    /// interface MUST NOT expose one. That is what
    /// `ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN` is for: it separates this
    /// derivation from the inherited `cloneDeterministic` one — which does take
    /// arbitrary `data` — by both a domain tag and a preimage length, so
    /// aiming `cloneDeterministic` at an open-salt address requires a keccak256
    /// preimage rather than a choice of salt.
    ///
    /// # Events
    ///
    /// `NewClone` is shared with `cloneDeterministic` and is emitted
    /// identically, with the caller-supplied `salt` — NOT the effective salt.
    /// Its `sender` field is only whoever paid for this deploy and is not part
    /// of the address derivation, but `salt` and `data` together are the whole
    /// of it, so the event still carries the full deterministic deploy that
    /// `ICloneableFactoryV3.NewClone` promises. An indexer that wants to verify
    /// the address rather than take the emitted one MUST pick the derivation:
    /// the two cannot both produce the emitted `clone`, so trying both and
    /// keeping the match is well defined.
    ///
    /// @param implementation The contract to clone.
    /// @param data As per `ICloneableV2`, and part of the address derivation.
    /// MAY be empty.
    /// @param salt Caller-chosen salt. Distinguishes clones that share an
    /// implementation and `data`; distinct `(salt, data)` pairs yield distinct
    /// clones.
    /// @return New child contract address.
    function cloneDeterministicOpenSalt(address implementation, bytes calldata data, bytes32 salt)
        external
        returns (address);

    /// The address `cloneDeterministicOpenSalt(implementation, data, salt)`
    /// deploys to. Takes `data` because `data` is in the derivation, and takes
    /// no `deployer` because the deployer is not — that is the entire
    /// difference from `predictDeterministicAddress`. A pure function of its
    /// inputs and this factory, so it is computable (and pinnable) before
    /// deploying, by anyone. Identical across chains only where both this
    /// factory and `implementation` are at the same address on each — see the
    /// cross-network note on this interface.
    ///
    /// A non-zero code size at the returned address means this exact
    /// `(implementation, data, salt)` has already been deployed by somebody and
    /// `cloneDeterministicOpenSalt` will revert there. Since nothing else can
    /// be deployed there, what occupies it is the clone that was asked for,
    /// initialized with the bytes that were asked for.
    ///
    /// @param implementation The contract to clone.
    /// @param data The initialization data that will be passed to
    /// `ICloneableV2.initialize`.
    /// @param salt The caller-chosen salt.
    /// @return The predicted clone address.
    function predictDeterministicAddressOpenSalt(address implementation, bytes calldata data, bytes32 salt)
        external
        view
        returns (address);
}
