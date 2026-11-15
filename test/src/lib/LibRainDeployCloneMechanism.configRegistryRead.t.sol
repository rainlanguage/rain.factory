// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {DeployDeclaration, DeploySuite} from "rain-deploy-0.1.32/src/abstract/RainDeploySuitesBase.sol";
import {DeployDependency, LibRainDeploy} from "rain-deploy-0.1.32/src/lib/LibRainDeploy.sol";
import {IConfigRegistryV5} from "rain-deploy-0.1.32/src/interface/IConfigRegistryV5.sol";
import {LibConfigRegistryDeploy} from "rain-deploy-0.1.32/src/lib/LibConfigRegistryDeploy.sol";
import {CloneDeploy, LibRainDeployClone} from "../../../src/lib/LibRainDeployClone.sol";
import {
    CloneInitializeReadsStorage,
    LibRainDeployCloneMechanism
} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {MockCloneFactory} from "../../concrete/MockCloneFactory.sol";
import {MockRegistryReadingCloneable} from "../../concrete/MockRegistryReadingCloneable.sol";
import {MockStorageReadingCloneable, SourceUse} from "../../concrete/MockStorageReadingCloneable.sol";
import {MockStorageSource} from "../../concrete/MockStorageSource.sol";
import {TestRegistryBeaconSource} from "../../concrete/TestRegistryBeaconSource.sol";

