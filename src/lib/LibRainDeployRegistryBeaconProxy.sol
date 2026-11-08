// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.17.0/src/Vm.sol";
import {console2} from "forge-std-1.17.0/src/console2.sol";
import {IERC5313} from "@openzeppelin-contracts-5.7.0/interfaces/IERC5313.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/UpgradeableBeacon.sol";
import {ICloneableFactoryV7} from "../interface/ICloneableFactoryV7.sol";
import {LibICloneableFactoryV7} from "./LibICloneableFactoryV7.sol";

import {DeployDependency} from "rain-deploy-0.1.30/src/lib/LibRainDeploy.sol";
import {ConfigRegistry} from "rain-deploy-0.1.30/src/concrete/ConfigRegistry.sol";
import {IConfigRegistryV5} from "rain-deploy-0.1.30/src/interface/IConfigRegistryV5.sol";

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
    /// The beacon the binding MUST resolve to at broadcast. Not committed to by the address.
    address beacon;
    bytes data;
    bytes32 salt;
    /// MUST include the factory, the registry and the beacon.
    DeployDependency[] dependencies;
    /// The proxy's runtime code, generated into `src/generated/` and checked by `Git is clean`.
    bytes runtimeCode;
}

/// The factory call a registry beacon proxy suite's `mechanismData` carries.
struct RegistryBeaconProxyParams {
    address factory;
    address registry;
    address authority;
    bytes32 beaconName;
    address beacon;
    bytes data;
    bytes32 salt;
}

