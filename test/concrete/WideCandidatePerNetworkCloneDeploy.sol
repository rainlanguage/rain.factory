// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {DeployCandidate, DeployDeclaration} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeploy} from "rain-deploy-0.1.29/src/lib/LibRainDeploy.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.29/src/lib/LibRainDeployDeclaration.sol";
import {LibRainDeployZoltuMechanism} from "rain-deploy-0.1.29/src/lib/LibRainDeployZoltuMechanism.sol";
import {LibRainDeployCloneMechanism} from "../../src/lib/LibRainDeployCloneMechanism.sol";
import {ExternalDeployBroadcast} from "../abstract/ExternalDeployBroadcast.sol";
import {perNetworkCloneChainIds, perNetworkCloneNetworks} from "../abstract/PerNetworkCloneDeploys.sol";
import {upgradedPerNetworkClone} from "../abstract/UpgradedPerNetworkCloneDeploys.sol";

/// @title WideCandidatePerNetworkCloneDeploy
/// @notice A broadcast whose hand-written candidate declares Arbitrum One and Polygon while the repo supports Arbitrum
/// One alone.
contract WideCandidatePerNetworkCloneDeploy is ExternalDeployBroadcast {
    function declaration() internal view override returns (DeployDeclaration memory) {
        DeployDeclaration memory d;
        LibRainDeployDeclaration.extend(d);
        string[] memory networks = new string[](1);
        networks[0] = LibRainDeploy.ARBITRUM_ONE;
        LibRainDeployDeclaration.setNetworks(d, networks);
        LibRainDeployZoltuMechanism.extend(d);
        LibRainDeployCloneMechanism.extend(d);
        DeployCandidate[] memory candidates = new DeployCandidate[](1);
        candidates[0] = LibRainDeployCloneMechanism.cloneCandidate(upgradedPerNetworkClone(), perNetworkCloneChainIds());
        candidates[0].snapshot.networks = perNetworkCloneNetworks();
        LibRainDeployDeclaration.addCandidates(d, candidates);
        return d;
    }
}
