// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {DeploySuite} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {ExtendedNetworksDeclaration} from "../../src/lib/LibRainDeployCloneMechanism.sol";
import {ChainDeploy} from "../../src/lib/LibRainDeployExtendedNetworks.sol";
import {PerNetworkCloneBuildScriptHarness} from "./PerNetworkCloneBuildScriptHarness.sol";

/// @dev The key the harness releases its second copy of the per-network clone under.
string constant SECOND_RELEASE_KEY = "per-network-clone@0_0_2";

/// @title TwoReleasePerNetworkCloneBuildScriptHarness
/// @notice `PerNetworkCloneBuildScriptHarness` releasing the per-network clone twice, under its own key and under
/// `SECOND_RELEASE_KEY`, each with its own extended networks.
contract TwoReleasePerNetworkCloneBuildScriptHarness is PerNetworkCloneBuildScriptHarness {
    /// The networks the clone layer declares for `SECOND_RELEASE_KEY`. Empty by default.
    ChainDeploy[] internal sSecondExtendedNetworks;

    /// @param root The record root to regenerate into.
    /// @param libDir The directory the released-suites lib is written to.
    constructor(string memory root, string memory libDir) PerNetworkCloneBuildScriptHarness(root, libDir) {}

    /// @inheritdoc PerNetworkCloneBuildScriptHarness
    function released() internal pure override returns (DeploySuite[] memory) {
        DeploySuite memory first = PerNetworkCloneBuildScriptHarness.released()[0];
        DeploySuite memory second = PerNetworkCloneBuildScriptHarness.released()[0];
        second.suite = SECOND_RELEASE_KEY;
        DeploySuite[] memory suites = new DeploySuite[](2);
        suites[0] = first;
        suites[1] = second;
        return suites;
    }

    /// @inheritdoc PerNetworkCloneBuildScriptHarness
    function extended() internal view override returns (ExtendedNetworksDeclaration[] memory) {
        ExtendedNetworksDeclaration[] memory first = PerNetworkCloneBuildScriptHarness.extended();
        ExtendedNetworksDeclaration[] memory declared = new ExtendedNetworksDeclaration[](first.length + 1);
        for (uint256 i = 0; i < first.length; i++) {
            declared[i] = first[i];
        }
        declared[first.length] =
            ExtendedNetworksDeclaration({suite: SECOND_RELEASE_KEY, networks: sSecondExtendedNetworks});
        return declared;
    }

    /// Sets what the clone layer declares for `SECOND_RELEASE_KEY`.
    /// @param networks The networks.
    function setSecondExtendedNetworks(ChainDeploy[] memory networks) external {
        delete sSecondExtendedNetworks;
        for (uint256 i = 0; i < networks.length; i++) {
            sSecondExtendedNetworks.push(networks[i]);
        }
    }
}
