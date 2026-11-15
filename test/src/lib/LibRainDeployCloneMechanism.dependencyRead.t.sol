// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {DeployDeclaration, DeploySuite} from "rain-deploy-0.1.32/src/abstract/RainDeploySuitesBase.sol";
import {DeployDependency, LibRainDeploy} from "rain-deploy-0.1.32/src/lib/LibRainDeploy.sol";
import {IConfigRegistryV5} from "rain-deploy-0.1.32/src/interface/IConfigRegistryV5.sol";
import {LibConfigRegistryDeploy} from "rain-deploy-0.1.32/src/lib/LibConfigRegistryDeploy.sol";
import {
    RUNTIME_CODE as CONFIG_REGISTRY_RUNTIME_CODE
} from "rain-deploy-0.1.32/src/generated/candidate/ConfigRegistry.sol";
import {CloneDeploy, LibRainDeployClone} from "../../../src/lib/LibRainDeployClone.sol";
import {
    CloneInitializeReadsStorage,
    LibRainDeployCloneMechanism
} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {MockCloneFactory} from "../../concrete/MockCloneFactory.sol";
import {MockRegistryReadingCloneable} from "../../concrete/MockRegistryReadingCloneable.sol";
import {TestRegistryBeaconSource} from "../../concrete/TestRegistryBeaconSource.sol";

