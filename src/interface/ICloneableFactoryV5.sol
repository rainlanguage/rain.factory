// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ICloneableFactoryV4} from "./deprecated/ICloneableFactoryV4.sol";

/// @dev Word 0 of the beacon-proxy effective-salt preimage, distinct from both
/// `ICloneableFactoryV4` tags.
bytes32 constant ICLONEABLE_FACTORY_V5_BEACON_PROXY_OPEN_SALT_DOMAIN = keccak256("rain.factory.beaconproxy.opensalt");

/// @dev `keccak256` of the OpenZeppelin `BeaconProxy` creation code, without
/// constructor arguments, that `ICloneableFactoryV5` deploys.
/// Part of the V5 spec: a different hash is a different derivation and needs a
/// new interface version, never an edit here.
bytes32 constant ICLONEABLE_FACTORY_V5_BEACON_PROXY_CREATION_CODE_HASH =
    0xe1ae7c0d01fd026af8df65ef9ca88d99cef57ff3b31eaa283d3101ccb42a02a2;

/// @title ICloneableFactoryV5
/// @notice Adds a deterministic open-salt OpenZeppelin `BeaconProxy` derivation
/// to the `ICloneableFactoryV4` clone derivations. Effective `CREATE2` salt:
/// `keccak256(abi.encode(BEACON_PROXY_OPEN_SALT_DOMAIN, salt, keccak256(data)))`;
/// creation code: the `BeaconProxy` creation code hashing to
/// `ICLONEABLE_FACTORY_V5_BEACON_PROXY_CREATION_CODE_HASH`, `++ abi.encode(beacon, bytes(""))`.
/// The address commits to `(factory, beacon, salt, data)`, not the caller, and
/// not the implementation the beacon serves: the beacon owner is trusted for
/// the proxy's behaviour and, since `initialize` runs on what the beacon serves
/// at deploy time, its initial state. Anyone picks the deploy time, and so
/// which implementation initializes a pinned address: every implementation the
/// beacon serves while it is undeployed MUST give the same `initialize(data)`
/// result, or revert, and MUST otherwise meet the `cloneDeterministicOpenSalt`
/// rules. A version tag leading `data`, which an implementation that does not
/// know it rejects, meets the first rule.
/// Every deploy bubbles a reverting `initialize` verbatim, so a revert's
/// selector and arguments, the factory's own errors included, may be the
/// deployed contract's: re-derive an address with a predict function.
interface ICloneableFactoryV5 is ICloneableFactoryV4 {
    /// Emitted by `beaconProxyDeterministicOpenSalt` after `CREATE2`, before
    /// `initialize`, in place of `NewClone`.
    /// @param sender The `msg.sender` that called it.
    /// @param beacon The proxy's beacon.
    /// @param proxy The deployed proxy.
    /// @param salt The raw caller salt.
    /// @param data The `initialize` data.
    event NewBeaconProxy(address sender, address beacon, address proxy, bytes32 salt, bytes data);

    /// Deploys the beacon proxy at the open-salt address, emits
    /// `NewBeaconProxy` and no `NewClone`, then initializes it as
    /// `ICloneableFactoryV3.cloneDeterministic` does: `initialize(data)` first
    /// and only, success sentinel checked. `initialize` runs after `CREATE2`,
    /// not as constructor data, whose return `BeaconProxy` discards. MUST
    /// revert if `beacon` or `beacon.implementation()` has no code or is an
    /// EIP-7702 delegated account. MUST NOT mix any caller-derived value into
    /// the salt, nor expose another entry point whose salt image overlaps
    /// this one. Needs a Cancun chain: the proxy creation code uses `MCOPY`.
    /// @param beacon The OpenZeppelin `IBeacon` the proxy reads.
    /// @param data Passed to `initialize`; part of the address.
    /// @param salt Part of the address; emitted raw in `NewBeaconProxy`.
    /// @return The deployed proxy.
    function beaconProxyDeterministicOpenSalt(address beacon, bytes calldata data, bytes32 salt)
        external
        returns (address);

    /// The address `beaconProxyDeterministicOpenSalt` deploys to, for any
    /// caller. Does not read the beacon.
    /// @param beacon As for `beaconProxyDeterministicOpenSalt`.
    /// @param data As for `beaconProxyDeterministicOpenSalt`.
    /// @param salt As for `beaconProxyDeterministicOpenSalt`.
    /// @return The proxy address.
    function predictBeaconProxyAddressOpenSalt(address beacon, bytes calldata data, bytes32 salt)
        external
        view
        returns (address);
}
