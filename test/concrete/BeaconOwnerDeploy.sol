// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    DeployCandidate,
    DeployDeclaration,
    DeploySuite
} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.29/src/lib/LibRainDeployDeclaration.sol";
import {LibRainDeployZoltuMechanism} from "rain-deploy-0.1.29/src/lib/LibRainDeployZoltuMechanism.sol";
import {ChainBeacon, DeployBeacon} from "../../src/lib/LibRainDeployBeacon.sol";
import {LibRainDeployCloneMechanism} from "../../src/lib/LibRainDeployCloneMechanism.sol";
import {ExternalDeployBroadcast} from "../abstract/ExternalDeployBroadcast.sol";
import {LibBeaconDeclarations} from "../lib/LibBeaconDeclarations.sol";
import {LibBeaconTest} from "../lib/LibBeaconTest.sol";
import {MockDeployable} from "./MockDeployable.sol";

/// @dev The one release `BeaconOwnerDeploy` declares.
string constant BEACON_OWNER_DEPLOY_RELEASE = "deployable@0_0_1";

/// @title BeaconOwnerDeploy
/// @notice A broadcast script releasing and proposing one Zoltu suite on every supported network, beside the beacons
/// a test declares on it.
contract BeaconOwnerDeploy is ExternalDeployBroadcast {
    using LibBeaconDeclarations for ChainBeacon[];

    ChainBeacon[] internal sBeacons;

    function declaration() internal view override returns (DeployDeclaration memory) {
        DeployDeclaration memory d;
        LibRainDeployDeclaration.extend(d);
        LibRainDeployZoltuMechanism.extend(d);
        LibRainDeployCloneMechanism.extend(d);
        LibRainDeployCloneMechanism.setBeacons(d, sBeacons);
        DeploySuite[] memory released = new DeploySuite[](1);
        released[0] = LibBeaconTest.zoltuSuite(
            BEACON_OWNER_DEPLOY_RELEASE,
            type(MockDeployable).creationCode,
            type(MockDeployable).runtimeCode,
            "test/concrete/MockDeployable.sol:MockDeployable"
        );
        LibRainDeployDeclaration.addReleased(d, released);
        DeployCandidate[] memory candidates = new DeployCandidate[](1);
        candidates[0] = DeployCandidate({
            snapshot: LibBeaconTest.zoltuSuite(
                "deployable",
                type(MockDeployable).creationCode,
                type(MockDeployable).runtimeCode,
                "test/concrete/MockDeployable.sol:MockDeployable"
            ),
            unanchorableReason: ""
        });
        LibRainDeployDeclaration.addCandidates(d, candidates);
        return d;
    }

    /// @param chainId The network the beacon is on.
    /// @param beacon The beacon.
    function declareBeacon(uint256 chainId, DeployBeacon memory beacon) external {
        sBeacons.declare(chainId, beacon);
    }
}