/// @title LibRainDeployCloneMechanismDependencyReadTest
/// @notice A clone's `initialize` reads the storage of the suite's declared dependencies as it stands, deployed
/// locally and on its chain alone; a read of any other account it did not create is refused.
contract LibRainDeployCloneMechanismDependencyReadTest is Test {
    address constant AUTHORITY = address(uint160(uint256(keccak256("rain.factory.test.dependency-read.authority"))));
    bytes32 constant NAME = keccak256("rain.factory.test.dependency-read.name");
    address constant REGISTRY = LibConfigRegistryDeploy.CONFIG_REGISTRY_DEPLOYED_ADDRESS;
    /// The block at which `ConfigRegistry` first has its code on Arbitrum One.
    uint256 constant CONFIG_REGISTRY_ARBITRUM_ONE_DEPLOY_BLOCK = 519115682;
    /// The block at which `ConfigRegistry` first has its code on Polygon.
    uint256 constant CONFIG_REGISTRY_POLYGON_DEPLOY_BLOCK = 96336285;

    function externalDeployLocally(DeploySuite memory suite) external returns (address[] memory) {
        DeployDeclaration memory d;
        return LibRainDeployCloneMechanism.deployLocally(d, vm, suite);
    }

    function externalDeployLocallyOnChain(DeploySuite memory suite) external {
        DeployDeclaration memory d;
        LibRainDeployCloneMechanism.deployLocallyOnChain(d, vm, suite);
    }

    function bind(address registry, bytes memory value) internal {
        vm.prank(AUTHORITY);
        IConfigRegistryV5(registry).registerV5(AUTHORITY, NAME, "bytes", value, "");
    }

    /// @return The first slot of `registry` its `getV5` of `NAME` reads.
    function firstSlotRead(address registry) internal returns (bytes32) {
        vm.record();
        IConfigRegistryV5(registry).getV5(AUTHORITY, NAME);
        (bytes32[] memory reads,) = vm.accesses(registry);
        vm.stopRecord();
        return reads[0];
    }

    /// @return The deployed `ConfigRegistry` as the one dependency declared.
    function registryDeclared() internal pure returns (DeployDependency[] memory) {
        DeployDependency[] memory declared = new DeployDependency[](1);
        declared[0] = DeployDependency({deployedAddress: REGISTRY, runtimeCode: CONFIG_REGISTRY_RUNTIME_CODE});
        return declared;
    }

    /// A clone of `MockRegistryReadingCloneable` on Arbitrum One and Polygon, declaring its factory, its
    /// implementation and `declared`.
    /// @param registry The registry `initialize` reads `NAME` from.
    /// @param declared The dependencies declared besides the factory and the implementation.
    function registryReadingSuite(address registry, DeployDependency[] memory declared)
        internal
        view
        returns (DeploySuite memory)
    {
        address factory = LibRainDeploy.zoltuAddress(type(MockCloneFactory).creationCode);
        address implementation = LibRainDeploy.zoltuAddress(type(MockRegistryReadingCloneable).creationCode);
        DeployDependency[] memory dependencies = new DeployDependency[](2 + declared.length);
        dependencies[0] = DeployDependency({deployedAddress: factory, runtimeCode: type(MockCloneFactory).runtimeCode});
        dependencies[1] = DeployDependency({
            deployedAddress: implementation, runtimeCode: type(MockRegistryReadingCloneable).runtimeCode
        });
        for (uint256 i = 0; i < declared.length; i++) {
            dependencies[2 + i] = declared[i];
        }
        CloneDeploy memory clone = CloneDeploy({
            suite: "dependency-read",
            factory: factory,
            implementation: implementation,
            data: abi.encode(registry, AUTHORITY, NAME),
            initDataPerNetwork: false,
            initData: LibRainDeployClone.noInitDataPerNetwork,
            salt: bytes32(uint256(7)),
            dependencies: dependencies
        });
        DeploySuite memory suite = LibRainDeployCloneMechanism.cloneCandidate(clone, new uint256[](0)).snapshot;
        string[] memory networks = new string[](2);
        networks[0] = LibRainDeploy.ARBITRUM_ONE;
        networks[1] = LibRainDeploy.POLYGON;
        suite.networks = networks;
        return suite;
    }

    /// Deploys `suite` locally on all its networks, then from the same state on its chain alone, each clone holding
    /// `value`.
    function assertDeploysHolding(DeploySuite memory suite, bytes memory value) internal {
        uint256 snapshotId = vm.snapshotState();
        address[] memory deployed = this.externalDeployLocally(suite);
        assertEq(deployed.length, 2);
        for (uint256 i = 0; i < deployed.length; i++) {
            assertEq(deployed[i], suite.storedDeployedAddress);
            assertEq(MockRegistryReadingCloneable(deployed[i]).sValue(), value);
        }
        assertTrue(vm.revertToStateAndDelete(snapshotId));

        this.externalDeployLocallyOnChain(suite);
        assertEq(suite.storedDeployedAddress.code, suite.storedRuntimeCode);
        assertEq(MockRegistryReadingCloneable(suite.storedDeployedAddress).sValue(), value);
    }

    /// Refuses `suite` naming `account` and `slot`, deployed locally and on its chain alone.
    function assertRefused(DeploySuite memory suite, address account, bytes32 slot) internal {
        bytes memory refusal = abi.encodeWithSelector(CloneInitializeReadsStorage.selector, suite.suite, account, slot);
        vm.expectRevert(refusal);
        this.externalDeployLocally(suite);
        vm.expectRevert(refusal);
        this.externalDeployLocallyOnChain(suite);
    }

    /// On each network's fork the clone reading the declared `ConfigRegistry` deploys holding that network's binding.
    function testCloneInitializeReadingADeclaredRegistryOnItsForkDeploys() external {
        DeploySuite memory suite = registryReadingSuite(REGISTRY, registryDeclared());

        vm.createSelectFork(LibRainDeploy.ARBITRUM_ONE, CONFIG_REGISTRY_ARBITRUM_ONE_DEPLOY_BLOCK);
        bind(REGISTRY, "arbitrum binding");
        assertDeploysHolding(suite, "arbitrum binding");

        vm.createSelectFork(LibRainDeploy.POLYGON, CONFIG_REGISTRY_POLYGON_DEPLOY_BLOCK);
        bind(REGISTRY, "polygon binding");
        assertDeploysHolding(suite, "polygon binding");
    }

    /// On the fork, the same read of the deployed `ConfigRegistry` is refused when the suite does not declare it.
    function testCloneInitializeReadingAnUndeclaredRegistryOnItsForkIsRefused() external {
        vm.createSelectFork(LibRainDeploy.ARBITRUM_ONE, CONFIG_REGISTRY_ARBITRUM_ONE_DEPLOY_BLOCK);
        bind(REGISTRY, "arbitrum binding");
        assertRefused(registryReadingSuite(REGISTRY, new DeployDependency[](0)), REGISTRY, firstSlotRead(REGISTRY));
    }

    /// A read of an account the suite does not declare is refused while it declares another.
    function testCloneInitializeReadingAnUndeclaredAccountIsRefused() external {
        TestRegistryBeaconSource standIn = new TestRegistryBeaconSource();
        standIn.bind(AUTHORITY, NAME, "bytes", "stand-in binding");
        assertRefused(
            registryReadingSuite(address(standIn), registryDeclared()),
            address(standIn),
            firstSlotRead(address(standIn))
        );
    }

    /// A declared dependency's storage survives the etch of its declared code: bound, then left without code, it
    /// is read once etched.
    function testDeclaredDependencyStorageSurvivesEtching() external {
        TestRegistryBeaconSource source = new TestRegistryBeaconSource();
        source.bind(AUTHORITY, NAME, "bytes", "kept binding");
        DeployDependency[] memory declared = new DeployDependency[](1);
        declared[0] = DeployDependency({deployedAddress: address(source), runtimeCode: address(source).code});
        vm.etch(address(source), "");
        assertDeploysHolding(registryReadingSuite(address(source), declared), "kept binding");
    }
}
