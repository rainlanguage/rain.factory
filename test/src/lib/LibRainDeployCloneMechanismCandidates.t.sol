// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {
    DeployCandidate,
    DeployDeclaration,
    DeploySuite
} from "rain-deploy-0.1.27/src/abstract/RainDeploySuitesBase.sol";
import {BEACON_PROXY_ARTIFACT_PATH} from "../../../src/lib/LibRainDeployBeaconProxy.sol";
import {CLONE_ARTIFACT_PATH, CloneDeploy} from "../../../src/lib/LibRainDeployClone.sol";
import {BEACON_PROXY_MECHANISM, LibRainDeployCloneMechanism} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {exampleCloneDeploys} from "../../abstract/ExampleCloneDeploys.sol";
import {BeaconProxyOnlyDeploySuites} from "../../concrete/BeaconProxyOnlyDeploySuites.sol";
import {ExampleCloneDeploy} from "../../concrete/ExampleCloneDeploy.sol";
import {MixedCloneBeaconProxyDeploySuites} from "../../concrete/MixedCloneBeaconProxyDeploySuites.sol";
import {LibCloneCandidates} from "../../lib/LibCloneCandidates.sol";

/// @title LibRainDeployCloneMechanismCandidatesTest
/// @notice A declaration's clone and beacon proxy candidates, as the suite readers see them: the clone and beacon
/// proxy lists derived, in order, one for one.
contract LibRainDeployCloneMechanismCandidatesTest is Test {
    /// The candidates MUST be `cloneCandidate` mapped over the declared clones, in order and one for one.
    function testCandidatesAreTheCloneListDerived() external {
        ExampleCloneDeploy fixtureDeploy = new ExampleCloneDeploy();

        CloneDeploy[] memory cloneDeploys = exampleCloneDeploys();
        uint256 clones = cloneDeploys.length;
        DeployCandidate[] memory candidates = fixtureDeploy.externalCheckedCandidateSuites();

        assertEq(candidates.length, clones, "one candidate per clone");
        assertEq(clones, 2, "the fixture declares two, so a loop that stops early is visible");

        DeployDeclaration memory networks;
        networks.networks = fixtureDeploy.externalNetworks();
        uint256[] memory chainIds = LibCloneCandidates.chainIds(networks);
        for (uint256 i = 0; i < clones; i++) {
            DeployCandidate memory derived = LibRainDeployCloneMechanism.cloneCandidate(cloneDeploys[i], chainIds);
            assertEq(candidates[i].snapshot.suite, derived.snapshot.suite);
            assertEq(candidates[i].snapshot.creationCode, derived.snapshot.creationCode);
            assertEq(candidates[i].snapshot.storedDeployedAddress, derived.snapshot.storedDeployedAddress);
            assertEq(candidates[i].snapshot.storedBytecodeHash, derived.snapshot.storedBytecodeHash);
            assertEq(candidates[i].snapshot.storedRuntimeCode, derived.snapshot.storedRuntimeCode);
            assertEq(candidates[i].snapshot.artifactPath, CLONE_ARTIFACT_PATH);
            assertEq(candidates[i].snapshot.mechanismData, derived.snapshot.mechanismData);
            assertEq(candidates[i].snapshot.dependencies.length, derived.snapshot.dependencies.length);
            assertEq(candidates[i].unanchorableReason, derived.unanchorableReason);
        }

        assertNotEq(candidates[0].snapshot.storedDeployedAddress, candidates[1].snapshot.storedDeployedAddress);
    }

    /// The derived candidates MUST satisfy `checkCandidatesAnchoredToSource`, the qualifier rule included.
    function testCloneCandidatesPassTheSourceAnchor() external {
        ExampleCloneDeploy fixtureDeploy = new ExampleCloneDeploy();
        fixtureDeploy.externalCheckCandidatesAnchoredToSource();
    }

    /// @param actual The candidate read.
    /// @param expected The candidate derived on its own.
    function assertSameCandidate(DeployCandidate memory actual, DeployCandidate memory expected) internal pure {
        assertEq(actual.snapshot.suite, expected.snapshot.suite);
        assertEq(actual.snapshot.creationCode, expected.snapshot.creationCode);
        assertEq(actual.snapshot.storedDeployedAddress, expected.snapshot.storedDeployedAddress);
        assertEq(actual.snapshot.storedBytecodeHash, expected.snapshot.storedBytecodeHash);
        assertEq(actual.snapshot.storedRuntimeCode, expected.snapshot.storedRuntimeCode);
        assertEq(actual.snapshot.artifactPath, expected.snapshot.artifactPath);
        assertEq(actual.snapshot.mechanismData, expected.snapshot.mechanismData);
        assertEq(abi.encode(actual.snapshot.dependencies), abi.encode(expected.snapshot.dependencies));
        assertEq(actual.snapshot.networks, expected.snapshot.networks);
        assertEq(actual.unanchorableReason, expected.unanchorableReason);
    }

    /// With no clones, the candidates MUST be `beaconProxyCandidate` mapped over the declared beacon proxies, and
    /// every reader of them answers.
    function testCandidatesAreTheBeaconProxyListDerived() external {
        BeaconProxyOnlyDeploySuites deploy = new BeaconProxyOnlyDeploySuites();
        assertEq(deploy.externalBeaconProxyDeploysLength(), 1);

        DeployCandidate[] memory candidates = deploy.externalCheckedCandidateSuites();
        assertEq(candidates.length, 1);
        assertSameCandidate(candidates[0], deploy.externalBeaconProxyDeployCandidate(0));
        assertEq(LibRainDeployCloneMechanism.mechanismTag(candidates[0].snapshot.mechanismData), BEACON_PROXY_MECHANISM);
        assertEq(candidates[0].snapshot.artifactPath, BEACON_PROXY_ARTIFACT_PATH);

        deploy.externalCheckCandidatesAnchoredToSource();
        DeploySuite[] memory suites = deploy.externalAllSuites();
        assertEq(suites.length, 1);
        assertEq(suites[0].suite, "example-beacon-proxy");
        assertEq(deploy.externalSuiteNames(), "example-beacon-proxy");
    }

    /// With both, the candidates MUST be the clones' candidates, in order, then the beacon proxies'.
    function testCandidatesAreTheClonesThenTheBeaconProxies() external {
        MixedCloneBeaconProxyDeploySuites deploy = new MixedCloneBeaconProxyDeploySuites();
        uint256 clones = deploy.externalCloneDeploysLength();
        uint256 proxies = deploy.externalBeaconProxyDeploysLength();
        assertEq(clones, 2);
        assertEq(proxies, 2);

        DeployCandidate[] memory candidates = deploy.externalCheckedCandidateSuites();
        assertEq(candidates.length, clones + proxies);
        for (uint256 i = 0; i < clones; i++) {
            assertSameCandidate(candidates[i], deploy.externalCloneDeployCandidate(i));
        }
        for (uint256 i = 0; i < proxies; i++) {
            assertSameCandidate(candidates[clones + i], deploy.externalBeaconProxyDeployCandidate(i));
            assertEq(
                LibRainDeployCloneMechanism.mechanismTag(candidates[clones + i].snapshot.mechanismData),
                BEACON_PROXY_MECHANISM
            );
        }
        assertNotEq(candidates[2].snapshot.storedDeployedAddress, candidates[3].snapshot.storedDeployedAddress);
        deploy.externalCheckCandidatesAnchoredToSource();
    }
}
