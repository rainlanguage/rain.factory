// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ExampleCloneDeploys} from "../abstract/ExampleCloneDeploys.sol";
import {ExternalDeployBroadcast} from "../abstract/ExternalDeployBroadcast.sol";

/// @title ExampleCloneDeploy
/// @notice The example clone declaration as a broadcast script, with no mechanism override and its broadcast exposed.
contract ExampleCloneDeploy is ExampleCloneDeploys, ExternalDeployBroadcast {}
