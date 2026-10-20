// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

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
/// creation code: `BEACON_PROXY_CREATION_CODE ++ abi.encode(beacon, bytes(""))`.
/// The address commits to `(factory, beacon, salt, data)`, not the caller, and
/// not the implementation the beacon serves: the beacon owner is trusted for
/// the proxy's behaviour and, since `initialize` runs on what the beacon serves
/// at deploy time, its initial state. Every implementation the beacon serves
/// MUST otherwise meet the `cloneDeterministicOpenSalt` rules.
interface ICloneableFactoryV5 is ICloneableFactoryV4 {
    /// Deploys the beacon proxy at the open-salt address, then initializes it
    /// as `ICloneableFactoryV3.cloneDeterministic` does: `initialize(data)`
    /// first and only, success sentinel checked, raw-salt `NewClone` with
    /// `beacon` as `implementation`. `initialize` runs after `CREATE2`, not as
    /// constructor data, whose return `BeaconProxy` discards. MUST revert if
    /// `beacon` has no code, or `beacon.implementation()` has no code or is an
    /// EIP-7702 delegated account. MUST NOT mix any caller-derived value into
    /// the salt. `NewClone.implementation` holds the beacon, not cloned
    /// bytecode: an indexer tells a beacon proxy from an EIP-1167 clone by
    /// re-deriving `clone` from the event under each domain tag.
    /// Needs a Cancun chain: the proxy creation code uses `MCOPY`.
    /// @param beacon The OpenZeppelin `IBeacon` the proxy reads.
    /// @param data Passed to `initialize`; part of the address.
    /// @param salt Part of the address; emitted raw in `NewClone`.
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
