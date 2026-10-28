// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.17.0/src/Vm.sol";
import {console2} from "forge-std-1.17.0/src/console2.sol";
import {
    DeployCandidate,
    DeploySuite,
    RainDeploySuitesBase
} from "rain-deploy-0.1.27/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeploy, SupportedNetwork} from "rain-deploy-0.1.27/src/lib/LibRainDeploy.sol";
import {ChainDeploy} from "rain-deploy-0.1.27/src/lib/LibRainDeployExtendedNetworks.sol";
import {LibRainDeploySnapshot} from "rain-deploy-0.1.27/src/lib/LibRainDeploySnapshot.sol";
import {CloneDeploy} from "../lib/LibRainDeployClone.sol";
import {BeaconProxyDeploy} from "../lib/LibRainDeployBeaconProxy.sol";
import {LibRainDeployCloneMechanism, UnverifiableSource} from "../lib/LibRainDeployCloneMechanism.sol";
import {LibRainDeployCloneSnapshot, SnapshotStateRevertFailed} from "../lib/LibRainDeployCloneSnapshot.sol";

/// Thrown when a declaration names no clone and no beacon proxy at all.
error NoFactoryDeploys();

/// @title RainDeployCloneSuitesBase
/// @notice The declaration for a repo whose candidates are factory deployments: EIP-1167 clones,
/// beacon proxies, or both. Each mechanism hook handles a suite carrying one of
/// `LibRainDeployCloneMechanism`'s tags and hands any other to `RainDeploySuitesBase`.
abstract contract RainDeployCloneSuitesBase is RainDeploySuitesBase {
    /// Every clone candidate this repo deploys. None by default.
    /// @return The clones.
    function cloneDeploys() internal pure virtual returns (CloneDeploy[] memory) {
        return new CloneDeploy[](0);
    }

    /// Every beacon proxy candidate this repo deploys. None by default.
    /// @return The beacon proxies.
    function beaconProxyDeploys() internal pure virtual returns (BeaconProxyDeploy[] memory) {
        return new BeaconProxyDeploy[](0);
    }

    /// The chain id of every network in `supportedNetworks()`, in that order, from the network
    /// catalogue.
    /// @return The chain ids.
    function supportedChainIds() internal view returns (uint256[] memory) {
        SupportedNetwork[] memory configs = LibRainDeploy.declaredNetworkConfigs(supportedNetworks());
        uint256[] memory chainIds = new uint256[](configs.length);
        for (uint256 i = 0; i < configs.length; i++) {
            chainIds[i] = configs[i].chainId;
        }
        return chainIds;
    }

    /// Every candidate this repo deploys.
    /// @return The clones, then the beacon proxies, refusing `NoFactoryDeploys` when there are neither.
    function candidateSuites() internal view virtual override returns (DeployCandidate[] memory) {
        CloneDeploy[] memory clones = cloneDeploys();
        BeaconProxyDeploy[] memory proxies = beaconProxyDeploys();
        if (clones.length == 0 && proxies.length == 0) {
            revert NoFactoryDeploys();
        }
        uint256[] memory chainIds = supportedChainIds();
        DeployCandidate[] memory candidates = new DeployCandidate[](clones.length + proxies.length);
        for (uint256 i = 0; i < clones.length; i++) {
            candidates[i] = LibRainDeployCloneMechanism.cloneCandidate(clones[i], chainIds);
        }
        for (uint256 i = 0; i < proxies.length; i++) {
            candidates[clones.length + i] = LibRainDeployCloneMechanism.beaconProxyCandidate(proxies[i], chainIds);
        }
        return candidates;
    }

    /// @inheritdoc RainDeploySuitesBase
    function deployedAddress(DeploySuite memory suite, uint256 chainId) internal view virtual override returns (address) {
        if (LibRainDeployCloneMechanism.isFactoryMechanism(suite)) {
            return LibRainDeployCloneMechanism.deployedAddress(suite, chainId);
        }
        return super.deployedAddress(suite, chainId);
    }

    /// @inheritdoc RainDeploySuitesBase
    function recordedAddress(DeploySuite memory suite, uint256 chainId) internal view virtual override returns (address) {
        if (LibRainDeployCloneMechanism.isFactoryMechanism(suite)) {
            return LibRainDeployCloneMechanism.recordedAddress(suite, chainId);
        }
        return super.recordedAddress(suite, chainId);
    }

    /// @inheritdoc RainDeploySuitesBase
    function addressChainIds(DeploySuite memory suite) internal view virtual override returns (uint256[] memory) {
        if (LibRainDeployCloneMechanism.isFactoryMechanism(suite)) {
            return LibRainDeployCloneMechanism.addressChainIds(suite);
        }
        return super.addressChainIds(suite);
    }

    /// @inheritdoc RainDeploySuitesBase
    function deployStepData(DeploySuite memory suite, uint256 chainId)
        internal
        view
        virtual
        override
        returns (bytes memory)
    {
        if (LibRainDeployCloneMechanism.isFactoryMechanism(suite)) {
            return LibRainDeployCloneMechanism.deployStepData(suite, chainId);
        }
        return super.deployStepData(suite, chainId);
    }

    /// @inheritdoc RainDeploySuitesBase
    function deployStep(DeploySuite memory suite)
        internal
        view
        virtual
        override
        returns (function(Vm, string memory, address, bytes memory) internal returns (address))
    {
        if (LibRainDeployCloneMechanism.isFactoryMechanism(suite)) {
            return LibRainDeployCloneMechanism.deployStep(suite);
        }
        return super.deployStep(suite);
    }

    /// @inheritdoc RainDeploySuitesBase
    function deployLocally(Vm vm, DeploySuite memory suite) internal virtual override returns (address[] memory) {
        if (!LibRainDeployCloneMechanism.isFactoryMechanism(suite)) {
            return super.deployLocally(vm, suite);
        }
        address[] memory deployed = deployedAddresses(suite);
        etchDependencies(vm, suite);
        LibRainDeployCloneMechanism.deployTargets(vm, suite, deployed);
        return deployed;
    }

    /// @inheritdoc RainDeploySuitesBase
    /// @dev A per-network suite deploys only its network on `block.chainid`.
    function deployLocallyOnChain(Vm vm, DeploySuite memory suite) internal virtual override {
        if (!LibRainDeployCloneMechanism.isPerNetwork(suite)) {
            super.deployLocallyOnChain(vm, suite);
            return;
        }
        bytes memory mechanismData = suite.mechanismData;
        suite.mechanismData = LibRainDeployCloneMechanism.onChainMechanismData(suite, block.chainid);
        deployLocally(vm, suite);
        suite.mechanismData = mechanismData;
    }

    /// @inheritdoc RainDeploySuitesBase
    function withUnrecordedNetworks(DeploySuite memory suite, DeploySuite memory candidate, uint256[] memory chainIds)
        internal
        view
        virtual
        override
        returns (DeploySuite memory)
    {
        if (LibRainDeployCloneMechanism.isFactoryMechanism(suite)) {
            return LibRainDeployCloneMechanism.withUnrecordedNetworks(suite, candidate, chainIds);
        }
        return super.withUnrecordedNetworks(suite, candidate, chainIds);
    }

    /// @inheritdoc RainDeploySuitesBase
    function appendExtendedNetworks(DeploySuite memory suite, ChainDeploy[] memory extended)
        internal
        view
        virtual
        override
        returns (DeploySuite memory)
    {
        if (LibRainDeployCloneMechanism.isFactoryMechanism(suite)) {
            return LibRainDeployCloneMechanism.appendExtendedNetworks(suite, extended);
        }
        return super.appendExtendedNetworks(suite, extended);
    }

    /// @inheritdoc RainDeploySuitesBase
    function checkNetworkFrozen(DeploySuite memory frozen, string memory network, uint256 chainId, address where)
        internal
        view
        virtual
        override
    {
        if (LibRainDeployCloneMechanism.isFactoryMechanism(frozen)) {
            LibRainDeployCloneMechanism.checkNetworkFrozen(frozen, network, chainId, where);
            return;
        }
        super.checkNetworkFrozen(frozen, network, chainId, where);
    }

    /// @inheritdoc RainDeploySuitesBase
    function suiteBeacon(DeploySuite memory suite, uint256 chainId) internal view virtual override returns (address) {
        if (LibRainDeployCloneMechanism.isBeaconProxy(suite)) {
            return LibRainDeployCloneMechanism.beacon(suite, chainId);
        }
        if (LibRainDeployCloneMechanism.isFactoryMechanism(suite)) {
            return address(0);
        }
        return super.suiteBeacon(suite, chainId);
    }

    /// @inheritdoc RainDeploySuitesBase
    /// @dev Logs nothing for a clone or beacon proxy, and emits `UnverifiableSource` for a Zoltu suite under a
    /// factory proxy artifact path, whose source nothing here can verify.
    function logVerification(Vm vm, string[] memory networks, DeploySuite memory suite, address[] memory deployed)
        internal
        virtual
        override
    {
        if (LibRainDeployCloneMechanism.isFactoryMechanism(suite)) {
            return;
        }
        if (suite.mechanismData.length == 0 && LibRainDeployCloneMechanism.isProxyArtifactPath(suite.artifactPath)) {
            // slither-disable-next-line reentrancy-events
            emit UnverifiableSource(msg.sender, deployed[0], networks);
            console2.log(LibRainDeployCloneMechanism.unverifiableSourceNotice(vm, networks, deployed[0]));
            return;
        }
        super.logVerification(vm, networks, suite, deployed);
    }

    /// @inheritdoc RainDeploySuitesBase
    /// @dev A clone or beacon proxy is deployed locally inside a state snapshot, and its record written from there.
    function writeSuiteSnapshot(
        Vm vm,
        string memory root,
        string memory dir,
        string memory contractName,
        string memory spdxLicenseIdentifier,
        string memory copyrightText,
        DeploySuite memory suite
    ) internal virtual override returns (string memory) {
        if (!LibRainDeployCloneMechanism.isFactoryMechanism(suite)) {
            return super.writeSuiteSnapshot(vm, root, dir, contractName, spdxLicenseIdentifier, copyrightText, suite);
        }
        uint256 snapshotId = vm.snapshotState();
        LibRainDeployCloneSnapshot.writeCloneSnapshotFile(
            vm,
            LibRainDeploySnapshot.dirForSnapshot(root, dir),
            contractName,
            spdxLicenseIdentifier,
            copyrightText,
            suite,
            deployLocally(vm, suite)
        );
        if (!vm.revertToState(snapshotId)) {
            revert SnapshotStateRevertFailed(suite.suite, snapshotId);
        }
        return LibRainDeploySnapshot.pathForSnapshot(root, dir, contractName);
    }

    /// @inheritdoc RainDeploySuitesBase
    function releasedMechanismData(Vm vm, string memory path, string memory prefix)
        internal
        view
        virtual
        override
        returns (string memory)
    {
        bytes32 tag = LibRainDeployCloneSnapshot.recordedMechanismTag(vm, path);
        if (tag == bytes32(0)) {
            return super.releasedMechanismData(vm, path, prefix);
        }
        return LibRainDeployCloneSnapshot.releasedMechanismDataExpression(vm, tag, prefix);
    }
}
