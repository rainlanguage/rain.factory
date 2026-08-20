// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

import {ICloneableFactoryV3} from "./ICloneableFactoryV3.sol";

/// @dev Domain tag hashed as the FIRST word of the `cloneDeterministic` /
/// `predictDeterministicAddress` effective `CREATE2` salt on a factory that
/// implements `ICloneableFactoryV4`. String-derived so the literal is its own
/// documentation. Its job is to keep the namespaced derivation's image disjoint
/// from the open-salt one BY CONSTRUCTION: the two tags are distinct fixed
/// words and no caller can place either in word 0 of the other derivation, so
/// neither entry point can be aimed at an address the other produces. See
/// `ICloneableFactoryV4`.
bytes32 constant ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN = keccak256("rain.factory.clone.namespaced");

/// @dev Domain tag hashed as the FIRST word of the `cloneDeterministicOpenSalt`
/// / `predictDeterministicAddressOpenSalt` effective `CREATE2` salt.
/// String-derived so the literal is its own documentation. Pairs with
/// `ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN`: the two are distinct fixed words,
/// so the open-salt and namespaced images cannot overlap and no other entry
/// point on the factory can be aimed at an open-salt address. See
/// `ICloneableFactoryV4`.
bytes32 constant ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN = keccak256("rain.factory.clone.opensalt");

/// @title ICloneableFactoryV4
/// @notice A factory with two deterministic-clone derivations, both pinned to
/// exact bytes. The namespaced pair — `cloneDeterministic`, which namespaces its
/// salt by `msg.sender`, and `predictDeterministicAddress`, which takes a
/// `deployer` — is inherited from `ICloneableFactoryV3`. The open-salt pair,
/// `cloneDeterministicOpenSalt` / `predictDeterministicAddressOpenSalt`, is
/// defined here. A factory may offer both, and the caller picks per deploy.
///
/// Both effective `CREATE2` salts are a `keccak256` over a 96-byte preimage
/// whose FIRST word is a distinct, string-derived domain tag the caller cannot
/// set:
///
/// ```
/// // cloneDeterministic / predictDeterministicAddress (the namespaced pair)
/// keccak256(abi.encode(
///     ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN, msg.sender, salt
/// ))
///
/// // cloneDeterministicOpenSalt / predictDeterministicAddressOpenSalt
/// keccak256(abi.encode(
///     ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data)
/// ))
/// ```
///
/// so third parties can recompute either, and the two `predict…` functions are
/// the factory saying the same thing. The two tags differ, so the two images
/// are disjoint by construction — see the disjointness note on
/// `cloneDeterministicOpenSalt`.
///
/// The difference between the two is which of the deployer and the
/// initialization data the clone's address commits to:
///
/// - `cloneDeterministic` derives its salt from `msg.sender` and `salt` (behind
///   the namespaced tag). The address commits to WHO deployed and not to WHAT
///   was deployed. It buys squat-resistance — nobody but that account can reach
///   that address — and pays with an identity baked into an address: retire the
///   deploying account and every address derived from it becomes unreachable,
///   so a pinned address can never be re-established from a different account.
///   It also leaves `data` outside the derivation, so the deployer alone
///   decides the clone's initial state at an address that says nothing about it.
/// - `cloneDeterministicOpenSalt` derives its salt from `salt` and `data`
///   (behind the open-salt tag). The address commits to WHAT was deployed and
///   not to WHO deployed it. Every account reaches the same address — and so
///   can anyone — but every account that reaches it deploys the same contract,
///   initialized with the same bytes, because varying either input lands
///   somewhere else.
///
/// Neither dominates. Open-salt costs the ability to choose an address before
/// the initialization data is final: the address is not knowable until `data`
/// is, and re-deploying "the same" clone with corrected `data` is a different
/// address. Sender-namespacing costs portability across accounts. A consumer
/// pinning an open-salt address must be able to reproduce the exact `data`
/// bytes, ABI encoding and all, since a byte of difference is a different
/// address.
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
    /// Initialization MUST be atomic with the clone, per the shared spec in
    /// `ICloneableFactoryV3.cloneDeterministic`: the factory MUST call
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
    /// - Registry-resolved authority is the ordinary case: it is simply `data`
    ///   that names things instead of naming addresses. `data` MAY be empty, and
    ///   an implementation that resolves everything from the registry will pass
    ///   empty `data`.
    ///
    /// # Obligation on the factory, not on the consumer
    ///
    /// The guarantee above holds only while no OTHER entry point on the same
    /// factory can `CREATE2` at an effective salt in this derivation's image
    /// with caller-supplied initialization data. The inherited
    /// `cloneDeterministic` is exactly such an entry point — it takes arbitrary
    /// `data` — so the two derivations MUST NOT share an effective-salt image,
    /// and a factory implementing this interface MUST NOT expose any entry point
    /// that does.
    ///
    /// They do not overlap, by construction. Both preimages are 96 bytes whose
    /// FIRST word is a fixed domain tag no caller can set:
    /// `cloneDeterministic` hashes
    /// `abi.encode(ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN, msg.sender, salt)`
    /// and this function hashes
    /// `abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data))`.
    /// The two domain constants are distinct `keccak256` outputs, so the two
    /// preimage sets are disjoint in their first word alone. A caller on the
    /// namespaced path chooses only words 1 and 2 (`msg.sender` and `salt`); a
    /// caller here chooses only words 1 and 2 (`salt` and `keccak256(data)`);
    /// neither can place the other derivation's tag in word 0, so neither can
    /// aim its entry point at an address the other produces. The disjointness is
    /// a property of the two fixed tags.
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
