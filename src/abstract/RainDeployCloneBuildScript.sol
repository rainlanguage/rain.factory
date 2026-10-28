// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.17.0/src/Vm.sol";
import {DeploySuite, RainDeploySuitesBase} from "rain-deploy-0.1.27/src/abstract/RainDeploySuitesBase.sol";
import {BuildScript} from "rain-deploy-0.1.27/src/abstract/BuildScript.sol";
import {ChainDeploy} from "rain-deploy-0.1.27/src/lib/LibRainDeployExtendedNetworks.sol";
import {RainDeployCloneSuitesBase} from "./RainDeployCloneSuitesBase.sol";

/// @title RainDeployCloneBuildScript
/// @notice `BuildScript` for a `RainDeployCloneSuitesBase` declaration, with the
/// mechanism hooks resolved once so an inheritor overrides none of them.
abstract contract RainDeployCloneBuildScript is RainDeployCloneSuitesBase, BuildScript {

    function deployedAddress(DeploySuite memory suite, uint256 chainId)
        internal
        view
        override(RainDeploySuitesBase, RainDeployCloneSuitesBase)
        returns (address)
    {
        return super.deployedAddress(suite, chainId);
    }

    function recordedAddress(DeploySuite memory suite, uint256 chainId)
        internal
        view
        override(RainDeploySuitesBase, RainDeployCloneSuitesBase)
        returns (address)
    {
        return super.recordedAddress(suite, chainId);
    }

    function addressChainIds(DeploySuite memory suite)
        internal
        view
        override(RainDeploySuitesBase, RainDeployCloneSuitesBase)
        returns (uint256[] memory)
    {
        return super.addressChainIds(suite);
    }

    function deployStepData(DeploySuite memory suite, uint256 chainId)
        internal
        view
        override(RainDeploySuitesBase, RainDeployCloneSuitesBase)
        returns (bytes memory)
    {
        return super.deployStepData(suite, chainId);
    }

    function deployStep(DeploySuite memory suite)
        internal
        view
        override(RainDeploySuitesBase, RainDeployCloneSuitesBase)
        returns (function(Vm, string memory, address, bytes memory) internal returns (address))
    {
        return super.deployStep(suite);
    }

    function deployLocally(Vm localVm, DeploySuite memory suite)
        internal
        override(RainDeploySuitesBase, RainDeployCloneSuitesBase)
        returns (address[] memory)
    {
        return super.deployLocally(localVm, suite);
    }

    function deployLocallyOnChain(Vm localVm, DeploySuite memory suite)
        internal
        override(RainDeploySuitesBase, RainDeployCloneSuitesBase)
    {
        super.deployLocallyOnChain(localVm, suite);
    }

    function withUnrecordedNetworks(DeploySuite memory suite, DeploySuite memory candidate, uint256[] memory chainIds)
        internal
        view
        override(RainDeploySuitesBase, RainDeployCloneSuitesBase)
        returns (DeploySuite memory)
    {
        return super.withUnrecordedNetworks(suite, candidate, chainIds);
    }

    function appendExtendedNetworks(DeploySuite memory suite, ChainDeploy[] memory extended)
        internal
        view
        override(RainDeploySuitesBase, RainDeployCloneSuitesBase)
        returns (DeploySuite memory)
    {
        return super.appendExtendedNetworks(suite, extended);
    }

    function checkNetworkFrozen(DeploySuite memory frozen, string memory network, uint256 chainId, address where)
        internal
        view
        override(RainDeploySuitesBase, RainDeployCloneSuitesBase)
    {
        super.checkNetworkFrozen(frozen, network, chainId, where);
    }

    function suiteBeacon(DeploySuite memory suite, uint256 chainId)
        internal
        view
        override(RainDeploySuitesBase, RainDeployCloneSuitesBase)
        returns (address)
    {
        return super.suiteBeacon(suite, chainId);
    }

    function logVerification(Vm logVm, string[] memory networks, DeploySuite memory suite, address[] memory deployed)
        internal
        override(RainDeploySuitesBase, RainDeployCloneSuitesBase)
    {
        super.logVerification(logVm, networks, suite, deployed);
    }

    function writeSuiteSnapshot(
        Vm fileVm,
        string memory root,
        string memory dir,
        string memory contractName,
        string memory spdxLicenseIdentifier,
        string memory copyrightText,
        DeploySuite memory suite
    ) internal override(RainDeploySuitesBase, RainDeployCloneSuitesBase) returns (string memory) {
        return super.writeSuiteSnapshot(fileVm, root, dir, contractName, spdxLicenseIdentifier, copyrightText, suite);
    }

    function releasedMechanismData(Vm fileVm, string memory path, string memory prefix)
        internal
        view
        override(RainDeploySuitesBase, RainDeployCloneSuitesBase)
        returns (string memory)
    {
        return super.releasedMechanismData(fileVm, path, prefix);
    }
}
