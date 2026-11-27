// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {
    DependencyCycle,
    DeployDeclaration,
    DeployDependency,
    DeploySuite,
    ExternalDeployment
} from "rain-deploy-0.1.43/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeploy} from "rain-deploy-0.1.43/src/lib/LibRainDeploy.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.43/src/lib/LibRainDeployDeclaration.sol";
import {LibRainDeployZoltuMechanism} from "rain-deploy-0.1.43/src/lib/LibRainDeployZoltuMechanism.sol";
import {CloneDeploy, CloneParams, LibRainDeployClone} from "../../../src/lib/LibRainDeployClone.sol";
import {LibRainDeployCloneMechanism} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {
    exampleCloneDependencies,
    exampleCloneFactory,
    exampleCloneImplementation
} from "../../abstract/ExampleCloneDeploys.sol";
import {
    PER_NETWORK_CLONE_ARBITRUM_ONE_CHAIN_ID,
    PER_NETWORK_CLONE_POLYGON_CHAIN_ID,
    perNetworkClone,
    perNetworkCloneChainIds,
    perNetworkCloneInitData,
    perNetworkCloneNetworks
} from "../../abstract/PerNetworkCloneDeploys.sol";
import {MockCloneFactory} from "../../concrete/MockCloneFactory.sol";
import {MockCloneable} from "../../concrete/MockCloneable.sol";
import {MockDeployable} from "../../concrete/MockDeployable.sol";

