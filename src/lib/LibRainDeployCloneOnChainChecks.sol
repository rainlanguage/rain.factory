// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.17.0/src/Vm.sol";
import {StdConstants} from "forge-std-1.17.0/src/StdConstants.sol";
import {IERC5313} from "@openzeppelin-contracts-5.7.0/interfaces/IERC5313.sol";
import {IBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/IBeacon.sol";
import {
    DeployDeclaration,
    DeployMechanismHandler,
    DeploySuite
} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.29/src/lib/LibRainDeployDeclaration.sol";
import {LibRainDeploy} from "rain-deploy-0.1.29/src/lib/LibRainDeploy.sol";
import {ChainBeacon, LibRainDeployBeacon} from "./LibRainDeployBeacon.sol";
import {
    BEACON_PROXY_MECHANISM,
    BEACON_PROXY_PER_NETWORK_MECHANISM,
    CloneLayerConfig,
    LibRainDeployCloneMechanism,
    REGISTRY_BEACON_PROXY_MECHANISM
} from "./LibRainDeployCloneMechanism.sol";
import {LibRainDeployExtendedNetworks} from "./LibRainDeployExtendedNetworks.sol";
import {ResolvedBeacon} from "./LibRainDeployBeaconResolution.sol";
import {LibRainDeployRegistryBeaconProxy} from "./LibRainDeployRegistryBeaconProxy.sol";

/// @param suite The beacon proxy suite.
/// @param network The network.
/// @param beacon The proxy's beacon.
error BeaconProxyBeaconUndeclared(string suite, string network, address beacon);

/// @param suite The suite named.
error BeaconSuiteNotReleased(string suite);

/// @param chainId The beacon's network.
/// @param beaconIndex The beacon's index in the beacon config.
error BeaconNamedTwice(uint256 chainId, uint256 beaconIndex);

/// @param chainId The beacon's network.
/// @param beaconIndex The beacon's index in the beacon config.
error BeaconUnnamed(uint256 chainId, uint256 beaconIndex);

/// @param chainId The beacon's network.
/// @param beaconIndex The beacon's index in the beacon config.
/// @param seated The `owner()` answer, raw.
error BeaconSeatedOwner(uint256 chainId, uint256 beaconIndex, bytes seated);

/// @param chainId The beacon's network.
/// @param beaconIndex The beacon's index in the beacon config.
/// @param seated The `implementation()` answer, raw.
error BeaconSeatedImplementation(uint256 chainId, uint256 beaconIndex, bytes seated);

/// @param suite The suite deployed.
/// @param snapshotId The snapshot that failed to restore.
error BeaconSnapshotRevertFailed(string suite, uint256 snapshotId);

/// @param chainId The beacon's network.
/// @param beaconIndex The beacon's index in the beacon config.
/// @param state The state index, as `LibRainDeployBeacon.stateAt` takes it.
error BeaconOwnedByDeployKey(uint256 chainId, uint256 beaconIndex, uint256 state);

/// @param chainId The proxy's network.
/// @param beacon The registry beacon proxy's beacon.
error RegistryBeaconOwnedByDeployKey(uint256 chainId, address beacon);

/// @param ownerAnswered Whether `owner()` returned.
/// @param owner The `owner()` answer, raw.
/// @param implementationAnswered Whether `implementation()` returned.
/// @param implementation The `implementation()` answer, raw.
struct BeaconProbe {
    bool ownerAnswered;
    bytes owner;
    bool implementationAnswered;
    bytes implementation;
}

/// @title LibRainDeployCloneOnChainChecks
/// @notice The clone and beacon proxy handlers' `checkOnChain` and `checkBroadcastSeat`.
library LibRainDeployCloneOnChainChecks {
    function isBeaconId(bytes32 id) internal pure returns (bool) {
        return id == BEACON_PROXY_MECHANISM || id == BEACON_PROXY_PER_NETWORK_MECHANISM;
    }

    function beacons(DeployDeclaration memory d) internal pure returns (ChainBeacon[] memory) {
        return LibRainDeployCloneMechanism.layerConfig(d).beacons;
    }

    /// @return A copy of the release `name` keys with its recorded networks and the networks among `d.networks` its
    /// candidate takes it to; `d.released` is not changed.
    function released(DeployDeclaration memory d, string memory name) internal view returns (DeploySuite memory) {
        for (uint256 i = 0; i < d.released.length; i++) {
            if (keccak256(bytes(d.released[i].suite)) == keccak256(bytes(name))) {
                DeploySuite memory copy = abi.decode(abi.encode(d.released[i]), (DeploySuite));
                handlerOf(d, copy).addRecordedNetworks(d, copy);
                LibRainDeployDeclaration.addCandidateNetworks(
                    d, copy, LibRainDeploy.networkChainIds(LibRainDeploy.declaredNetworkConfigs(d.networks))
                );
                return copy;
            }
        }
        revert BeaconSuiteNotReleased(name);
    }

    function handlerOf(DeployDeclaration memory d, DeploySuite memory suite)
        internal
        pure
        returns (DeployMechanismHandler memory)
    {
        return LibRainDeployDeclaration.mechanismOf(d, suite);
    }

    function seatsOther(bool answered, bytes memory answer, address expected) internal pure returns (bool) {
        return answered && answer.length != 0 && keccak256(answer) != keccak256(abi.encode(expected));
    }

    /// `suite` deployed locally under `chainId` in a reverted snapshot: `beacon`'s raw `owner()` and
    /// `implementation()` answers.
    function probeBeacon(DeployDeclaration memory d, DeploySuite memory suite, address beacon, uint256 chainId)
        internal
        returns (BeaconProbe memory)
    {
        Vm vm = StdConstants.VM;
        uint256 snapshotId = vm.snapshotState();
        vm.chainId(chainId);
        handlerOf(d, suite).deployLocallyOnChain(d, vm, suite);
        // slither-disable-next-line low-level-calls
        (bool ownerAnswered, bytes memory owner) = beacon.staticcall(abi.encodeCall(IERC5313.owner, ()));
        // slither-disable-next-line low-level-calls
        (bool implementationAnswered, bytes memory implementation) =
            beacon.staticcall(abi.encodeCall(IBeacon.implementation, ()));
        BeaconProbe memory probe = BeaconProbe({
            ownerAnswered: ownerAnswered,
            owner: owner,
            implementationAnswered: implementationAnswered,
            implementation: implementation
        });
        if (!vm.revertToState(snapshotId)) {
            revert BeaconSnapshotRevertFailed(suite.suite, snapshotId);
        }
        return probe;
    }

    /// Beacon proxy suites: refuses `BeaconProxyBeaconUndeclared` when no beacon `checkNetworks` resolved on
    /// `chainId` is the proxy's beacon. Registry beacon proxy suites: `checkBeacon` on `network`.
    function checkOnChain(
        DeployDeclaration memory d,
        DeploySuite memory suite,
        string memory network,
        uint256 chainId,
        address
    ) internal view {
        bytes32 id = LibRainDeployDeclaration.mechanismIdOf(suite);
        if (id == REGISTRY_BEACON_PROXY_MECHANISM) {
            LibRainDeployRegistryBeaconProxy.checkBeacon(
                network, LibRainDeployCloneMechanism.registryBeaconProxyTarget(suite)
            );
            return;
        }
        if (!isBeaconId(id)) {
            return;
        }
        address proxyBeacon = LibRainDeployCloneMechanism.beacon(suite, chainId);
        ResolvedBeacon[] memory resolved = LibRainDeployCloneMechanism.layerConfig(d).resolvedBeacons;
        for (uint256 i = 0; i < resolved.length; i++) {
            if (resolved[i].chainId == chainId && resolved[i].beacon.beacon == proxyBeacon) {
                return;
            }
        }
        revert BeaconProxyBeaconUndeclared(suite.suite, network, proxyBeacon);
    }

    /// Every release's declared extended networks are exactly the ones its record under the config's root holds, else
    /// `ExtendedNetworksUnrecorded`.
    function checkDeclarationPerNetwork(DeployDeclaration memory d) internal view {
        CloneLayerConfig memory config = LibRainDeployCloneMechanism.layerConfig(d);
        for (uint256 i = 0; i < config.extended.length; i++) {
            LibRainDeployExtendedNetworks.checkExtendedNetworksRecorded(
                StdConstants.VM, config.extendedNetworksRoot, config.extended[i].suite, config.extended[i].networks
            );
        }
    }

    /// Beacon proxy suites: refuses `BeaconOwnedByDeployKey` when any state of any beacon in the handler's config is
    /// owned by `deployer`. Registry beacon proxy suites: refuses `RegistryBeaconOwnedByDeployKey` when `deployer`
    /// owns the proxy's beacon.
    function checkBroadcastSeat(DeployDeclaration memory d, DeploySuite memory suite, uint256 chainId, address deployer)
        internal
        view
    {
        bytes32 id = LibRainDeployDeclaration.mechanismIdOf(suite);
        if (id == REGISTRY_BEACON_PROXY_MECHANISM) {
            address beacon = LibRainDeployCloneMechanism.registryBeaconProxyTarget(suite).beacon;
            if (IERC5313(beacon).owner() == deployer) {
                revert RegistryBeaconOwnedByDeployKey(chainId, beacon);
            }
            return;
        }
        if (!isBeaconId(id)) {
            return;
        }
        ChainBeacon[] memory chainBeacons = beacons(d);
        for (uint256 beaconIndex = 0; beaconIndex < chainBeacons.length; beaconIndex++) {
            for (uint256 state = 0; state <= chainBeacons[beaconIndex].beacon.transitions.length; state++) {
                if (LibRainDeployBeacon.stateAt(chainBeacons[beaconIndex].beacon, state).owner == deployer) {
                    revert BeaconOwnedByDeployKey(chainBeacons[beaconIndex].chainId, beaconIndex, state);
                }
            }
        }
    }
}