/// @title LibRainDeployRegistryBeaconProxy
/// @notice The REGISTRY_BEACON_PROXY mechanism.
library LibRainDeployRegistryBeaconProxy {
    /// Thrown when the factory on a network does not derive the address this package derives.
    /// @param network The network whose factory was read.
    /// @param factory The factory that was asked.
    /// @param expected The address this package derives.
    /// @param predicted The address the factory says it would deploy to.
    error RegistryBeaconProxyFactoryPredictionMismatch(
        string network, address factory, address expected, address predicted
    );

    /// Thrown when the binding on a network does not resolve to the declared beacon.
    /// @param network The network whose registry was read.
    /// @param expected The declared beacon.
    /// @param resolved The beacon the binding resolves to.
    error RegistryBeaconProxyBeaconMismatch(string network, address expected, address resolved);

    /// Thrown when a registry beacon proxy deployed on the fork answers `owner()` with the deploy key.
    /// @param network The network.
    /// @param proxy The proxy.
    error RegistryBeaconProxySeatsDeployKey(string network, address proxy);

    /// Thrown when `registryBeaconProxyRuntimeCode` cannot construct the beacon locally.
    /// @param beacon The beacon address.
    /// @param implementation The implementation it was to serve.
    error RegistryBeaconProxyBeaconConstructionFailed(address beacon, address implementation);

    /// Thrown when `registryBeaconProxyRuntimeCode` cannot deploy the proxy locally.
    /// @param registry The registry.
    /// @param authority The authority.
    /// @param beaconName The beacon's name.
    error RegistryBeaconProxyLocalDeployFailed(address registry, address authority, bytes32 beaconName);

    /// Thrown when `registryBeaconProxyRuntimeCode` cannot revert the local state it wrote.
    /// @param state The state snapshot.
    error RegistryBeaconProxyLocalStateNotReverted(uint256 state);

    /// @param params The proxy.
    /// @return Its creation code.
    function registryBeaconProxyCreationCode(RegistryBeaconProxyParams memory params)
        internal
        pure
        returns (bytes memory)
    {
        return LibICloneableFactoryV7.registryBeaconProxyCreationCode(
            params.registry, params.authority, params.beaconName
        );
    }

    /// The proxy's runtime code, for a repo's `script/Build.sol` to generate into `src/generated/`. Etches a
    /// `ConfigRegistry` at `params.registry` binding `beaconName` under `authority` to an `UpgradeableBeacon` at
    /// `params.beacon` serving `implementation`, deploys the creation code, then reverts the local state.
    /// @param vm The Vm instance to etch with.
    /// @param params The proxy.
    /// @param implementation The implementation the beacon serves.
    /// @param implementationCode The implementation's runtime code.
    /// @return The proxy's runtime code.
    function registryBeaconProxyRuntimeCode(
        Vm vm,
        RegistryBeaconProxyParams memory params,
        address implementation,
        bytes memory implementationCode
    ) internal returns (bytes memory) {
        uint256 state = vm.snapshotState();
        vm.etch(params.registry, address(new ConfigRegistry()).code);
        vm.etch(implementation, implementationCode);
        // slither-disable-next-line too-many-digits
        vm.etch(
            params.beacon, bytes.concat(type(UpgradeableBeacon).creationCode, abi.encode(implementation, params.beacon))
        );
        // slither-disable-next-line low-level-calls
        (bool constructed, bytes memory beaconCode) = params.beacon.call("");
        if (!constructed) {
            revert RegistryBeaconProxyBeaconConstructionFailed(params.beacon, implementation);
        }
        vm.etch(params.beacon, beaconCode);
        uint256 moment = vm.getBlockTimestamp();
        // slither-disable-next-line unused-return
        try IConfigRegistryV5(params.registry).getV5(params.authority, params.beaconName) returns (
            bytes memory, uint256 registeredAt, bytes32
        ) {
            if (registeredAt > moment) {
                moment = registeredAt;
            }
        } catch {}
        vm.warp(moment + 1);
        vm.prank(params.authority);
        IConfigRegistryV5(params.registry)
            .registerV5(params.authority, params.beaconName, "address", abi.encode(params.beacon), "");
        bytes memory creationCode = registryBeaconProxyCreationCode(params);
        address proxy;
        assembly ("memory-safe") {
            proxy := create(0, add(creationCode, 0x20), mload(creationCode))
        }
        if (proxy == address(0)) {
            revert RegistryBeaconProxyLocalDeployFailed(params.registry, params.authority, params.beaconName);
        }
        bytes memory runtimeCode = proxy.code;
        if (!vm.revertToState(state)) {
            revert RegistryBeaconProxyLocalStateNotReverted(state);
        }
        return runtimeCode;
    }

    /// Refuses `RegistryBeaconProxyBeaconMismatch` unless the binding on the current network resolves to the
    /// declared beacon.
    /// @param network The network.
    /// @param params The proxy.
    function checkBeacon(string memory network, RegistryBeaconProxyParams memory params) internal view {
        address resolved = LibICloneableFactoryV7.resolveBeacon(params.registry, params.authority, params.beaconName);
        if (resolved != params.beacon) {
            revert RegistryBeaconProxyBeaconMismatch(network, params.beacon, resolved);
        }
    }

    /// @param params The proxy.
    /// @return The address it lands at.
    function registryBeaconProxyDeployedAddress(RegistryBeaconProxyParams memory params)
        internal
        pure
        returns (address)
    {
        return LibICloneableFactoryV7.predictRegistryBeaconProxyAddress(
            params.factory, params.registry, params.authority, params.beaconName, params.data, params.salt
        );
    }

    /// The REGISTRY_BEACON_PROXY mechanism as a `LibRainDeploy.deployStepToNetworks` step.
    /// @param vm The Vm instance to broadcast with.
    /// @param network The network being deployed to.
    /// @param deployer The deployer address to broadcast as.
    /// @param paramsData The `abi.encode`d `RegistryBeaconProxyParams`.
    /// @return The address the factory deployed the proxy to.
    function registryBeaconProxyDeployStep(Vm vm, string memory network, address deployer, bytes memory paramsData)
        internal
        returns (address)
    {
        RegistryBeaconProxyParams memory params = abi.decode(paramsData, (RegistryBeaconProxyParams));

        console2.log(" - Registry Beacon Proxy Factory:", params.factory);
        checkBeacon(network, params);
        address expectedAddress = registryBeaconProxyDeployedAddress(params);
        address factoryPredictedAddress = ICloneableFactoryV7(params.factory)
            .predictRegistryBeaconProxyAddress(
                params.registry, params.authority, params.beaconName, params.data, params.salt
            );
        if (factoryPredictedAddress != expectedAddress) {
            revert RegistryBeaconProxyFactoryPredictionMismatch(
                network, params.factory, expectedAddress, factoryPredictedAddress
            );
        }

        vm.startBroadcast(deployer);
        address proxy = ICloneableFactoryV7(params.factory)
            .registryBeaconProxy(params.registry, params.authority, params.beaconName, params.data, params.salt);
        vm.stopBroadcast();

        // slither-disable-next-line low-level-calls
        (bool answered, bytes memory owner) = proxy.staticcall(abi.encodeCall(IERC5313.owner, ()));
        if (answered && owner.length >= 0x20 && address(uint160(abi.decode(owner, (uint256)))) == deployer) {
            revert RegistryBeaconProxySeatsDeployKey(network, proxy);
        }
        return proxy;
    }
}
