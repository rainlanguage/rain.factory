// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {
    ICloneableFactoryV7,
    ICLONEABLE_FACTORY_V7_REGISTRY_BEACON_PROXY_DOMAIN
} from "../interface/ICloneableFactoryV7.sol";
import {LibICloneableFactoryV5} from "./LibICloneableFactoryV5.sol";
import {REGISTRY_BEACON_PROXY_CREATION_CODE} from "../generated/RegistryBeaconProxy.sol";
import {IConfigRegistryV5} from "rain-deploy-0.1.29/src/interface/IConfigRegistryV5.sol";

/// @dev The value type hash a beacon binding must carry.
bytes32 constant BEACON_BINDING_VALUE_TYPE_HASH = keccak256("address");

/// Thrown when a beacon binding is not typed `address`.
/// @param registry The registry read.
/// @param authority The authority the name is bound under.
/// @param beaconName The name read.
/// @param valueTypeHash The type hash the binding carries.
error BeaconBindingTypeMismatch(address registry, address authority, bytes32 beaconName, bytes32 valueTypeHash);

/// Thrown when a beacon binding is not exactly `abi.encode(beacon)`.
/// @param registry The registry read.
/// @param authority The authority the name is bound under.
/// @param beaconName The name read.
error NonCanonicalBeaconBinding(address registry, address authority, bytes32 beaconName);

/// @title LibICloneableFactoryV7
/// @notice The `ICloneableFactoryV7` additions to `LibICloneableFactoryV5`,
/// for a factory that implements both.
library LibICloneableFactoryV7 {
    /// The CREATE2 salt of a registry beacon proxy. The registry, authority and
    /// name are its constructor arguments, so the creation code commits to them.
    /// @param data The init data.
    /// @param salt The caller's salt.
    /// @return The derived salt.
    function effectiveRegistryBeaconProxySalt(bytes memory data, bytes32 salt) internal pure returns (bytes32) {
        return keccak256(abi.encode(ICLONEABLE_FACTORY_V7_REGISTRY_BEACON_PROXY_DOMAIN, salt, keccak256(data)));
    }

    /// The creation code of the registry beacon proxy for a binding.
    /// @param registry The registry.
    /// @param authority The authority.
    /// @param beaconName The beacon's name.
    /// @return The creation code with its constructor arguments.
    function registryBeaconProxyCreationCode(address registry, address authority, bytes32 beaconName)
        internal
        pure
        returns (bytes memory)
    {
        return bytes.concat(REGISTRY_BEACON_PROXY_CREATION_CODE, abi.encode(registry, authority, beaconName));
    }

    /// The beacon `beaconName` under `authority` is bound to in `registry`.
    /// @param registry The registry.
    /// @param authority The authority.
    /// @param beaconName The beacon's name.
    /// @return The beacon.
    function resolveBeacon(address registry, address authority, bytes32 beaconName) internal view returns (address) {
        // When the binding was written does not matter here.
        //slither-disable-next-line unused-return
        (bytes memory value,, bytes32 valueTypeHash) = IConfigRegistryV5(registry).getV5(authority, beaconName);
        if (valueTypeHash != BEACON_BINDING_VALUE_TYPE_HASH) {
            revert BeaconBindingTypeMismatch(registry, authority, beaconName, valueTypeHash);
        }
        if (value.length != 0x20) {
            revert NonCanonicalBeaconBinding(registry, authority, beaconName);
        }
        uint256 word = abi.decode(value, (uint256));
        if (word >> 160 != 0) {
            revert NonCanonicalBeaconBinding(registry, authority, beaconName);
        }
        // `word >> 160 == 0`, so the cast drops nothing.
        //forge-lint: disable-next-line(unsafe-typecast)
        return address(uint160(word));
    }

    /// `ICloneableFactoryV7.registryBeaconProxy`.
    function registryBeaconProxy(
        address registry,
        address authority,
        bytes32 beaconName,
        bytes memory data,
        bytes32 salt
    ) internal returns (address) {
        address beacon = resolveBeacon(registry, authority, beaconName);
        LibICloneableFactoryV5.checkBeacon(beacon);
        address proxy = LibICloneableFactoryV5.deployChild(
            registryBeaconProxyCreationCode(registry, authority, beaconName),
            effectiveRegistryBeaconProxySalt(data, salt)
        );
        emit ICloneableFactoryV7.NewRegistryBeaconProxy(
            msg.sender, registry, authority, beaconName, beacon, proxy, salt, data
        );
        LibICloneableFactoryV5.initializeChild(proxy, data);
        return proxy;
    }

    /// `ICloneableFactoryV7.predictRegistryBeaconProxyAddress`.
    function predictRegistryBeaconProxyAddress(
        address registry,
        address authority,
        bytes32 beaconName,
        bytes memory data,
        bytes32 salt
    ) internal view returns (address) {
        return LibICloneableFactoryV5.predictCreate2Address(
            address(this),
            effectiveRegistryBeaconProxySalt(data, salt),
            keccak256(registryBeaconProxyCreationCode(registry, authority, beaconName))
        );
    }

    /// `ICloneableFactoryV7.predictRegistryBeaconProxyAddress` as `factory` answers it.
    function predictRegistryBeaconProxyAddress(
        address factory,
        address registry,
        address authority,
        bytes32 beaconName,
        bytes memory data,
        bytes32 salt
    ) internal pure returns (address) {
        return LibICloneableFactoryV5.predictCreate2Address(
            factory,
            effectiveRegistryBeaconProxySalt(data, salt),
            keccak256(registryBeaconProxyCreationCode(registry, authority, beaconName))
        );
    }
}
