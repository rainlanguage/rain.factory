// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

import {ICloneableFactoryV4} from "./deprecated/ICloneableFactoryV4.sol";

/// @dev Domain tag hashed as the FIRST word of the
/// `beaconProxyDeterministicOpenSalt` / `predictBeaconProxyAddressOpenSalt`
/// effective `CREATE2` salt. String-derived so the literal is its own
/// documentation. Joins `ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN` and
/// `ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN`: the three are distinct fixed
/// words, so the beacon-proxy image overlaps neither clone image and no other
/// entry point on the factory can be aimed at a beacon-proxy address. See
/// `ICloneableFactoryV5`.
bytes32 constant ICLONEABLE_FACTORY_V5_BEACON_PROXY_OPEN_SALT_DOMAIN = keccak256("rain.factory.beaconproxy.opensalt");

/// @title ICloneableFactoryV5
/// @notice A factory with the two `ICloneableFactoryV4` EIP-1167 clone
/// derivations, inherited, plus a deterministic open-salt BEACON PROXY
/// derivation defined here: `beaconProxyDeterministicOpenSalt` /
/// `predictBeaconProxyAddressOpenSalt`. The proxy is a minimal ERC-1967 beacon
/// proxy with the beacon fixed in its code, so the address commits to the
/// beacon and the initialization data, and to nothing about the caller.
///
/// The effective `CREATE2` salt is a `keccak256` over a 96-byte preimage whose
/// FIRST word is a domain tag the caller cannot set, distinct from both
/// `ICloneableFactoryV4` tags:
///
/// ```
/// keccak256(abi.encode(
///     ICLONEABLE_FACTORY_V5_BEACON_PROXY_OPEN_SALT_DOMAIN, salt, keccak256(data)
/// ))
/// ```
///
/// and the `CREATE2` creation code is the proxy's own, which embeds `beacon`.
/// So the address is a pure function of `(factory, beacon, salt, data)`, and
/// third parties can recompute it.
///
/// # The beacon owner is the trust point
///
/// `ICloneableFactoryV4.cloneDeterministicOpenSalt` says an implementation MUST
/// NOT delegate onward to a target anyone can change, because that derivation
/// fixes the implementation's ADDRESS and a consumer reading the address takes
/// it to fix the clone's behaviour. A beacon proxy delegates onward by design,
/// so this derivation does not claim that. It fixes the BEACON, names it in the
/// address, and leaves the clone's behaviour to whoever can change what the
/// beacon returns from `implementation()` — the beacon owner, or whatever
/// governs the beacon's code. That party is trusted for everything the address
/// does not fix:
///
/// - Behaviour after deploy. Retargeting the beacon changes the code every
///   proxy of it runs, at once.
/// - Initial state. `initialize` runs on the implementation the beacon returns
///   at deploy time, and the address does not fix which. The beacon owner can
///   retarget, deploy the pinned `(beacon, data, salt)` against an
///   implementation that initializes differently, and retarget back, all in one
///   transaction. The open-salt squat-resistance below holds against every
///   OTHER party.
///
/// The V4 rule is therefore not relaxed, it is moved: the one changeable
/// delegation target allowed is the beacon this address names, and the
/// consumer opts into trusting its owner by choosing this derivation. Every
/// implementation the beacon serves MUST still meet the rest of the V4 list on
/// `cloneDeterministicOpenSalt` — no `tx.origin`, gas MUST NOT select state, no
/// third-party-settable chain state — and MUST NOT itself delegate onward to a
/// target anyone other than the beacon owner can change. A beacon nobody can
/// retarget reduces to the V4 open-salt guarantee for the implementation it
/// returns.
///
/// Cross-network determinism needs the factory and the beacon at the same
/// address on each chain; the implementation's address is not in the
/// derivation.
interface ICloneableFactoryV5 is ICloneableFactoryV4 {
    /// Deploys a minimal ERC-1967 beacon proxy for `beacon` via `CREATE2` at an
    /// address that does not depend on the caller and does depend on `beacon`
    /// and the initialization data.
    ///
    /// The proxy's construction MUST write `beacon` to the ERC-1967 beacon
    /// slot, `bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1)`, emit
    /// ERC-1967 `BeaconUpgraded(beacon)`, and call nothing — no constructor-time
    /// initialization. Every call to the proxy MUST `STATICCALL`
    /// `beacon.implementation()` on the beacon fixed in its code (not the one
    /// in the slot) and `DELEGATECALL` the result with the call's calldata,
    /// returning or reverting with the result's return data; a beacon call that
    /// reverts MUST revert with the beacon's revert data, and one that returns
    /// fewer than 32 bytes or a value that is not an address MUST revert with
    /// no data. This is OpenZeppelin `BeaconProxy`'s observable behaviour.
    ///
    /// The factory MUST use
    /// `keccak256(abi.encode(ICLONEABLE_FACTORY_V5_BEACON_PROXY_OPEN_SALT_DOMAIN, salt, keccak256(data)))`
    /// as the `CREATE2` salt and MUST NOT mix `msg.sender`, `tx.origin`, or any
    /// other caller-derived value into it.
    ///
    /// The factory MUST revert if `beacon` has no code, or if the address
    /// `beacon.implementation()` returns has no code or is an EIP-7702
    /// delegated account. That checks the beacon at deploy time only; the
    /// beacon owner can retarget it afterwards.
    ///
    /// Initialization MUST be atomic with the deploy, exactly as
    /// `ICloneableFactoryV4.cloneDeterministicOpenSalt`: the factory MUST call
    /// `ICloneableV2.initialize` with `data` verbatim, MUST NOT call anything
    /// else on the proxy first, and MUST ONLY consider the proxy created if
    /// `initialize` returns keccak256("ICloneableV2.initialize").
    ///
    /// # Open salt
    ///
    /// As on `ICloneableFactoryV4.cloneDeterministicOpenSalt`, `data` inside
    /// the derivation is what makes the open salt safe: a front-runner with
    /// different `data` or a different beacon derives a different address, and
    /// one with the same inputs deploys the intended proxy — subject to the
    /// beacon owner, per the trust note on this interface.
    ///
    /// # Disjointness
    ///
    /// The V4 obligation that no other entry point can `CREATE2` in an
    /// open-salt image with caller-supplied `data` holds for all three
    /// derivations. Each preimage is 96 bytes whose FIRST word is a fixed tag
    /// no caller can set, and the three tags —
    /// `ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN`,
    /// `ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN` and
    /// `ICLONEABLE_FACTORY_V5_BEACON_PROXY_OPEN_SALT_DOMAIN` — are distinct
    /// `keccak256` outputs, so the three effective-salt images are disjoint in
    /// their first word alone. Callers on every path choose only words 1 and 2,
    /// so none can aim its entry point at an address another produces. The
    /// beacon-proxy creation code also differs from every EIP-1167 creation
    /// code, but disjointness does not rest on that.
    ///
    /// # Events
    ///
    /// MUST emit `NewClone` exactly as `cloneDeterministicOpenSalt` does, with
    /// `beacon` in its `implementation` field and the caller-supplied `salt`.
    /// `beacon`, `salt` and `data` are the whole derivation. An indexer
    /// verifying the emitted `clone` tries the three derivations and keeps the
    /// match, which is well defined because at most one produces it.
    ///
    /// @param beacon The ERC-1967 beacon the proxy resolves its implementation
    /// through. Part of the address derivation.
    /// @param data As per `ICloneableV2`, and part of the address derivation.
    /// MAY be empty.
    /// @param salt Caller-chosen salt. Distinguishes proxies that share a
    /// beacon and `data`.
    /// @return The new proxy's address.
    function beaconProxyDeterministicOpenSalt(address beacon, bytes calldata data, bytes32 salt)
        external
        returns (address);

    /// The address `beaconProxyDeterministicOpenSalt(beacon, data, salt)`
    /// deploys to, from any caller. A pure function of its inputs and this
    /// factory, so it is pinnable before deploying, by anyone. It does not read
    /// the beacon, and the address does not change when the beacon is
    /// retargeted.
    ///
    /// Non-zero code at the returned address means this exact
    /// `(beacon, data, salt)` has been deployed and
    /// `beaconProxyDeterministicOpenSalt` will revert there.
    ///
    /// @param beacon The ERC-1967 beacon the proxy resolves its implementation
    /// through.
    /// @param data The initialization data that will be passed to
    /// `ICloneableV2.initialize`.
    /// @param salt The caller-chosen salt.
    /// @return The predicted proxy address.
    function predictBeaconProxyAddressOpenSalt(address beacon, bytes calldata data, bytes32 salt)
        external
        view
        returns (address);
}
