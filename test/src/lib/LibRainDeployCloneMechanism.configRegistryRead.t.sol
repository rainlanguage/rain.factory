// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {DeployDeclaration, DeploySuite} from "rain-deploy-0.1.37/src/abstract/RainDeploySuitesBase.sol";
import {DeployDependency, LibRainDeploy} from "rain-deploy-0.1.37/src/lib/LibRainDeploy.sol";
import {IConfigRegistryV5} from "rain-deploy-0.1.37/src/interface/IConfigRegistryV5.sol";
import {LibConfigRegistryDeploy} from "rain-deploy-0.1.37/src/lib/LibConfigRegistryDeploy.sol";
import {
    RUNTIME_CODE as CONFIG_REGISTRY_RUNTIME_CODE
} from "rain-deploy-0.1.37/src/generated/candidate/ConfigRegistry.sol";
import {CloneDeploy, LibRainDeployClone} from "../../../src/lib/LibRainDeployClone.sol";
import {LibRainDeployCloneMechanism} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {MockCloneFactory} from "../../concrete/MockCloneFactory.sol";
import {MockRegistryReadingCloneable} from "../../concrete/MockRegistryReadingCloneable.sol";

/// @title LibRainDeployCloneMechanismConfigRegistryReadTest
/// @notice A clone whose `initialize` reads the deployed `ConfigRegistry` deploys holding the network's binding.
contract LibRainDeployCloneMechanismConfigRegistryReadTest is Test {
    address constant AUTHORITY =
        address(uint160(uint256(keccak256("rain.factory.test.config-registry-read.authority"))));
    bytes32 constant NAME = keccak256("rain.factory.test.config-registry-read.name");
    address constant REGISTRY = LibConfigRegistryDeploy.CONFIG_REGISTRY_DEPLOYED_ADDRESS;
    /// The block at which `ConfigRegistry` first has its code on Arbitrum One.
    uint256 constant CONFIG_REGISTRY_ARBITRUM_ONE_DEPLOY_BLOCK = 519115682;

    function externalDeployLocally(DeploySuite memory suite) external returns (address[] memory) {
        DeployDeclaration memory d;
        return LibRainDeployCloneMechanism.deployLocally(d, vm, suite);
    }

    function externalDeployLocallyOnChain(DeploySuite memory suite) external {
        DeployDeclaration memory d;
        LibRainDeployCloneMechanism.deployLocallyOnChain(d, vm, suite);
    }

    /// A clone of `MockRegistryReadingCloneable` on Arbitrum One reading `NAME` from the deployed `ConfigRegistry`,
    /// declaring its factory, its implementation and the registry.
    function registryReadingSuite() internal view returns (DeploySuite memory) {
        address factory = LibRainDeploy.zoltuAddress(type(MockCloneFactory).creationCode);
        address implementation = LibRainDeploy.zoltuAddress(type(MockRegistryReadingCloneable).creationCode);
        DeployDependency[] memory dependencies = new DeployDependency[](3);
        dependencies[0] = DeployDependency({deployedAddress: factory, runtimeCode: type(MockCloneFactory).runtimeCode});
        dependencies[1] = DeployDependency({
            deployedAddress: implementation, runtimeCode: type(MockRegistryReadingCloneable).runtimeCode
        });
        dependencies[2] = DeployDependency({deployedAddress: REGISTRY, runtimeCode: CONFIG_REGISTRY_RUNTIME_CODE});
        CloneDeploy memory clone = CloneDeploy({
            suite: "config-registry-read",
            factory: factory,
            implementation: implementation,
            data: abi.encode(REGISTRY, AUTHORITY, NAME),
            initDataPerNetwork: false,
            initData: LibRainDeployClone.noInitDataPerNetwork,
            salt: bytes32(uint256(7)),
            dependencies: dependencies
        });
        DeploySuite memory suite = LibRainDeployCloneMechanism.cloneCandidate(clone, new uint256[](0)).snapshot;
        string[] memory networks = new string[](1);
        networks[0] = LibRainDeploy.ARBITRUM_ONE;
        suite.networks = networks;
        return suite;
    }

    /// On the Arbitrum One fork the clone reading the deployed `ConfigRegistry` deploys holding Arbitrum One's
    /// binding, locally and on its chain alone.
    function testCloneInitializeReadingTheDeployedRegistryOnItsForkDeploys() external {
        vm.createSelectFork(LibRainDeploy.ARBITRUM_ONE, CONFIG_REGISTRY_ARBITRUM_ONE_DEPLOY_BLOCK);
        vm.prank(AUTHORITY);
        IConfigRegistryV5(REGISTRY).registerV5(AUTHORITY, NAME, "bytes", "arbitrum binding", "");
        DeploySuite memory suite = registryReadingSuite();

        uint256 snapshotId = vm.snapshotState();
        address[] memory deployed = this.externalDeployLocally(suite);
        assertEq(deployed.length, 1);
        assertEq(deployed[0], suite.storedDeployedAddress);
        assertEq(MockRegistryReadingCloneable(deployed[0]).sValue(), "arbitrum binding");
        assertTrue(vm.revertToStateAndDelete(snapshotId));

        this.externalDeployLocallyOnChain(suite);
        assertEq(suite.storedDeployedAddress.code, suite.storedRuntimeCode);
        assertEq(MockRegistryReadingCloneable(suite.storedDeployedAddress).sValue(), "arbitrum binding");
    }
}
