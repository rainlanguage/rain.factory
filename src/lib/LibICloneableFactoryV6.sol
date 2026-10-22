// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {
    ICloneableFactoryV6,
    ICLONEABLE_FACTORY_V6_REGISTRY_BEACON_PROXY_DOMAIN
} from "../interface/ICloneableFactoryV6.sol";
import {LibICloneableFactoryV5} from "./LibICloneableFactoryV5.sol";
import {REGISTRY_BEACON_PROXY_CREATION_CODE} from "../generated/RegistryBeaconProxy.sol";

/// The read a registry beacon proxy resolves its beacon through: rain-deploy's
/// `IConfigRegistryV3.getV3`.
interface IRegistryBeaconSourceV1 {
    function getV3(address authority, bytes32 name) external view returns (bytes memory, uint256);
}

/// Thrown when a beacon binding is not exactly `abi.encode(beacon)`.
/// @param registry The registry read.
/// @param authority The authority the name is bound under.
/// @param beaconName The name read.
error NonCanonicalBeaconBinding(address registry, address authority, bytes32 beaconName);

/// @title LibICloneableFactoryV6
/// @notice The `ICloneableFactoryV6` additions to `LibICloneableFactoryV5`,
/// for a factory that implements both.
library LibICloneableFactoryV6 {
    /// The CREATE2 salt of a registry beacon proxy. The registry, authority and
    /// name are its constructor arguments, so the creation code commits to them.
    /// @param data The init data.
    /// @param salt The caller's salt.
    /// @return The derived salt.
    function effectiveRegistryBeaconProxySalt(bytes memory data, bytes32 salt) internal pure returns (bytes32) {
        return keccak256(abi.encode(ICLONEABLE_FACTORY_V6_REGISTRY_BEACON_PROXY_DOMAIN, salt, keccak256(data)));
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
        (bytes memory value,) = IRegistryBeaconSourceV1(registry).getV3(authority, beaconName);
        if (value.length != 0x20) {
            revert NonCanonicalBeaconBinding(registry, authority, beaconName);
        }
        uint256 word = abi.decode(value, (uint256));
        if (word >> 160 != 0) {
            revert NonCanonicalBeaconBinding(registry, authority, beaconName);
        }
        return address(uint160(word));
    }

    /// `ICloneableFactoryV6.registryBeaconProxy`.
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
        emit ICloneableFactoryV6.NewRegistryBeaconProxy(
            msg.sender, registry, authority, beaconName, beacon, proxy, salt, data
        );
        LibICloneableFactoryV5.initializeChild(proxy, data);
        return proxy;
    }

    /// `ICloneableFactoryV6.predictRegistryBeaconProxyAddress`.
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
}