/// @title LibRainDeployCloneMechanismDependencyClosureTest
/// @notice A clone's local deploys etch its dependencies' own dependencies, and refuse a closure reaching the clone.
contract LibRainDeployCloneMechanismDependencyClosureTest is Test {
    bytes32 constant SALT = bytes32(uint256(11));

    function externalDeployLocally(DeploySuite memory suite, DeployDependency memory reached)
        external
        returns (address[] memory)
    {
        return LibRainDeployCloneMechanism.deployLocally(implementationReaching(reached), vm, suite);
    }

    function externalDeployLocallyOnChain(DeploySuite memory suite, DeployDependency memory reached) external {
        LibRainDeployCloneMechanism.deployLocallyOnChain(implementationReaching(reached), vm, suite);
    }

    /// The example factory as an external deployment and the example implementation as a Zoltu release that itself
    /// depends on `reached`, an external deployment.
    function implementationReaching(DeployDependency memory reached) internal view returns (DeployDeclaration memory) {
        DeployDeclaration memory d;
        LibRainDeployZoltuMechanism.extend(d);
        LibRainDeployCloneMechanism.extend(d);
        DeployDependency[] memory implementationDependencies = new DeployDependency[](1);
        implementationDependencies[0] = reached;
        DeploySuite[] memory released = new DeploySuite[](1);
        released[0] = DeploySuite({
            suite: "implementation@0_0_1",
            creationCode: type(MockCloneable).creationCode,
            storedDeployedAddress: exampleCloneImplementation(),
            storedBytecodeHash: keccak256(type(MockCloneable).runtimeCode),
            storedRuntimeCode: type(MockCloneable).runtimeCode,
            artifactPath: "test/concrete/MockCloneable.sol:MockCloneable",
            dependencies: implementationDependencies,
            mechanismData: LibRainDeployZoltuMechanism.mechanismData(),
            networks: perNetworkCloneNetworks(),
            describedByMeta: ""
        });
        LibRainDeployDeclaration.addReleased(d, released);
        d.externalDeployments = new ExternalDeployment[](2);
        d.externalDeployments[0] = ExternalDeployment({
            deployedAddress: exampleCloneFactory(), codeHash: keccak256(type(MockCloneFactory).runtimeCode)
        });
        d.externalDeployments[1] =
            ExternalDeployment({deployedAddress: reached.deployedAddress, codeHash: keccak256(reached.runtimeCode)});
        return d;
    }

    function mockDeployable() internal pure returns (DeployDependency memory) {
        return DeployDependency({
            deployedAddress: LibRainDeploy.zoltuAddress(type(MockDeployable).creationCode),
            runtimeCode: type(MockDeployable).runtimeCode
        });
    }

    function oneDataSuite() internal view returns (DeploySuite memory) {
        CloneDeploy memory clone = CloneDeploy({
            suite: "one-data",
            factory: exampleCloneFactory(),
            implementation: exampleCloneImplementation(),
            data: hex"01",
            initDataPerNetwork: false,
            initData: LibRainDeployClone.noInitDataPerNetwork,
            salt: SALT,
            dependencies: exampleCloneDependencies()
        });
        DeploySuite memory suite = LibRainDeployCloneMechanism.cloneCandidate(clone, new uint256[](0)).snapshot;
        suite.networks = perNetworkCloneNetworks();
        return suite;
    }

    function perNetworkSuite() internal view returns (DeploySuite memory) {
        DeploySuite memory suite =
        LibRainDeployCloneMechanism.cloneCandidate(perNetworkClone("per-network", SALT), perNetworkCloneChainIds())
        .snapshot;
        suite.networks = perNetworkCloneNetworks();
        return suite;
    }

    function perNetworkAddress(uint256 chainId) internal pure returns (address) {
        return LibRainDeployClone.cloneDeployedAddress(
            CloneParams({
                factory: exampleCloneFactory(),
                implementation: exampleCloneImplementation(),
                data: perNetworkCloneInitData(chainId),
                salt: SALT
            })
        );
    }

    function ownAt(address deployedAddress, bytes memory runtimeCode) internal pure returns (DeployDependency memory) {
        return DeployDependency({deployedAddress: deployedAddress, runtimeCode: runtimeCode});
    }

    function testOneDataCloneDeployLocallyEtchesItsDependenciesDependencies() external {
        DeploySuite memory suite = oneDataSuite();
        DeployDependency memory reached = mockDeployable();
        assertEq(reached.deployedAddress.code.length, 0);

        address[] memory deployed = this.externalDeployLocally(suite, reached);
        assertEq(reached.deployedAddress.code, reached.runtimeCode);
        assertEq(exampleCloneFactory().code, type(MockCloneFactory).runtimeCode);
        assertEq(exampleCloneImplementation().code, type(MockCloneable).runtimeCode);
        assertEq(deployed[0].code, suite.storedRuntimeCode);
    }

    function testPerNetworkCloneDeployLocallyEtchesItsDependenciesDependencies() external {
        DeploySuite memory suite = perNetworkSuite();
        DeployDependency memory reached = mockDeployable();
        assertEq(reached.deployedAddress.code.length, 0);

        address[] memory deployed = this.externalDeployLocally(suite, reached);
        assertEq(reached.deployedAddress.code, reached.runtimeCode);
        assertEq(deployed[0], perNetworkAddress(PER_NETWORK_CLONE_ARBITRUM_ONE_CHAIN_ID));
        assertEq(deployed[1], perNetworkAddress(PER_NETWORK_CLONE_POLYGON_CHAIN_ID));
        assertEq(deployed[0].code, suite.storedRuntimeCode);
        assertEq(deployed[1].code, suite.storedRuntimeCode);
    }

    function testCloneDeployLocallyOnChainEtchesItsDependenciesDependencies() external {
        DeploySuite memory suite = perNetworkSuite();
        DeployDependency memory reached = mockDeployable();
        assertEq(reached.deployedAddress.code.length, 0);

        vm.chainId(PER_NETWORK_CLONE_POLYGON_CHAIN_ID);
        this.externalDeployLocallyOnChain(suite, reached);
        assertEq(reached.deployedAddress.code, reached.runtimeCode);
        assertEq(perNetworkAddress(PER_NETWORK_CLONE_POLYGON_CHAIN_ID).code, suite.storedRuntimeCode);
    }

    function testOneDataCloneWhoseClosureReachesItIsACycle() external {
        DeploySuite memory suite = oneDataSuite();
        DeployDependency memory reached = ownAt(suite.storedDeployedAddress, suite.storedRuntimeCode);

        vm.expectRevert(abi.encodeWithSelector(DependencyCycle.selector, suite.suite));
        this.externalDeployLocally(suite, reached);
        vm.chainId(PER_NETWORK_CLONE_ARBITRUM_ONE_CHAIN_ID);
        vm.expectRevert(abi.encodeWithSelector(DependencyCycle.selector, suite.suite));
        this.externalDeployLocallyOnChain(suite, reached);
        assertEq(suite.storedDeployedAddress.code.length, 0);
    }

    /// Every in-play network's clone is the suite's own, not only the first.
    function testPerNetworkCloneWhoseClosureReachesAnyNetworksCloneIsACycle() external {
        DeploySuite memory suite = perNetworkSuite();
        uint256[] memory chainIds = perNetworkCloneChainIds();
        for (uint256 i = 0; i < chainIds.length; i++) {
            DeployDependency memory reached = ownAt(perNetworkAddress(chainIds[i]), suite.storedRuntimeCode);
            vm.expectRevert(abi.encodeWithSelector(DependencyCycle.selector, suite.suite));
            this.externalDeployLocally(suite, reached);
        }
    }

    function testPerNetworkCloneOnChainWhoseClosureReachesThatNetworksCloneIsACycle() external {
        DeploySuite memory suite = perNetworkSuite();
        DeployDependency memory reached =
            ownAt(perNetworkAddress(PER_NETWORK_CLONE_POLYGON_CHAIN_ID), suite.storedRuntimeCode);

        vm.chainId(PER_NETWORK_CLONE_POLYGON_CHAIN_ID);
        vm.expectRevert(abi.encodeWithSelector(DependencyCycle.selector, suite.suite));
        this.externalDeployLocallyOnChain(suite, reached);
    }
}
