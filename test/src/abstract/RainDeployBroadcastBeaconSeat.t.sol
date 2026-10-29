// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/UpgradeableBeacon.sol";
import {DeploySuite} from "rain-deploy-0.1.27/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeploy} from "rain-deploy-0.1.27/src/lib/LibRainDeploy.sol";
import {Prerequisite} from "rain-deploy-0.1.27/src/interface/IMigrationRegistryV5.sol";
import {BeaconState, BeaconTransition, DeployBeacon} from "../../../src/lib/LibRainDeployBeacon.sol";
import {LibRainDeployCloneMechanism} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {perNetworkCloneChainIds} from "../../abstract/PerNetworkCloneDeploys.sol";
import {BEACON_OWNER_DEPLOY_RELEASE, BeaconOwnerDeploy} from "../../concrete/BeaconOwnerDeploy.sol";
import {MockBeaconProxyFactory} from "../../concrete/MockBeaconProxyFactory.sol";
import {MockOriginOwnedCloneable} from "../../concrete/MockOriginOwnedCloneable.sol";
import {LibBeaconProxyTest} from "../../lib/LibBeaconProxyTest.sol";

/// @title RainDeployBroadcastBeaconSeatTest
/// @notice `broadcastSuite`'s pre-fork seat checks beside declared beacons and over a beacon proxy suite.
contract RainDeployBroadcastBeaconSeatTest is Test {
    function ownedBy(address initial, address later) internal pure returns (DeployBeacon memory) {
        DeployBeacon memory beacon = DeployBeacon({
            beaconSuite: "",
            beacon: address(0xBEAC0),
            beaconCodeHash: keccak256("beacon"),
            initial: BeaconState({implementation: BEACON_OWNER_DEPLOY_RELEASE, owner: initial}),
            transitions: new BeaconTransition[](2)
        });
        for (uint256 i = 0; i < 2; i++) {
            beacon.transitions[i] = BeaconTransition({
                migration: Prerequisite({
                    writer: address(0x5AFE), namespace: keccak256("beacons"), migration: keccak256(abi.encode(i))
                }),
                state: BeaconState({implementation: BEACON_OWNER_DEPLOY_RELEASE, owner: i == 1 ? later : initial})
            });
        }
        return beacon;
    }

    function expectBroadcastRefused(BeaconOwnerDeploy deploy, bytes memory refusal) internal {
        DeploySuite memory suite = deploy.externalSuiteByName(BEACON_OWNER_DEPLOY_RELEASE);
        vm.expectRevert(refusal);
        deploy.externalBroadcastSuite(suite, new string[](0), 1);
    }

    function testBroadcastWithBeaconsOwnedByOthersReachesTheNetworkRefusal() external {
        BeaconOwnerDeploy deploy = new BeaconOwnerDeploy();
        deploy.declareBeacon(42161, ownedBy(address(0xB0B), address(0xCAFE)));
        deploy.declareBeacon(8453, ownedBy(address(0xCAFE), vm.addr(2)));
        expectBroadcastRefused(deploy, abi.encodeWithSelector(LibRainDeploy.NoNetworks.selector));
    }

    /// A beacon proxy suite whose init data would seat the deploy key passes the pre-fork seat check, which cannot read
    /// a placed proxy's `owner()`, so the broadcast reaches the network refusal; its seat is checked on each network's fork.
    function testBroadcastOfABeaconProxySuiteSeatingTheDeployKeyReachesTheNetworkRefusal() external {
        BeaconOwnerDeploy deploy = new BeaconOwnerDeploy();
        address beacon = address(new UpgradeableBeacon(address(new MockOriginOwnedCloneable()), address(0xB0B)));
        DeploySuite memory suite =
        LibRainDeployCloneMechanism.beaconProxyCandidate(
            LibBeaconProxyTest.declared(
                "origin-owned-beacon-proxy",
                address(new MockBeaconProxyFactory()),
                beacon,
                abi.encode(address(0)),
                false,
                bytes32(uint256(1)),
                LibBeaconProxyTest.runtimeOf(vm, beacon)
            ),
            perNetworkCloneChainIds()
        )
        .snapshot;
        vm.expectRevert(abi.encodeWithSelector(LibRainDeploy.NoNetworks.selector));
        deploy.externalBroadcastSuite(suite, new string[](0), 1);
    }
}
