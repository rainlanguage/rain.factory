// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.17.0/src/Vm.sol";
import {RAIN_COPYRIGHT_TEXT, RAIN_SPDX_LICENSE_IDENTIFIER} from "rain-sol-codegen-0.1.39/src/lib/LibCodeGen.sol";
import {DeployDeclaration} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {ChainDeploy, LibRainDeployExtendedNetworks} from "./LibRainDeployExtendedNetworks.sol";
import {CloneLayerConfig, LibRainDeployCloneMechanism} from "./LibRainDeployCloneMechanism.sol";

/// @title LibRainDeployCloneBuild
/// @notice The build-side writer of the extended networks records the clone layer config declares. A consumer's
/// `Build.sol` calls `regenerateExtendedNetworks` from its build hook and `extendedNetworksPaths` from its
/// `buildGeneratedPaths()`.
library LibRainDeployCloneBuild {
    /// Writes each release's extended networks record from the clone layer config, under its `extendedNetworksRoot`.
    /// Append-only against the record in the checkout: reverts with `ExtendedNetworksRewritten` on a declaration
    /// that drops, changes or reorders a network that record holds. Before writing, refuses a declaration the
    /// broadcast and the chain group would refuse, as `LibRainDeployCloneMechanism.appendExtendedNetworks` does.
    /// @param vm The Vm instance for file and string operations.
    /// @param d The declaration, its clone handlers appended.
    /// @param spdxLicenseIdentifier The SPDX licence identifier each written record declares.
    /// @param copyrightText The copyright text each written record declares.
    function regenerateExtendedNetworks(
        Vm vm,
        DeployDeclaration memory d,
        string memory spdxLicenseIdentifier,
        string memory copyrightText
    ) internal {
        CloneLayerConfig memory config = LibRainDeployCloneMechanism.layerConfig(d);
        for (uint256 i = 0; i < d.released.length; i++) {
            ChainDeploy[] memory declared = LibRainDeployCloneMechanism.extendedNetworksOf(config, d.released[i].suite);
            // Called for its refusals: `declared` is what is written, once each network derives its declared address.
            // slither-disable-next-line unused-return
            LibRainDeployCloneMechanism.appendExtendedNetworks(d.released[i], declared);
            LibRainDeployExtendedNetworks.writeExtendedNetworks(
                vm, config.extendedNetworksRoot, d.released[i].suite, declared, spdxLicenseIdentifier, copyrightText
            );
        }
    }

    /// `regenerateExtendedNetworks` applied to `RAIN_SPDX_LICENSE_IDENTIFIER` and `RAIN_COPYRIGHT_TEXT`, for a repo
    /// this org owns.
    /// @param vm The Vm instance for file and string operations.
    /// @param d The declaration, its clone handlers appended.
    function regenerateExtendedNetworks(Vm vm, DeployDeclaration memory d) internal {
        regenerateExtendedNetworks(vm, d, RAIN_SPDX_LICENSE_IDENTIFIER, RAIN_COPYRIGHT_TEXT);
    }

    /// Every extended networks record `regenerateExtendedNetworks` writes.
    /// @param d The declaration, its clone handlers appended.
    /// @return The paths.
    function extendedNetworksPaths(DeployDeclaration memory d) internal pure returns (string[] memory) {
        CloneLayerConfig memory config = LibRainDeployCloneMechanism.layerConfig(d);
        string[] memory written = new string[](d.released.length);
        uint256 count = 0;
        for (uint256 i = 0; i < d.released.length; i++) {
            // The path alone names the record; its directory is not needed.
            // slither-disable-next-line unused-return
            (, string memory path) = LibRainDeployExtendedNetworks.writtenExtendedNetworksPath(
                config.extendedNetworksRoot,
                d.released[i].suite,
                LibRainDeployCloneMechanism.extendedNetworksOf(config, d.released[i].suite)
            );
            if (bytes(path).length > 0) {
                written[count++] = path;
            }
        }
        string[] memory paths = new string[](count);
        for (uint256 i = 0; i < count; i++) {
            paths[i] = written[i];
        }
        return paths;
    }
}
