// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {DeployDeclaration} from "rain-deploy-0.1.27/src/abstract/RainDeploySuitesBase.sol";
import {DeployDependency, LibRainDeploy} from "rain-deploy-0.1.27/src/lib/LibRainDeploy.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.27/src/lib/LibRainDeployDeclaration.sol";
import {LibRainDeployZoltuMechanism} from "rain-deploy-0.1.27/src/lib/LibRainDeployZoltuMechanism.sol";
import {ChainBeacon} from "../../src/lib/LibRainDeployBeacon.sol";
import {CloneDeploy} from "../../src/lib/LibRainDeployClone.sol";
import {LibRainDeployCloneMechanism} from "../../src/lib/LibRainDeployCloneMechanism.sol";
import {ExternalDeployBroadcast} from "../abstract/ExternalDeployBroadcast.sol";
import {LibCloneCandidates} from "../lib/LibCloneCandidates.sol";
import {MockCloneFactory} from "./MockCloneFactory.sol";
import {MockOriginOwnedCloneable} from "./MockOriginOwnedCloneable.sol";

/// The `origin-owned-clone` factory and implementation, each a declared dependency.
/// @return The factory.
/// @return The implementation.
/// @return The factory and the implementation as dependencies, in that order.
function originOwnedCloneSetup() pure returns (address, address, DeployDependency[] memory) {
    address factory = LibRainDeploy.zoltuAddress(type(MockCloneFactory).creationCode);
    address implementation = LibRainDeploy.zoltuAddress(type(MockOriginOwnedCloneable).creationCode);
    DeployDependency[] memory dependencies = new DeployDependency[](2);
    dependencies[0] = DeployDependency({deployedAddress: factory, runtimeCode: type(MockCloneFactory).runtimeCode});
    dependencies[1] =
        DeployDependency({deployedAddress: implementation, runtimeCode: type(MockOriginOwnedCloneable).runtimeCode});
    return (factory, implementation, dependencies);
}

/// The init data of the `origin-owned-clone` candidate: Base's clone seats its initialization's origin, every
/// other network's seats `0xB0B`.
/// @param chainId The network's chain id.
/// @return The init data on that network.
function originOwnedCloneInitData(uint256 chainId) pure returns (bytes memory) {
    return abi.encode(chainId == 8453 ? address(0) : address(0xB0B));
}

/// @return Arbitrum One then Base: the networks the `origin-owned-clone` repo supports.
function originOwnedCloneNetworks() pure returns (string[] memory) {
    string[] memory networks = new string[](2);
    networks[0] = LibRainDeploy.ARBITRUM_ONE;
    networks[1] = LibRainDeploy.BASE;
    return networks;
}

/// @return The `origin-owned-clone` declaration a candidate is derived from.
function originOwnedCloneDeploys() pure returns (CloneDeploy[] memory) {
    (address factory, address implementation, DeployDependency[] memory dependencies) = originOwnedCloneSetup();
    CloneDeploy[] memory clones = new CloneDeploy[](1);
    clones[0] = CloneDeploy({
        suite: "origin-owned-clone",
        factory: factory,
        implementation: implementation,
        data: "",
        initDataPerNetwork: true,
        initData: originOwnedCloneInitData,
        salt: bytes32(uint256(7)),
        dependencies: dependencies
    });
    return clones;
}

/// @title OriginOwnedCloneDeploy
/// @notice A per-network clone repo on Arbitrum One and Base whose candidate's Base clone seats the deploy key,
/// with `broadcastSuite` exposed.
contract OriginOwnedCloneDeploy is ExternalDeployBroadcast {
    function declaration() internal view override returns (DeployDeclaration memory) {
        DeployDeclaration memory d;
        LibRainDeployDeclaration.extend(d);
        LibRainDeployDeclaration.setNetworks(d, originOwnedCloneNetworks());
        LibRainDeployZoltuMechanism.extend(d);
        LibRainDeployCloneMechanism.extend(d, new ChainBeacon[](0));
        LibCloneCandidates.addClones(d, originOwnedCloneDeploys());
        return d;
    }
}
