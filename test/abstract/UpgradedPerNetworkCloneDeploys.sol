// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {DeployDeclaration, RainDeploySuitesBase} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.29/src/lib/LibRainDeployDeclaration.sol";
import {LibCloneCandidates} from "../../src/lib/LibCloneCandidates.sol";
import {CloneDeploy, CloneTarget, LibRainDeployClone} from "../../src/lib/LibRainDeployClone.sol";
import {DeployDependency, LibRainDeploy} from "rain-deploy-0.1.29/src/lib/LibRainDeploy.sol";
import {MockCloneFactory} from "../concrete/MockCloneFactory.sol";
import {MockCloneableV2} from "../concrete/MockCloneableV2.sol";
import {perNetworkCloneInitData, perNetworkCloneLayers, perNetworkCloneReleased} from "./PerNetworkCloneDeploys.sol";

/// The factory the upgraded candidate clones through.
/// @return The factory address.
function upgradedCloneFactory() pure returns (address) {
    return address(uint160(uint256(keccak256("rain.deploy.test.upgraded-clone-factory"))));
}

/// The implementation the upgraded candidate clones.
/// @return The implementation address.
function upgradedCloneImplementation() pure returns (address) {
    return LibRainDeploy.zoltuAddress(type(MockCloneableV2).creationCode);
}

/// The upgraded candidate's dependencies.
/// @return The dependencies.
function upgradedCloneDependencies() pure returns (DeployDependency[] memory) {
    DeployDependency[] memory dependencies = new DeployDependency[](2);
    dependencies[0] =
        DeployDependency({deployedAddress: upgradedCloneFactory(), runtimeCode: type(MockCloneFactory).runtimeCode});
    dependencies[1] = DeployDependency({
        deployedAddress: upgradedCloneImplementation(), runtimeCode: type(MockCloneableV2).runtimeCode
    });
    return dependencies;
}

/// The `per-network-clone` candidate after it moved to the upgraded factory and implementation,
/// with the same per-network init data and its own salt.
/// @return The candidate's clone declaration.
function upgradedPerNetworkClone() pure returns (CloneDeploy memory) {
    return CloneDeploy({
        suite: "per-network-clone",
        factory: upgradedCloneFactory(),
        implementation: upgradedCloneImplementation(),
        data: "",
        initDataPerNetwork: true,
        initData: perNetworkCloneInitData,
        salt: bytes32(uint256(4)),
        dependencies: upgradedCloneDependencies()
    });
}

/// Where the upgraded candidate's factory, implementation and salt put a clone initialized with a
/// network's init data.
/// @param chainId The network's chain id.
/// @return The clone address.
function upgradedPerNetworkCloneAddress(uint256 chainId) pure returns (address) {
    CloneDeploy memory candidate = upgradedPerNetworkClone();
    return LibRainDeployClone.cloneDeployedAddress(
        CloneTarget({
            factory: candidate.factory,
            implementation: candidate.implementation,
            data: perNetworkCloneInitData(chainId),
            salt: candidate.salt
        })
    );
}

/// @title UpgradedPerNetworkCloneDeploys
/// @notice `PerNetworkCloneDeploys` with its candidate moved to another factory and implementation
/// since its `0_0_1` release was cut.
abstract contract UpgradedPerNetworkCloneDeploys is RainDeploySuitesBase {
    function declaration() internal view virtual override returns (DeployDeclaration memory) {
        DeployDeclaration memory d = perNetworkCloneLayers();
        LibRainDeployDeclaration.addReleased(d, perNetworkCloneReleased());
        CloneDeploy[] memory clones = new CloneDeploy[](1);
        clones[0] = upgradedPerNetworkClone();
        LibCloneCandidates.addClones(d, clones);
        return d;
    }
}
