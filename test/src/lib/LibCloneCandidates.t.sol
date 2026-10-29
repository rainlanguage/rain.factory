// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {DeployCandidate, DeployDeclaration} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.29/src/lib/LibRainDeployDeclaration.sol";
import {BeaconProxyDeploy} from "../../../src/lib/LibRainDeployBeaconProxy.sol";
import {CloneDeploy} from "../../../src/lib/LibRainDeployClone.sol";
import {LibRainDeployCloneMechanism} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {LibCloneCandidates, NoFactoryDeploys} from "../../../src/lib/LibCloneCandidates.sol";
import {exampleCloneDeploys} from "../../abstract/ExampleCloneDeploys.sol";
import {LibBeaconProxyTest} from "../../lib/LibBeaconProxyTest.sol";

/// @title LibCloneCandidatesTest
/// @notice An empty clone or beacon proxy list is refused where it is added, and a non-empty one appends a candidate
/// per entry, in order, after the candidates already declared.
contract LibCloneCandidatesTest is Test {
    function declaration() internal pure returns (DeployDeclaration memory) {
        DeployDeclaration memory d;
        LibRainDeployDeclaration.extend(d);
        return d;
    }

    function beaconProxyDeploys() internal pure returns (BeaconProxyDeploy[] memory) {
        BeaconProxyDeploy[] memory proxies = new BeaconProxyDeploy[](2);
        proxies[0] = LibBeaconProxyTest.example(bytes32(uint256(7)));
        proxies[1] = LibBeaconProxyTest.example(bytes32(uint256(8)));
        proxies[1].suite = "example-beacon-proxy-second-salt";
        return proxies;
    }

    function externalAddNoClones() external view {
        LibCloneCandidates.addClones(declaration(), new CloneDeploy[](0));
    }

    function externalAddNoBeaconProxies() external view {
        LibCloneCandidates.addBeaconProxies(declaration(), new BeaconProxyDeploy[](0));
    }

    /// @param actual The candidate added.
    /// @param expected The candidate derived on its own, before the declaration fills its networks.
    /// @param networks The declaration's networks.
    function assertAddedCandidate(
        DeployCandidate memory actual,
        DeployCandidate memory expected,
        string[] memory networks
    ) internal pure {
        assertEq(actual.snapshot.networks, networks, "built for the declaration's networks");
        expected.snapshot.networks = networks;
        assertEq(abi.encode(actual), abi.encode(expected));
    }

    function testAddClonesRefusesAnEmptyList() external {
        vm.expectRevert(abi.encodeWithSelector(NoFactoryDeploys.selector));
        this.externalAddNoClones();
    }

    function testAddBeaconProxiesRefusesAnEmptyList() external {
        vm.expectRevert(abi.encodeWithSelector(NoFactoryDeploys.selector));
        this.externalAddNoBeaconProxies();
    }

    function testAddClonesAppendsACandidatePerCloneInOrder() external view {
        DeployDeclaration memory d = declaration();
        BeaconProxyDeploy[] memory proxies = beaconProxyDeploys();
        LibCloneCandidates.addBeaconProxies(d, proxies);
        DeployCandidate memory prior = d.candidates[0];

        CloneDeploy[] memory clones = exampleCloneDeploys();
        assertEq(clones.length, 2, "two, so a loop that stops early is visible");
        LibCloneCandidates.addClones(d, clones);

        uint256[] memory ids = LibCloneCandidates.chainIds(d);
        assertEq(d.candidates.length, proxies.length + clones.length);
        assertEq(abi.encode(d.candidates[0]), abi.encode(prior), "earlier candidates kept");
        for (uint256 i = 0; i < clones.length; i++) {
            assertAddedCandidate(
                d.candidates[proxies.length + i],
                LibRainDeployCloneMechanism.cloneCandidate(clones[i], ids),
                d.networks
            );
        }
        assertNotEq(d.candidates[2].snapshot.storedDeployedAddress, d.candidates[3].snapshot.storedDeployedAddress);
    }

    function testAddBeaconProxiesAppendsACandidatePerBeaconProxyInOrder() external view {
        DeployDeclaration memory d = declaration();
        CloneDeploy[] memory clones = exampleCloneDeploys();
        LibCloneCandidates.addClones(d, clones);
        DeployCandidate memory prior = d.candidates[0];

        BeaconProxyDeploy[] memory proxies = beaconProxyDeploys();
        assertEq(proxies.length, 2, "two, so a loop that stops early is visible");
        LibCloneCandidates.addBeaconProxies(d, proxies);

        uint256[] memory ids = LibCloneCandidates.chainIds(d);
        assertEq(d.candidates.length, clones.length + proxies.length);
        assertEq(abi.encode(d.candidates[0]), abi.encode(prior), "earlier candidates kept");
        for (uint256 i = 0; i < proxies.length; i++) {
            assertAddedCandidate(
                d.candidates[clones.length + i],
                LibRainDeployCloneMechanism.beaconProxyCandidate(proxies[i], ids),
                d.networks
            );
        }
        assertNotEq(d.candidates[2].snapshot.storedDeployedAddress, d.candidates[3].snapshot.storedDeployedAddress);
    }
}
