// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {DeployCandidate, DeployDeclaration} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeploy} from "rain-deploy-0.1.29/src/lib/LibRainDeploy.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.29/src/lib/LibRainDeployDeclaration.sol";
import {CloneDeploy} from "../../src/lib/LibRainDeployClone.sol";
import {BeaconProxyDeploy} from "../../src/lib/LibRainDeployBeaconProxy.sol";
import {LibRainDeployCloneMechanism} from "../../src/lib/LibRainDeployCloneMechanism.sol";

/// @title LibCloneCandidates
/// @notice Clone and beacon proxy declarations as candidates for a declaration's networks.
library LibCloneCandidates {
    function chainIds(DeployDeclaration memory d) internal pure returns (uint256[] memory) {
        return LibRainDeploy.networkChainIds(LibRainDeploy.declaredNetworkConfigs(d.networks));
    }

    function addClones(DeployDeclaration memory d, CloneDeploy[] memory clones) internal view {
        uint256[] memory ids = chainIds(d);
        DeployCandidate[] memory candidates = new DeployCandidate[](clones.length);
        for (uint256 i = 0; i < clones.length; i++) {
            candidates[i] = LibRainDeployCloneMechanism.cloneCandidate(clones[i], ids);
        }
        LibRainDeployDeclaration.addCandidates(d, candidates);
    }

    function addBeaconProxies(DeployDeclaration memory d, BeaconProxyDeploy[] memory proxies) internal view {
        uint256[] memory ids = chainIds(d);
        DeployCandidate[] memory candidates = new DeployCandidate[](proxies.length);
        for (uint256 i = 0; i < proxies.length; i++) {
            candidates[i] = LibRainDeployCloneMechanism.beaconProxyCandidate(proxies[i], ids);
        }
        LibRainDeployDeclaration.addCandidates(d, candidates);
    }
}
