// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {
    DeployDeclaration,
    DeployDependency,
    ExternalDeployment
} from "rain-deploy-0.1.43/src/abstract/RainDeploySuitesBase.sol";

/// @title LibExternalDeployments
/// @notice Declares deployments outside a fixture's suites as its external deployments.
library LibExternalDeployments {
    /// Appends each of `deployments` to `d.externalDeployments` at the hash of the code it declares.
    /// @param d The declaration, mutated.
    /// @param deployments The deployments.
    function add(DeployDeclaration memory d, DeployDependency[] memory deployments) internal pure {
        ExternalDeployment[] memory externals =
            new ExternalDeployment[](d.externalDeployments.length + deployments.length);
        for (uint256 i = 0; i < d.externalDeployments.length; i++) {
            externals[i] = d.externalDeployments[i];
        }
        for (uint256 i = 0; i < deployments.length; i++) {
            externals[d.externalDeployments.length + i] = ExternalDeployment({
                deployedAddress: deployments[i].deployedAddress, codeHash: keccak256(deployments[i].runtimeCode)
            });
        }
        d.externalDeployments = externals;
    }

    /// @param deployed An address.
    /// @return `deployed` with the code it holds now.
    function deployedNow(address deployed) internal view returns (DeployDependency memory) {
        return DeployDependency({deployedAddress: deployed, runtimeCode: deployed.code});
    }
}
