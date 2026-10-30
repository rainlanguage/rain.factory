// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {DeployDeclaration, DeploySuite} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {Prerequisite} from "rain-deploy-0.1.29/src/interface/IMigrationRegistryV5.sol";
import {BeaconState, BeaconTransition, ChainBeacon, DeployBeacon} from "../../../src/lib/LibRainDeployBeacon.sol";
import {
    BEACON_PROXY_MECHANISM,
    BEACON_PROXY_PER_NETWORK_MECHANISM,
    CLONE_MECHANISM,
    LibRainDeployCloneMechanism
} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {
    BeaconOwnedByDeployKey,
    LibRainDeployCloneOnChainChecks
} from "../../../src/lib/LibRainDeployCloneOnChainChecks.sol";

/// @title LibRainDeployCloneOnChainChecksBroadcastSeatTest
/// @notice `checkBroadcastSeat` refuses a beacon proxy suite when the deploy key owns any state of a declared beacon,
/// naming the first such state, and does not limit a clone suite.
contract LibRainDeployCloneOnChainChecksBroadcastSeatTest is Test {
    address constant OWNER = address(0xB0B);
    address constant NEW_OWNER = address(0xCAFE);
    address constant DEPLOYER = address(0xD1);

    function beacon(address initialOwner, address[] memory transitionOwners)
        internal
        pure
        returns (DeployBeacon memory)
    {
        BeaconTransition[] memory transitions = new BeaconTransition[](transitionOwners.length);
        for (uint256 i = 0; i < transitionOwners.length; i++) {
            transitions[i] = BeaconTransition({
                migration: Prerequisite({
                    writer: address(0x5AFE), namespace: keccak256("beacons"), migration: bytes32(i + 1)
                }),
                state: BeaconState({implementation: "impl", owner: transitionOwners[i]})
            });
        }
        return DeployBeacon({
            beaconSuite: "",
            beacon: address(0xBEAC),
            beaconCodeHash: bytes32(0),
            initial: BeaconState({implementation: "impl", owner: initialOwner}),
            transitions: transitions
        });
    }

    /// Beacon 0 on 42161: `initial0`, then `NEW_OWNER`. Beacon 1 on 8453: `OWNER`, then `NEW_OWNER`, then `last1`.
    function checkBroadcastSeat(bytes32 mechanismId, address initial0, address last1) external view {
        address[] memory owners0 = new address[](1);
        owners0[0] = NEW_OWNER;
        address[] memory owners1 = new address[](2);
        owners1[0] = NEW_OWNER;
        owners1[1] = last1;
        ChainBeacon[] memory beacons = new ChainBeacon[](2);
        beacons[0] = ChainBeacon({chainId: 42161, beacon: beacon(initial0, owners0)});
        beacons[1] = ChainBeacon({chainId: 8453, beacon: beacon(OWNER, owners1)});
        DeployDeclaration memory d;
        LibRainDeployCloneMechanism.extend(d);
        LibRainDeployCloneMechanism.setBeacons(d, beacons);
        DeploySuite memory suite;
        suite.suite = "suite";
        suite.mechanismData = abi.encode(mechanismId, "");
        LibRainDeployCloneOnChainChecks.checkBroadcastSeat(d, suite, 1, DEPLOYER);
    }

    function testBroadcastSeatRefusesTheDeployKeyOwningTheLastStateOfTheLastBeacon() external {
        vm.expectRevert(abi.encodeWithSelector(BeaconOwnedByDeployKey.selector, 8453, 1, 2));
        this.checkBroadcastSeat(BEACON_PROXY_MECHANISM, OWNER, DEPLOYER);
    }

    function testBroadcastSeatRefusesTheDeployKeyOwningTheFirstBeaconsInitialState() external {
        vm.expectRevert(abi.encodeWithSelector(BeaconOwnedByDeployKey.selector, 42161, 0, 0));
        this.checkBroadcastSeat(BEACON_PROXY_PER_NETWORK_MECHANISM, DEPLOYER, OWNER);
    }

    function testBroadcastSeatPassesABeaconProxySuiteNoBeaconStateOfWhichTheDeployKeyOwns() external view {
        this.checkBroadcastSeat(BEACON_PROXY_MECHANISM, OWNER, OWNER);
    }

    function testBroadcastSeatPassesACloneSuiteWhoseDeployKeyOwnsABeacon() external view {
        this.checkBroadcastSeat(CLONE_MECHANISM, DEPLOYER, DEPLOYER);
    }
}
