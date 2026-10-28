// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {RainDeployBroadcast} from "rain-deploy-0.1.27/src/abstract/RainDeployBroadcast.sol";
import {ExampleCloneDeploys} from "../abstract/ExampleCloneDeploys.sol";
import {ExternalDeploySuites} from "../abstract/ExternalDeploySuites.sol";

/// @title ExampleCloneDeploy
/// @notice The example clone declaration as a broadcast script, with no mechanism override.
contract ExampleCloneDeploy is ExampleCloneDeploys, ExternalDeploySuites, RainDeployBroadcast {}
