// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    DeployCandidate,
    DeployDeclaration,
    DeployDependency,
    ExternalDeployment
} from "rain-deploy-0.1.27/src/abstract/RainDeploySuitesBase.sol";
import {
    RainDeployDeclarationChecks,
    UndeclaredDependency
} from "rain-deploy-0.1.27/src/abstract/RainDeployDeclarationChecks.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.27/src/lib/LibRainDeployDeclaration.sol";
import {LibRainDeployZoltuMechanism} from "rain-deploy-0.1.27/src/lib/LibRainDeployZoltuMechanism.sol";
import {CloneDeploy, LibRainDeployClone} from "../../../src/lib/LibRainDeployClone.sol";
import {LibRainDeployCloneMechanism} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {
    exampleCloneDependencies,
    exampleCloneFactory,
    exampleCloneImplementation
} from "../../abstract/ExampleCloneDeploys.sol";
import {MockCloneFactory} from "../../concrete/MockCloneFactory.sol";
import {MockCloneable} from "../../concrete/MockCloneable.sol";

/// @title RainDeployVerifyDeclarationCloneTest
/// @notice The declaration checks over a clone candidate whose factory is reached only through its mechanism data.
contract RainDeployVerifyDeclarationCloneTest is RainDeployDeclarationChecks {
    /// Whether the clone candidate declares only its implementation.
    bool internal sUndeclaredMechanismDependency;

    function declaration() internal view override returns (DeployDeclaration memory) {
        DeployDeclaration memory d;
        LibRainDeployDeclaration.extend(d);
        LibRainDeployZoltuMechanism.extend(d);
        LibRainDeployCloneMechanism.extend(d);
        DeployCandidate[] memory candidates = new DeployCandidate[](1);
        candidates[0] = LibRainDeployCloneMechanism.cloneCandidate(
            CloneDeploy({
                suite: "mock-clone",
                factory: exampleCloneFactory(),
                implementation: exampleCloneImplementation(),
                data: "",
                initDataPerNetwork: false,
                initData: LibRainDeployClone.noInitDataPerNetwork,
                salt: bytes32(uint256(1)),
                dependencies: exampleCloneDependencies()
            }),
            new uint256[](0)
        );
        if (sUndeclaredMechanismDependency) {
            DeployDependency[] memory deps = new DeployDependency[](1);
            deps[0] = candidates[0].snapshot.dependencies[1];
            candidates[0].snapshot.dependencies = deps;
        }
        LibRainDeployDeclaration.addCandidates(d, candidates);
        d.externalDeployments = new ExternalDeployment[](2);
        d.externalDeployments[0] = ExternalDeployment({
            deployedAddress: exampleCloneImplementation(), codeHash: keccak256(type(MockCloneable).runtimeCode)
        });
        d.externalDeployments[1] = ExternalDeployment({
            deployedAddress: exampleCloneFactory(), codeHash: keccak256(type(MockCloneFactory).runtimeCode)
        });
        return d;
    }

    function externalCheckDependenciesAreTheEmbeddedDeployments() external view {
        checkDependenciesAreTheEmbeddedDeployments(declaration());
    }

    function testUndeclaredDependencyInMechanismData() external {
        sUndeclaredMechanismDependency = true;
        vm.expectRevert(abi.encodeWithSelector(UndeclaredDependency.selector, "mock-clone", exampleCloneFactory()));
        this.externalCheckDependenciesAreTheEmbeddedDeployments();
    }
}
