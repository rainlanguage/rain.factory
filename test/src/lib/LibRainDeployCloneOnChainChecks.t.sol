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
import {LibRainDeployDeclaration} from "rain-deploy-0.1.29/src/lib/LibRainDeployDeclaration.sol";
import {LibRainDeployZoltuMechanism} from "rain-deploy-0.1.29/src/lib/LibRainDeployZoltuMechanism.sol";
import {BeaconState, BeaconTransition, ChainBeacon, DeployBeacon} from "../../../src/lib/LibRainDeployBeacon.sol";
import {CloneNetworks} from "../../../src/lib/LibRainDeployClone.sol";
import {
    ChainDeploy,
    ExtendedNetworksUnrecorded,
    LibRainDeployExtendedNetworks
} from "../../../src/lib/LibRainDeployExtendedNetworks.sol";
import {
    BEACON_PROXY_MECHANISM,
    BEACON_PROXY_PER_NETWORK_MECHANISM,
    CLONE_MECHANISM,
    ExtendedNetworksDeclaration,
    LibRainDeployCloneMechanism
} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {
    BeaconOwnedByDeployKey,
    BeaconProbe,
    BeaconSnapshotRevertFailed,
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
import {MockSnapshotDeletingCreation} from "../../concrete/MockSnapshotDeletingCreation.sol";
import {LibExtendedNetworksFixture} from "../../lib/LibExtendedNetworksFixture.sol";
import {LibBeaconTest} from "../../lib/LibBeaconTest.sol";

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

/// @title LibRainDeployCloneOnChainChecksDeclarationPerNetworkTest
/// @notice `checkDeclarationPerNetwork` refuses any release whose declared extended networks are not its record.
contract LibRainDeployCloneOnChainChecksDeclarationPerNetworkTest is Test {
    string constant FIRST = "first-per-network-clone@0_0_1";
    string constant SECOND = "second-per-network-clone@0_0_1";

    function oneNetwork(uint256 chainId, bytes memory data, address deployedAddress)
        internal
        pure
        returns (ChainDeploy[] memory)
    {
        ChainDeploy[] memory networks = new ChainDeploy[](1);
        networks[0] = ChainDeploy({chainId: chainId, data: data, deployedAddress: deployedAddress});
        return networks;
    }

    function checkDeclarationPerNetwork(string memory label, bool firstRecorded, bool secondRecorded) external {
        string memory root = LibExtendedNetworksFixture.freshRoot(vm, "fixture-lib/extended-networks", label, FIRST);
        LibExtendedNetworksFixture.freshRoot(vm, "fixture-lib/extended-networks", label, SECOND);
        ExtendedNetworksDeclaration[] memory extended = new ExtendedNetworksDeclaration[](2);
        extended[0] = ExtendedNetworksDeclaration({
            suite: FIRST, networks: oneNetwork(137, hex"00aa", address(0x1111111111111111111111111111111111111111))
        });
        extended[1] = ExtendedNetworksDeclaration({
            suite: SECOND, networks: oneNetwork(8453, hex"", address(0xC4c4c4C4C4c4C4c4c4C4c4c4c4c4c4C4c4c4c4C4))
        });
        if (firstRecorded) {
            LibRainDeployExtendedNetworks.writeExtendedNetworks(vm, root, FIRST, extended[0].networks);
        }
        if (secondRecorded) {
            LibRainDeployExtendedNetworks.writeExtendedNetworks(vm, root, SECOND, extended[1].networks);
        }
        DeployDeclaration memory d;
        LibRainDeployCloneMechanism.extend(d);
        LibRainDeployCloneMechanism.setExtendedNetworksRoot(d, root);
        LibRainDeployCloneMechanism.setExtendedNetworks(d, extended);
        LibRainDeployCloneOnChainChecks.checkDeclarationPerNetwork(d);
    }

    function testCheckDeclarationPerNetworkPassesWhenEveryReleaseIsRecorded() external {
        this.checkDeclarationPerNetwork("declaration-all-recorded", true, true);
    }

    function testCheckDeclarationPerNetworkRefusesTheFirstReleaseUnrecorded() external {
        vm.expectRevert(abi.encodeWithSelector(ExtendedNetworksUnrecorded.selector, FIRST));
        this.checkDeclarationPerNetwork("declaration-first-unrecorded", false, true);
    }

    function testCheckDeclarationPerNetworkRefusesTheLastReleaseUnrecorded() external {
        vm.expectRevert(abi.encodeWithSelector(ExtendedNetworksUnrecorded.selector, SECOND));
        this.checkDeclarationPerNetwork("declaration-last-unrecorded", true, false);
    }
}

/// @title LibRainDeployCloneOnChainChecksProbeBeaconTest
/// @notice `probeBeacon` refuses a local deploy whose state cannot be reverted rather than leaving it in place.
contract LibRainDeployCloneOnChainChecksProbeBeaconTest is Test {
    function externalProbeBeacon(DeploySuite memory suite) external returns (BeaconProbe memory) {
        DeployDeclaration memory d;
        LibRainDeployDeclaration.extend(d);
        LibRainDeployZoltuMechanism.extend(d);
        LibRainDeployCloneMechanism.extend(d);
        return LibRainDeployCloneOnChainChecks.probeBeacon(d, suite, address(0xBEAC), 42161);
    }

    function testProbeBeaconWhoseDeployCannotBeRevertedIsRefused() external {
        DeploySuite memory suite = LibBeaconTest.zoltuSuite(
            "snapshot-deleting@0_0_1",
            type(MockSnapshotDeletingCreation).creationCode,
            type(MockSnapshotDeletingCreation).runtimeCode,
            "test/concrete/MockSnapshotDeletingCreation.sol:MockSnapshotDeletingCreation"
        );
        uint256 probeSnapshotId = vm.snapshotState() + 1;
        vm.expectRevert(
            abi.encodeWithSelector(BeaconSnapshotRevertFailed.selector, "snapshot-deleting@0_0_1", probeSnapshotId)
        );
        this.externalProbeBeacon(suite);
    }
}
