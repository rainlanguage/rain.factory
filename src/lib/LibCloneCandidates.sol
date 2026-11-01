// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {DeployCandidate, DeployDeclaration} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeploy} from "rain-deploy-0.1.29/src/lib/LibRainDeploy.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.29/src/lib/LibRainDeployDeclaration.sol";
import {CloneDeploy} from "./LibRainDeployClone.sol";
import {BeaconProxyDeploy} from "./LibRainDeployBeaconProxy.sol";
import {RegistryBeaconProxyDeploy} from "./LibRainDeployRegistryBeaconProxy.sol";
import {LibRainDeployCloneMechanism} from "./LibRainDeployCloneMechanism.sol";

/// Thrown when an empty clone or beacon proxy list is added to a declaration.
error NoFactoryDeploys();

/// @title LibCloneCandidates
/// @notice Clone and beacon proxy declarations as candidates for a declaration's networks.
library LibCloneCandidates {
    /// @param d The declaration.
    /// @return The chain id of every network in `d.networks`, in order.
    function chainIds(DeployDeclaration memory d) internal pure returns (uint256[] memory) {
        return LibRainDeploy.networkChainIds(LibRainDeploy.declaredNetworkConfigs(d.networks));
    }

    /// Adds a candidate per clone, built for `d.networks`. Refuses `NoFactoryDeploys` when empty.
    /// @param d The declaration.
    /// @param clones The clones.
    function addClones(DeployDeclaration memory d, CloneDeploy[] memory clones) internal view {
        if (clones.length == 0) {
            revert NoFactoryDeploys();
        }
        uint256[] memory ids = chainIds(d);
        DeployCandidate[] memory candidates = new DeployCandidate[](clones.length);
        for (uint256 i = 0; i < clones.length; i++) {
            candidates[i] = LibRainDeployCloneMechanism.cloneCandidate(clones[i], ids);
        }
        LibRainDeployDeclaration.addCandidates(d, candidates);
    }

    /// Adds a candidate per beacon proxy, built for `d.networks`. Refuses `NoFactoryDeploys` when
    /// empty.
    /// @param d The declaration.
    /// @param proxies The beacon proxies.
    function addBeaconProxies(DeployDeclaration memory d, BeaconProxyDeploy[] memory proxies) internal view {
        if (proxies.length == 0) {
            revert NoFactoryDeploys();
        }
        uint256[] memory ids = chainIds(d);
        DeployCandidate[] memory candidates = new DeployCandidate[](proxies.length);
        for (uint256 i = 0; i < proxies.length; i++) {
            candidates[i] = LibRainDeployCloneMechanism.beaconProxyCandidate(proxies[i], ids);
        }
        LibRainDeployDeclaration.addCandidates(d, candidates);
    }

    /// Adds a candidate per registry beacon proxy. Refuses `NoFactoryDeploys` when empty.
    /// @param d The declaration.
    /// @param proxies The registry beacon proxies.
    function addRegistryBeaconProxies(DeployDeclaration memory d, RegistryBeaconProxyDeploy[] memory proxies)
        internal
        pure
    {
        if (proxies.length == 0) {
            revert NoFactoryDeploys();
        }
        DeployCandidate[] memory candidates = new DeployCandidate[](proxies.length);
        for (uint256 i = 0; i < proxies.length; i++) {
            candidates[i] = LibRainDeployCloneMechanism.registryBeaconProxyCandidate(proxies[i]);
        }
        LibRainDeployDeclaration.addCandidates(d, candidates);
    }
}
