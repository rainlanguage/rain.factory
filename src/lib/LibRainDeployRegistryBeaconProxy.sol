// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.17.0/src/Vm.sol";
import {console2} from "forge-std-1.17.0/src/console2.sol";
import {IERC5313} from "@openzeppelin-contracts-5.7.0/interfaces/IERC5313.sol";
import {ICloneableFactoryV7} from "../interface/ICloneableFactoryV7.sol";
import {LibICloneableFactoryV7} from "./LibICloneableFactoryV7.sol";

import {DeployDependency} from "rain-deploy-0.1.29/src/lib/LibRainDeploy.sol";

/// @dev The artifact path a registry beacon proxy suite carries.
string constant REGISTRY_BEACON_PROXY_ARTIFACT_PATH = "rain-factory/RegistryBeaconProxy.sol:RegistryBeaconProxy";

string constant REGISTRY_BEACON_PROXY_UNANCHORABLE_REASON = "A RegistryBeaconProxy, deployed by the factory from "
    "rain-factory's generated creation code with the registry, authority and beacon name as its constructor "
    "arguments. Its source is not compiled here, so there is no artifact to anchor it to; the beacon the binding "
    "resolves to, and each implementation it serves, are the anchored contracts.";

/// One contract a repo deploys as a registry beacon proxy.
/// The address commits to the registry, authority and beacon name, not to the beacon they resolve to or the
/// implementation that runs `initialize(data)`. Every beacon the binding resolves to while the proxy is
/// undeployed MUST give the same `initialize(data)` result, or revert.
struct RegistryBeaconProxyDeploy {
    string suite;
    /// The `ICloneableFactoryV7` that deploys the proxy.
    address factory;
    address registry;
    address authority;
    bytes32 beaconName;
    bytes data;
    bytes32 salt;
    /// MUST include the factory and the registry.
    DeployDependency[] dependencies;
    /// The proxy's runtime code, generated into `src/generated/` and checked by `Git is clean`.
    bytes runtimeCode;
}

/// The factory call a registry beacon proxy suite's `mechanismData` carries.
struct RegistryBeaconProxyTarget {
    address factory;
    address registry;
    address authority;
    bytes32 beaconName;
    bytes data;
    bytes32 salt;
}

/// @title LibRainDeployRegistryBeaconProxy
/// @notice The REGISTRY_BEACON_PROXY mechanism.
library LibRainDeployRegistryBeaconProxy {
    /// Thrown when the factory on a network does not derive the address this package derives.
    error RegistryBeaconProxyFactoryPredictionMismatch(
        string network, address factory, address expected, address predicted
    );

    /// Thrown when a registry beacon proxy deployed on the fork answers `owner()` with the deploy key.
    error RegistryBeaconProxySeatsDeployKey(string network, address proxy);

    /// Thrown when `registryBeaconProxyRuntimeCode` cannot deploy the proxy locally.
    error RegistryBeaconProxyLocalDeployFailed(address registry, address authority, bytes32 beaconName);

    /// Thrown when `registryBeaconProxyRuntimeCode` cannot revert the local state it wrote.
    error RegistryBeaconProxyLocalStateNotReverted(uint256 state);

    /// @param target The proxy.
    /// @return Its creation code.
    function registryBeaconProxyCreationCode(RegistryBeaconProxyTarget memory target)
        internal
        pure
        returns (bytes memory)
    {
        return LibICloneableFactoryV7.registryBeaconProxyCreationCode(
            target.registry, target.authority, target.beaconName
        );
    }

    /// The proxy's runtime code, for a repo's `script/Build.sol` to generate into `src/generated/`. Deploys the
    /// creation code against the fork's registry, so the binding MUST resolve there. The local state is reverted.
    /// @param vm The Vm instance.
    /// @param target The proxy.
    /// @return The proxy's runtime code.
    function registryBeaconProxyRuntimeCode(Vm vm, RegistryBeaconProxyTarget memory target)
        internal
        returns (bytes memory)
    {
        uint256 state = vm.snapshotState();
        bytes memory creationCode = registryBeaconProxyCreationCode(target);
        address proxy;
        assembly ("memory-safe") {
            proxy := create(0, add(creationCode, 0x20), mload(creationCode))
        }
        if (proxy == address(0)) {
            revert RegistryBeaconProxyLocalDeployFailed(target.registry, target.authority, target.beaconName);
        }
        bytes memory runtimeCode = proxy.code;
        if (!vm.revertToState(state)) {
            revert RegistryBeaconProxyLocalStateNotReverted(state);
        }
        return runtimeCode;
    }

    /// @param target The proxy.
    /// @return The address it lands at.
    function registryBeaconProxyDeployedAddress(RegistryBeaconProxyTarget memory target)
        internal
        pure
        returns (address)
    {
        return LibICloneableFactoryV7.predictRegistryBeaconProxyAddress(
            target.factory, target.registry, target.authority, target.beaconName, target.data, target.salt
        );
    }

    /// The REGISTRY_BEACON_PROXY mechanism as a `LibRainDeploy.deployStepToNetworks` step.
    /// @param vm The Vm instance to broadcast with.
    /// @param network The network being deployed to.
    /// @param deployer The deployer address to broadcast as.
    /// @param targetData The `abi.encode`d `RegistryBeaconProxyTarget`.
    /// @return The address the factory deployed the proxy to.
    function registryBeaconProxyDeployStep(Vm vm, string memory network, address deployer, bytes memory targetData)
        internal
        returns (address)
    {
        RegistryBeaconProxyTarget memory target = abi.decode(targetData, (RegistryBeaconProxyTarget));

        console2.log(" - Registry Beacon Proxy Factory:", target.factory);
        address expectedAddress = registryBeaconProxyDeployedAddress(target);
        address factoryPredictedAddress = ICloneableFactoryV7(target.factory)
            .predictRegistryBeaconProxyAddress(
                target.registry, target.authority, target.beaconName, target.data, target.salt
            );
        if (factoryPredictedAddress != expectedAddress) {
            revert RegistryBeaconProxyFactoryPredictionMismatch(
                network, target.factory, expectedAddress, factoryPredictedAddress
            );
        }

        vm.startBroadcast(deployer);
        address proxy = ICloneableFactoryV7(target.factory)
            .registryBeaconProxy(target.registry, target.authority, target.beaconName, target.data, target.salt);
        vm.stopBroadcast();

        // slither-disable-next-line low-level-calls
        (bool answered, bytes memory owner) = proxy.staticcall(abi.encodeCall(IERC5313.owner, ()));
        if (answered && owner.length >= 0x20 && address(uint160(abi.decode(owner, (uint256)))) == deployer) {
            revert RegistryBeaconProxySeatsDeployKey(network, proxy);
        }
        return proxy;
    }
}
