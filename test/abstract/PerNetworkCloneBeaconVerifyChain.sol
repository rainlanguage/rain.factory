// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {
    DeployDeclaration,
    DeployDependency,
    DeploySuite
} from "rain-deploy-0.1.42/src/abstract/RainDeploySuitesBase.sol";
import {RainDeployVerifyChain} from "rain-deploy-0.1.42/src/abstract/RainDeployVerifyChain.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.42/src/lib/LibRainDeployDeclaration.sol";
import {LibRainDeploySnapshot} from "rain-deploy-0.1.42/src/lib/LibRainDeploySnapshot.sol";
import {LibRainDeployZoltuMechanism} from "rain-deploy-0.1.42/src/lib/LibRainDeployZoltuMechanism.sol";
import {BeaconState, ChainBeacon} from "../../src/lib/LibRainDeployBeacon.sol";
import {LibRainDeployCloneMechanism} from "../../src/lib/LibRainDeployCloneMechanism.sol";
import {LibCloneCandidates} from "../../src/lib/LibCloneCandidates.sol";
import {LibExternalDeployments} from "../lib/LibExternalDeployments.sol";
import {exampleCloneDependencies} from "./ExampleCloneDeploys.sol";
import {
    PER_NETWORK_CLONE_POLYGON_CHAIN_ID,
    perNetworkCloneDeploys,
    perNetworkCloneNetworks,
    perNetworkCloneReleased
} from "./PerNetworkCloneDeploys.sol";

/// @title PerNetworkCloneBeaconVerifyChain
/// @notice The chain group over the per-network clone declaration with a beacon on Polygon at the release's Polygon
/// clone.
abstract contract PerNetworkCloneBeaconVerifyChain is RainDeployVerifyChain {
    /// The beacon's owner.
    address constant OWNER = address(0xB0B);

    /// The beacon declared by address when `sBeaconBySuite` is false.
    address internal sBeacon;

    /// Whether the beacon is declared by the release's suite key rather than at `sBeacon`.
    bool internal sBeaconBySuite;

    /// The external deployments a test adds beside the example clone's factory and implementation.
    DeployDependency[] internal sExternalDeployments;

    /// @return The root the clone layer reads extended networks records under.
    function extendedNetworksRoot() internal view virtual returns (string memory) {
        return LibRainDeploySnapshot.LIB_FS_ROOT;
    }

    /// @return The released suites the declaration carries.
    function released() internal view virtual returns (DeploySuite[] memory) {
        return perNetworkCloneReleased();
    }

    /// @return The one beacon, on Polygon.
    function beacons() internal view returns (ChainBeacon[] memory) {
        ChainBeacon[] memory chainBeacons = new ChainBeacon[](1);
        chainBeacons[0].chainId = PER_NETWORK_CLONE_POLYGON_CHAIN_ID;
        if (sBeaconBySuite) {
            chainBeacons[0].beacon.beaconSuite = "per-network-clone@0_0_1";
        } else {
            chainBeacons[0].beacon.beacon = sBeacon;
            chainBeacons[0].beacon.beaconCodeHash = sBeacon.codehash;
        }
        chainBeacons[0].beacon.initial = BeaconState({implementation: "per-network-clone@0_0_1", owner: OWNER});
        return chainBeacons;
    }

    function declaration() internal view override returns (DeployDeclaration memory) {
        DeployDeclaration memory d;
        LibRainDeployDeclaration.extend(d);
        LibRainDeployDeclaration.setNetworks(d, perNetworkCloneNetworks());
        LibRainDeployZoltuMechanism.extend(d);
        LibRainDeployCloneMechanism.extend(d);
        LibRainDeployCloneMechanism.setBeacons(d, beacons());
        LibRainDeployCloneMechanism.setExtendedNetworksRoot(d, extendedNetworksRoot());
        LibExternalDeployments.add(d, exampleCloneDependencies());
        LibExternalDeployments.add(d, sExternalDeployments);
        LibRainDeployDeclaration.addReleased(d, released());
        LibCloneCandidates.addClones(d, perNetworkCloneDeploys());
        return d;
    }
}
