// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ICloneableFactoryV5} from "./ICloneableFactoryV5.sol";

/// @dev Domain separating the registry beacon proxy salt from every other
/// derivation.
bytes32 constant ICLONEABLE_FACTORY_V6_REGISTRY_BEACON_PROXY_DOMAIN = keccak256("rain.factory.registrybeaconproxy");

/// @title ICloneableFactoryV6
/// @notice `ICloneableFactoryV5` plus beacon proxies whose beacon is resolved
/// from a config registry, so the same proxy has the same address on every
/// chain while each chain binds its own beacon. The proxy's creation code holds
/// no beacon: the address commits to the registry, the authority, the beacon's
/// name, the salt and the init data, and whatever that binding resolves to on
/// the chain is the beacon.
interface ICloneableFactoryV6 is ICloneableFactoryV5 {
    /// A registry beacon proxy was deployed and initialized.
    /// @param sender The caller.
    /// @param registry The registry the beacon was resolved from.
    /// @param authority The authority the beacon's name is bound under.
    /// @param beaconName The name the beacon is bound to.
    /// @param beacon The beacon it resolved to.
    /// @param proxy The proxy.
    /// @param salt The caller's salt.
    /// @param data The init data.
    event NewRegistryBeaconProxy(
        address sender,
        address registry,
        address authority,
        bytes32 beaconName,
        address beacon,
        address proxy,
        bytes32 salt,
        bytes data
    );

    /// Resolves `beaconName` under `authority` in `registry` to a beacon, then
    /// deploys a proxy of it at an address that commits to the registry, the
    /// authority, the name, `salt` and `data`, and initializes it with `data`.
    /// The binding's value is `abi.encode(beacon)`.
    /// @param registry A config registry answering `getV3`.
    /// @param authority The authority the name is bound under.
    /// @param beaconName The name the beacon is bound to.
    /// @param data The init data.
    /// @param salt The caller's salt.
    /// @return The proxy.
    function registryBeaconProxy(
        address registry,
        address authority,
        bytes32 beaconName,
        bytes calldata data,
        bytes32 salt
    ) external returns (address);

    /// The address `registryBeaconProxy` deploys to for the same arguments,
    /// on every chain.
    /// @param registry A config registry.
    /// @param authority The authority the name is bound under.
    /// @param beaconName The name the beacon is bound to.
    /// @param data The init data.
    /// @param salt The caller's salt.
    /// @return The proxy address.
    function predictRegistryBeaconProxyAddress(
        address registry,
        address authority,
        bytes32 beaconName,
        bytes calldata data,
        bytes32 salt
    ) external view returns (address);

    /// The beacon a registry beacon proxy being deployed by this factory
    /// adopts, read by its constructor. The zero address outside a deploy.
    /// @return The beacon.
    function pendingBeacon() external view returns (address);
}
