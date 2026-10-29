// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {DeployCandidate, DeployDeclaration} from "rain-deploy-0.1.27/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.27/src/lib/LibRainDeployDeclaration.sol";
import {LibRainDeployZoltuMechanism} from "rain-deploy-0.1.27/src/lib/LibRainDeployZoltuMechanism.sol";
import {BeaconProxyDeploy} from "../../src/lib/LibRainDeployBeaconProxy.sol";
import {LibRainDeployCloneMechanism} from "../../src/lib/LibRainDeployCloneMechanism.sol";
import {ExternalDeploySuites} from "../abstract/ExternalDeploySuites.sol";
import {LibBeaconProxyTest} from "../lib/LibBeaconProxyTest.sol";
import {LibCloneCandidates} from "../lib/LibCloneCandidates.sol";

/// @title BeaconProxyOnlyDeploySuites
/// @notice A declaration whose only suite is one beacon proxy candidate: no release, no clone.
contract BeaconProxyOnlyDeploySuites is ExternalDeploySuites {
    function beaconProxyDeploys() internal pure returns (BeaconProxyDeploy[] memory) {
        BeaconProxyDeploy[] memory proxies = new BeaconProxyDeploy[](1);
        proxies[0] = LibBeaconProxyTest.example(bytes32(uint256(7)));
        return proxies;
    }

    function declaration() internal view override returns (DeployDeclaration memory) {
        DeployDeclaration memory d;
        LibRainDeployDeclaration.extend(d);
        LibRainDeployZoltuMechanism.extend(d);
        LibRainDeployCloneMechanism.extend(d);
        LibCloneCandidates.addBeaconProxies(d, beaconProxyDeploys());
        return d;
    }

    /// @return How many beacon proxies the declaration lists.
    function externalBeaconProxyDeploysLength() external pure returns (uint256) {
        return beaconProxyDeploys().length;
    }

    /// @param index The beacon proxy's index in the list.
    /// @return Its candidate, derived on its own over the declaration's networks.
    function externalBeaconProxyDeployCandidate(uint256 index) external view returns (DeployCandidate memory) {
        return LibRainDeployCloneMechanism.beaconProxyCandidate(
            beaconProxyDeploys()[index], LibCloneCandidates.chainIds(declaration())
        );
    }
}