/// @title LibRainDeployCloneMechanismConfigRegistryReadTest
/// @notice A clone's `initialize` reads the deployed `ConfigRegistry` only when deployed on its network's fork; every
/// other read of storage it did not create stays refused there.
contract LibRainDeployCloneMechanismConfigRegistryReadTest is Test {
    address constant AUTHORITY =
        address(uint160(uint256(keccak256("rain.factory.test.config-registry-read.authority"))));
    bytes32 constant NAME = keccak256("rain.factory.test.config-registry-read.name");
    address constant REGISTRY = LibConfigRegistryDeploy.CONFIG_REGISTRY_DEPLOYED_ADDRESS;

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

    function cloneSuite(address implementation, bytes memory implementationCode, bytes memory data)
        internal
        view
        returns (DeploySuite memory)
    {
        address factory = LibRainDeploy.zoltuAddress(type(MockCloneFactory).creationCode);
        DeployDependency[] memory dependencies = new DeployDependency[](2);
        dependencies[0] = DeployDependency({deployedAddress: factory, runtimeCode: type(MockCloneFactory).runtimeCode});
        dependencies[1] = DeployDependency({deployedAddress: implementation, runtimeCode: implementationCode});
        CloneDeploy memory clone = CloneDeploy({
            suite: "config-registry-read",
            factory: factory,
            implementation: implementation,
            data: data,
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

    /// @param registry The registry `initialize` reads `NAME` from.
    /// @param chainId The chain id it reads under, or zero for any.
    function registryReadingSuite(address registry, uint256 chainId) internal view returns (DeploySuite memory) {
        return cloneSuite(
            LibRainDeploy.zoltuAddress(type(MockRegistryReadingCloneable).creationCode),
            type(MockRegistryReadingCloneable).runtimeCode,
            abi.encode(registry, AUTHORITY, NAME, chainId)
        );
    }

    function deployOnChainHolding(DeploySuite memory suite, bytes memory value) internal {
        this.externalDeployLocallyOnChain(suite);
        assertEq(suite.storedDeployedAddress.code, suite.storedRuntimeCode);
        assertEq(MockRegistryReadingCloneable(suite.storedDeployedAddress).sValue(), value);
    }

    function assertOnChainReadRefused(address registry) internal {
        bytes32 slot = firstSlotRead(registry);
        DeploySuite memory suite = registryReadingSuite(registry, 0);
        vm.expectRevert(abi.encodeWithSelector(CloneInitializeReadsStorage.selector, suite.suite, registry, slot));
        this.externalDeployLocallyOnChain(suite);
    }

    /// On each network's fork the clone deploys holding the value that network's deployed `ConfigRegistry` binds.
    function testCloneInitializeReadingTheConfigRegistryOnItsForkDeploys() external {
        DeploySuite memory suite = registryReadingSuite(REGISTRY, 0);

        vm.createSelectFork(LibRainDeploy.ARBITRUM_ONE);
        bind(REGISTRY, "arbitrum binding");
        deployOnChainHolding(suite, "arbitrum binding");

        vm.createSelectFork(LibRainDeploy.POLYGON);
        bind(REGISTRY, "polygon binding");
        deployOnChainHolding(suite, "polygon binding");
    }

    /// Deployed locally on the same fork, the clone is refused whichever of its networks reads the registry: the one
    /// deployed in a reverted snapshot, the one left deployed, or both.
    function testCloneInitializeReadingTheConfigRegistryLocallyIsRefused() external {
        vm.createSelectFork(LibRainDeploy.ARBITRUM_ONE);
        bind(REGISTRY, "arbitrum binding");
        bytes32 slot = firstSlotRead(REGISTRY);
        uint256[3] memory readOn = [uint256(0), 137, 42161];
        for (uint256 i = 0; i < readOn.length; i++) {
            DeploySuite memory suite = registryReadingSuite(REGISTRY, readOn[i]);
            vm.expectRevert(abi.encodeWithSelector(CloneInitializeReadsStorage.selector, suite.suite, REGISTRY, slot));
            this.externalDeployLocally(suite);
        }
    }

    /// On the fork, a read of an account that is not the deployed `ConfigRegistry` is refused.
    function testCloneInitializeReadingAnotherAccountOnItsForkIsRefused() external {
        vm.createSelectFork(LibRainDeploy.ARBITRUM_ONE);
        address source = address(new MockStorageSource());
        DeploySuite memory suite = cloneSuite(
            LibRainDeploy.zoltuAddress(type(MockStorageReadingCloneable).creationCode),
            type(MockStorageReadingCloneable).runtimeCode,
            abi.encode(source, SourceUse.Read)
        );
        vm.expectRevert(
            abi.encodeWithSelector(CloneInitializeReadsStorage.selector, suite.suite, source, bytes32(uint256(1)))
        );
        this.externalDeployLocallyOnChain(suite);
    }

    /// On the fork, an account answering `getV5` whose code is not exactly `ConfigRegistry`'s is refused: a stand-in,
    /// and the deployed registry's own address and bindings under its code with one byte appended.
    function testCloneInitializeReadingRegistryLikeCodeOnItsForkIsRefused() external {
        vm.createSelectFork(LibRainDeploy.ARBITRUM_ONE);

        TestRegistryBeaconSource standIn = new TestRegistryBeaconSource();
        standIn.bind(AUTHORITY, NAME, "bytes", "stand-in binding");
        assertOnChainReadRefused(address(standIn));

        bind(REGISTRY, "arbitrum binding");
        vm.etch(REGISTRY, bytes.concat(REGISTRY.code, hex"00"));
        assertOnChainReadRefused(REGISTRY);
    }

    /// On the fork, an exact copy of the deployed `ConfigRegistry`'s code at another address is refused.
    function testCloneInitializeReadingAConfigRegistryCopyOnItsForkIsRefused() external {
        vm.createSelectFork(LibRainDeploy.ARBITRUM_ONE);
        address copy = makeAddr("config registry copy");
        vm.etch(copy, REGISTRY.code);
        assertEq(copy.codehash, LibConfigRegistryDeploy.CONFIG_REGISTRY_DEPLOYED_CODEHASH);
        bind(copy, "copy binding");
        assertOnChainReadRefused(copy);
    }

    /// On the fork, the deployed `ConfigRegistry`'s address running other code is refused.
    function testCloneInitializeReadingOtherCodeAtTheConfigRegistryOnItsForkIsRefused() external {
        vm.createSelectFork(LibRainDeploy.ARBITRUM_ONE);
        vm.etch(REGISTRY, type(TestRegistryBeaconSource).runtimeCode);
        TestRegistryBeaconSource(REGISTRY).bind(AUTHORITY, NAME, "bytes", "other code binding");
        assertOnChainReadRefused(REGISTRY);
    }
}
