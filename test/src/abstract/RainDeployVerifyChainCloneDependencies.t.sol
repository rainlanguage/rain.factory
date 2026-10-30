// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {DeployDeclaration, RainDeploySuitesBase} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {RainDeployVerifyChain} from "rain-deploy-0.1.29/src/abstract/RainDeployVerifyChain.sol";
import {LibRainDeploy} from "rain-deploy-0.1.29/src/lib/LibRainDeploy.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.29/src/lib/LibRainDeployDeclaration.sol";
import {LibCloneCandidates} from "../../../src/lib/LibCloneCandidates.sol";
import {
    PerNetworkCloneDeploys,
    etchPerNetworkCloneRelease,
    perNetworkCloneDeploys,
    perNetworkCloneLayers,
    perNetworkCloneReleased
} from "../../abstract/PerNetworkCloneDeploys.sol";
import {exampleCloneImplementation} from "../../abstract/ExampleCloneDeploys.sol";
import {MockCloneFactory} from "../../concrete/MockCloneFactory.sol";
import {MockCloneable} from "../../concrete/MockCloneable.sol";

/// @title RainDeployVerifyChainCloneDependenciesTest
/// @notice The chain matrix holds a per-network clone release's declared dependencies to the code declared for them
/// on each network, before the clone's own address.
contract RainDeployVerifyChainCloneDependenciesTest is PerNetworkCloneDeploys, RainDeployVerifyChain {
    /// Puts the release's dependencies, and its clone at its address for each network, on every fork.
    function setUp() external {
        DeployDeclaration memory d = declaration();
        etchPerNetworkCloneRelease(vm, d.released[0], deployedAddresses(d, d.released[0]));
    }

    /// The per-network clone release, checked on Polygon then Arbitrum One.
    function declaration()
        internal
        view
        override(PerNetworkCloneDeploys, RainDeploySuitesBase)
        returns (DeployDeclaration memory)
    {
        DeployDeclaration memory d = perNetworkCloneLayers();
        string[] memory networks = new string[](2);
        networks[0] = LibRainDeploy.POLYGON;
        networks[1] = LibRainDeploy.ARBITRUM_ONE;
        LibRainDeployDeclaration.setNetworks(d, networks);
        LibRainDeployDeclaration.addReleased(d, perNetworkCloneReleased());
        LibCloneCandidates.addClones(d, perNetworkCloneDeploys());
        return d;
    }

    /// Without the implementation the matrix refuses on the first network, naming it as the missing
    /// dependency, though the clone is at its address.
    function testMissingImplementationIsRefusedNamingNetworkAndDependency() external {
        vm.etch(exampleCloneImplementation(), hex"");
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRainDeploy.MissingDependency.selector, LibRainDeploy.POLYGON, exampleCloneImplementation()
            )
        );
        this.testSuitesLiveOnEverySupportedNetwork();
    }

    /// With other code at the implementation's address the matrix refuses on the first network,
    /// naming the dependency and both code hashes.
    function testChangedImplementationIsRefusedNamingNetworkAndDependency() external {
        vm.etch(exampleCloneImplementation(), type(MockCloneFactory).runtimeCode);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRainDeploy.DependencyChanged.selector,
                LibRainDeploy.POLYGON,
                exampleCloneImplementation(),
                keccak256(type(MockCloneable).runtimeCode),
                keccak256(type(MockCloneFactory).runtimeCode)
            )
        );
        this.testSuitesLiveOnEverySupportedNetwork();
    }
}
