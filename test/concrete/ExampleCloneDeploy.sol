// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ExampleCloneDeploys} from "../abstract/ExampleCloneDeploys.sol";
import {ExternalDeployBroadcast} from "../abstract/ExternalDeployBroadcast.sol";
import {DeployDeclaration, RainDeploySuitesBase} from "rain-deploy-0.1.41/src/abstract/RainDeploySuitesBase.sol";
import {DeployDependency} from "rain-deploy-0.1.41/src/lib/LibRainDeploy.sol";
import {LibExternalDeployments} from "../lib/LibExternalDeployments.sol";

/// @title ExampleCloneDeploy
/// @notice The example clone declaration as a broadcast script, with no mechanism override and its broadcast exposed,
/// also declaring each external deployment its caller adds.
contract ExampleCloneDeploy is ExampleCloneDeploys, ExternalDeployBroadcast {
    DeployDependency[] internal sExternalDeployments;

    /// Declares `deployment` an external deployment of every later `declaration()`.
    function addExternalDeployment(DeployDependency memory deployment) external {
        sExternalDeployments.push(deployment);
    }

    function declaration()
        internal
        view
        override(ExampleCloneDeploys, RainDeploySuitesBase)
        returns (DeployDeclaration memory)
    {
        DeployDeclaration memory d = super.declaration();
        LibExternalDeployments.add(d, sExternalDeployments);
        return d;
    }
}
