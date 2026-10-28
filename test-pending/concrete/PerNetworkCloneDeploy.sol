// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {RainDeploySuitesBase} from "rain-deploy-0.1.27/src/abstract/RainDeploySuitesBase.sol";
import {CloneDeploy} from "../../src/lib/LibRainDeployClone.sol";
import {ChainDeploy} from "rain-deploy-0.1.27/src/lib/LibRainDeployExtendedNetworks.sol";
import {RainDeployCloneSuitesBase} from "../../src/abstract/RainDeployCloneSuitesBase.sol";
import {PerNetworkCloneDeployBase} from "../abstract/PerNetworkCloneDeployBase.sol";
import {PerNetworkCloneDeploys} from "../abstract/PerNetworkCloneDeploys.sol";

/// @title PerNetworkCloneDeploy
/// @notice `PerNetworkCloneDeploys` under `PerNetworkCloneDeployBase`.
contract PerNetworkCloneDeploy is PerNetworkCloneDeploys, PerNetworkCloneDeployBase {
    /// @inheritdoc PerNetworkCloneDeploys
    function cloneDeploys()
        internal
        pure
        override(PerNetworkCloneDeploys, RainDeployCloneSuitesBase)
        returns (CloneDeploy[] memory)
    {
        return PerNetworkCloneDeploys.cloneDeploys();
    }

    /// @inheritdoc PerNetworkCloneDeploys
    function supportedNetworks()
        internal
        view
        override(PerNetworkCloneDeploys, RainDeploySuitesBase)
        returns (string[] memory)
    {
        return PerNetworkCloneDeploys.supportedNetworks();
    }

    /// @inheritdoc PerNetworkCloneDeployBase
    function extendedNetworks(string memory suite)
        internal
        view
        override(PerNetworkCloneDeployBase, RainDeploySuitesBase)
        returns (ChainDeploy[] memory)
    {
        return PerNetworkCloneDeployBase.extendedNetworks(suite);
    }

    /// @inheritdoc PerNetworkCloneDeployBase
    function extendedNetworksRoot()
        internal
        view
        override(PerNetworkCloneDeployBase, RainDeploySuitesBase)
        returns (string memory)
    {
        return PerNetworkCloneDeployBase.extendedNetworksRoot();
    }
}
