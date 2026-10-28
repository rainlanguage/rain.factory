// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {DeployDeclaration, DeploySuite} from "rain-deploy-0.1.27/src/abstract/RainDeploySuitesBase.sol";

/// @title LibRainDeployCloneOnChainChecks
/// @notice The clone and beacon proxy handlers' `checkOnChain` and `checkBroadcastSeat`.
library LibRainDeployCloneOnChainChecks {
    function checkOnChain(DeployDeclaration memory, DeploySuite memory, string memory, uint256, address)
        internal
        view
    {}

    function checkBroadcastSeat(DeployDeclaration memory, DeploySuite memory, uint256, address) internal view {}
}
