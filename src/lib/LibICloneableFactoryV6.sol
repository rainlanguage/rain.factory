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

/// @dev Transient slot holding the beacon of the registry beacon proxy being
/// deployed, for its constructor to read back.
bytes32 constant PENDING_BEACON_SLOT = bytes32(uint256(keccak256("rain.factory.pendingbeacon")) - 1);

/// @title LibICloneableFactoryV6
/// @notice The `ICloneableFactoryV6` additions to `LibICloneableFactoryV5`,
/// for a factory that implements both.
library LibICloneableFactoryV6 {
    /// The CREATE2 salt of a registry beacon proxy: everything that decides
    /// what it is, and nothing that differs between chains.
    /// @param registry The registry.
    /// @param authority The authority.
    /// @param beaconName The beacon's name.
    /// @param data The init data.
    /// @param salt The caller's salt.
    /// @return The derived salt.
    function effectiveRegistryBeaconProxySalt(
        address registry,
        address authority,
        bytes32 beaconName,
        bytes memory data,
        bytes32 salt
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ICLONEABLE_FACTORY_V6_REGISTRY_BEACON_PROXY_DOMAIN,
                registry,
                authority,
                beaconName,
                salt,
                keccak256(data)
            )
        );
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

    /// `ICloneableFactoryV6.pendingBeacon`.
    /// @return beacon The beacon in the transient slot.
    function pendingBeacon() internal view returns (address beacon) {
        bytes32 slot = PENDING_BEACON_SLOT;
        assembly ("memory-safe") {
            beacon := tload(slot)
        }
    }

    /// @param beacon The beacon to put in the transient slot.
    function setPendingBeacon(address beacon) private {
        bytes32 slot = PENDING_BEACON_SLOT;
        assembly ("memory-safe") {
            tstore(slot, beacon)
        }
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
        setPendingBeacon(beacon);
        address proxy = LibICloneableFactoryV5.deployChild(
            REGISTRY_BEACON_PROXY_CREATION_CODE,
            effectiveRegistryBeaconProxySalt(registry, authority, beaconName, data, salt)
        );
        setPendingBeacon(address(0));
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
            effectiveRegistryBeaconProxySalt(registry, authority, beaconName, data, salt),
            keccak256(REGISTRY_BEACON_PROXY_CREATION_CODE)
        );
    }
}
