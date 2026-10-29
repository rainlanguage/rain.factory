// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {DeployDeclaration} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeploy} from "rain-deploy-0.1.29/src/lib/LibRainDeploy.sol";
import {LibRainDeployBeaconResolution} from "./LibRainDeployBeaconResolution.sol";

/// @param chainId The beacon's chain id.
/// @param beaconIndex The beacon's index in the beacon config.
error BeaconOnUncheckedNetwork(uint256 chainId, uint256 beaconIndex);

/// @param chainId The beacon's network.
/// @param beaconIndex The index in the beacon config of the later declaration.
error BeaconDeclaredTwice(uint256 chainId, uint256 beaconIndex);

/// @title LibRainDeployBeaconDeclarationChecks
/// @notice The beacon proxy handler's `checkDeclaration`: every declared beacon resolved offline.
library LibRainDeployBeaconDeclarationChecks {
    /// Every declared beacon resolved on every declared network, through `LibRainDeployBeaconResolution`.
    /// @param d The declaration, extended.
    function checkDeclaration(DeployDeclaration memory d) internal {
        // Called for its refusals.
        // slither-disable-next-line unused-return
        LibRainDeployBeaconResolution.resolveBeacons(d, LibRainDeploy.declaredNetworkConfigs(d.networks));
    }
}
