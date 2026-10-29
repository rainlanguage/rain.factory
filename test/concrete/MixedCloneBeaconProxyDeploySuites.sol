// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {DeployCandidate, DeployDeclaration} from "rain-deploy-0.1.27/src/abstract/RainDeploySuitesBase.sol";
import {BeaconProxyDeploy} from "../../src/lib/LibRainDeployBeaconProxy.sol";
import {LibRainDeployCloneMechanism} from "../../src/lib/LibRainDeployCloneMechanism.sol";
import {ExampleCloneDeploys, exampleCloneDeploys} from "../abstract/ExampleCloneDeploys.sol";
import {ExternalDeploySuites} from "../abstract/ExternalDeploySuites.sol";
import {LibBeaconProxyTest} from "../lib/LibBeaconProxyTest.sol";
import {LibCloneCandidates} from "../lib/LibCloneCandidates.sol";

/// @title MixedCloneBeaconProxyDeploySuites
/// @notice The example clone declaration with two beacon proxy candidates added after its clones.
contract MixedCloneBeaconProxyDeploySuites is ExampleCloneDeploys, ExternalDeploySuites {
    function beaconProxyDeploys() internal pure returns (BeaconProxyDeploy[] memory) {
        BeaconProxyDeploy[] memory proxies = new BeaconProxyDeploy[](2);
        proxies[0] = LibBeaconProxyTest.example(bytes32(uint256(7)));
        proxies[1] = LibBeaconProxyTest.example(bytes32(uint256(8)));
        proxies[1].suite = "example-beacon-proxy-second-salt";
        return proxies;
    }

    function declaration() internal view override returns (DeployDeclaration memory) {
        DeployDeclaration memory d = ExampleCloneDeploys.declaration();
        LibCloneCandidates.addBeaconProxies(d, beaconProxyDeploys());
        return d;
    }

    /// @return How many clones the declaration lists.
    function externalCloneDeploysLength() external pure returns (uint256) {
        return exampleCloneDeploys().length;
    }

    /// @return How many beacon proxies the declaration lists.
    function externalBeaconProxyDeploysLength() external pure returns (uint256) {
        return beaconProxyDeploys().length;
    }

    /// @param index The clone's index in the list.
    /// @return Its candidate, derived on its own over the declaration's networks.
    function externalCloneDeployCandidate(uint256 index) external view returns (DeployCandidate memory) {
        return LibRainDeployCloneMechanism.cloneCandidate(
            exampleCloneDeploys()[index], LibCloneCandidates.chainIds(declaration())
        );
    }

    /// @param index The beacon proxy's index in the list.
    /// @return Its candidate, derived on its own over the declaration's networks.
    function externalBeaconProxyDeployCandidate(uint256 index) external view returns (DeployCandidate memory) {
        return LibRainDeployCloneMechanism.beaconProxyCandidate(
            beaconProxyDeploys()[index], LibCloneCandidates.chainIds(declaration())
        );
    }
}
