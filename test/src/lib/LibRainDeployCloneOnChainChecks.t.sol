// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {
    DeployCandidate,
    DeployDeclaration,
    DeploySuite
} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {Prerequisite} from "rain-deploy-0.1.29/src/interface/IMigrationRegistryV5.sol";
import {BeaconState, BeaconTransition, ChainBeacon, DeployBeacon} from "../../../src/lib/LibRainDeployBeacon.sol";
import {CloneNetworks} from "../../../src/lib/LibRainDeployClone.sol";
import {ChainDeploy, LibRainDeployExtendedNetworks} from "../../../src/lib/LibRainDeployExtendedNetworks.sol";
import {
    BEACON_PROXY_MECHANISM,
    BEACON_PROXY_PER_NETWORK_MECHANISM,
    CLONE_MECHANISM,
    LibRainDeployCloneMechanism
} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {
    BeaconOwnedByDeployKey,
    BeaconSuiteNotReleased,
    LibRainDeployCloneOnChainChecks
} from "../../../src/lib/LibRainDeployCloneOnChainChecks.sol";
import {
    PER_NETWORK_CLONE_POLYGON_CHAIN_ID,
    onlyFirstRecordedNetworkSuites,
    perNetworkCloneChainIds,
    perNetworkCloneDeploys,
    perNetworkCloneInitData,
    perNetworkCloneLayers,
    perNetworkCloneReleaseAddress,
    perNetworkCloneReleaseAddressAt,
    perNetworkCloneReleased
} from "../../abstract/PerNetworkCloneDeploys.sol";
import {LibExtendedNetworksFixture} from "../../lib/LibExtendedNetworksFixture.sol";

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

/// @title LibRainDeployCloneOnChainChecksReleasedTest
/// @notice `released` returns the release with its extended networks record and its candidate's networks among the
/// declaration's appended, leaving `d.released` unchanged.
contract LibRainDeployCloneOnChainChecksReleasedTest is Test {
    string constant KEY = "per-network-clone@0_0_1";

    function declaration(string memory label) internal returns (DeployDeclaration memory) {
        DeployDeclaration memory d = perNetworkCloneLayers();
        d.released = onlyFirstRecordedNetworkSuites(perNetworkCloneReleased()[0]);
        d.candidates = new DeployCandidate[](1);
        d.candidates[0] =
            LibRainDeployCloneMechanism.cloneCandidate(perNetworkCloneDeploys()[0], perNetworkCloneChainIds());
        LibRainDeployCloneMechanism.setExtendedNetworksRoot(
            d, LibExtendedNetworksFixture.freshRoot(vm, "fixture-lib/extended-networks", label, KEY)
        );
        return d;
    }

    function networksOf(DeploySuite memory suite) internal pure returns (ChainDeploy[] memory) {
        return abi.decode(LibRainDeployCloneMechanism.payload(suite), (CloneNetworks)).networks;
    }

    function testReleasedTakesTheCandidatesNetworkTheReleaseDoesNotRecord() external {
        DeployDeclaration memory d = declaration("released-candidate-network");
        bytes memory releasedData = d.released[0].mechanismData;
        ChainDeploy[] memory networks = networksOf(LibRainDeployCloneOnChainChecks.released(d, KEY));
        assertEq(networks.length, 2);
        assertEq(networks[1].chainId, PER_NETWORK_CLONE_POLYGON_CHAIN_ID);
        assertEq(networks[1].data, perNetworkCloneInitData(PER_NETWORK_CLONE_POLYGON_CHAIN_ID));
        assertEq(networks[1].deployedAddress, perNetworkCloneReleaseAddress(PER_NETWORK_CLONE_POLYGON_CHAIN_ID));
        assertEq(d.released[0].mechanismData, releasedData);
    }

    function testReleasedTakesItsExtendedNetworkRecordOverTheCandidatesData() external {
        DeployDeclaration memory d = declaration("released-extended-network");
        bytes memory data = abi.encode(address(0xc3c3c3c3c3c3c3c3c3C3C3c3C3C3C3c3C3C3c3c3));
        ChainDeploy[] memory extended = new ChainDeploy[](1);
        extended[0] = ChainDeploy({
            chainId: PER_NETWORK_CLONE_POLYGON_CHAIN_ID,
            data: data,
            deployedAddress: perNetworkCloneReleaseAddressAt(data)
        });
        LibRainDeployExtendedNetworks.writeExtendedNetworks(
            vm, LibRainDeployCloneMechanism.layerConfig(d).extendedNetworksRoot, KEY, extended
        );
        ChainDeploy[] memory networks = networksOf(LibRainDeployCloneOnChainChecks.released(d, KEY));
        assertEq(networks.length, 2);
        assertEq(networks[1].chainId, PER_NETWORK_CLONE_POLYGON_CHAIN_ID);
        assertEq(networks[1].data, data);
        assertEq(networks[1].deployedAddress, perNetworkCloneReleaseAddressAt(data));
    }

    function externalReleased(string memory key) external returns (DeploySuite memory) {
        return LibRainDeployCloneOnChainChecks.released(declaration("released-unreleased-key"), key);
    }

    function testReleasedRefusesAKeyNotReleased() external {
        vm.expectRevert(abi.encodeWithSelector(BeaconSuiteNotReleased.selector, "no-such-suite"));
        this.externalReleased("no-such-suite");
    }
}
