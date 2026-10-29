// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {UpgradeableBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/UpgradeableBeacon.sol";
import {
    BeaconOnUncheckedNetwork,
    LibRainDeployBeaconDeclarationChecks
} from "../../../src/lib/LibRainDeployBeaconDeclarationChecks.sol";
import {
    BeaconSeatedImplementation,
    BeaconSeatedOwner,
    LibRainDeployCloneOnChainChecks
} from "../../../src/lib/LibRainDeployCloneOnChainChecks.sol";
import {
    BeaconTransition,
    ChainBeacon,
    DeployBeacon,
    LibRainDeployBeacon
} from "../../../src/lib/LibRainDeployBeacon.sol";
import {LibRainDeployBeaconResolution} from "../../../src/lib/LibRainDeployBeaconResolution.sol";
import {DeployDeclaration, DeploySuite} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {DerivedDeploy} from "rain-deploy-0.1.29/src/abstract/RainDeployVerifyBase.sol";
import {LibRainDeploy, SupportedNetwork} from "rain-deploy-0.1.29/src/lib/LibRainDeploy.sol";
import {MockDeployable} from "../../concrete/MockDeployable.sol";
import {MockDeployableV2} from "../../concrete/MockDeployableV2.sol";
import {LibBeaconDeclarations} from "../../lib/LibBeaconDeclarations.sol";
import {BeaconVerifyFixture} from "../../abstract/BeaconVerifyFixture.sol";

contract RainDeployVerifyBaseBeaconTest is BeaconVerifyFixture {
    using LibBeaconDeclarations for ChainBeacon[];

    function externalCheckDeclaration() external {
        LibRainDeployBeaconDeclarationChecks.checkDeclaration(declaration());
    }

    function externalResolveBeacons(SupportedNetwork[] memory networks) external {
        LibRainDeployBeaconResolution.resolveBeacons(declaration(), networks);
    }

    function externalResolvedCount(SupportedNetwork[] memory networks) external returns (uint256) {
        return LibRainDeployBeaconResolution.resolveBeacons(declaration(), networks).length;
    }

    function externalResolveBeaconLeavesDeclaration(DeployBeacon memory beacon) external returns (DeployBeacon memory) {
        DeployDeclaration memory d = declaration();
        LibRainDeployBeaconResolution.resolveBeacon(
            d, beacon, 42161, 0, new DeploySuite[](d.released.length), new DerivedDeploy[](d.released.length)
        );
        return beacon;
    }

    function seatsOther(bool answered, bytes memory answer, address expected) internal pure returns (bool) {
        return LibRainDeployCloneOnChainChecks.seatsOther(answered, answer, expected);
    }

    function repeating(DeployBeacon memory beacon) internal pure returns (DeployBeacon memory) {
        BeaconTransition[] memory transitions = new BeaconTransition[](2);
        transitions[0] = beacon.transitions[0];
        transitions[1] = beacon.transitions[0];
        beacon.transitions = transitions;
        return beacon;
    }

    function testBeaconOnAnUncheckedNetworkIsRefusedBeforeAnEarlierBeaconResolves() external {
        supportOnly(LibRainDeploy.ARBITRUM_ONE, "");
        sBeacons.declare(42161, declared("no-such-suite", OWNER));
        sBeacons.declare(1, declared("beacon-implementation@0_0_1", OWNER));
        vm.expectRevert(abi.encodeWithSelector(BeaconOnUncheckedNetwork.selector, 1, 1));
        this.externalCheckDeclaration();
    }

    function testBeaconOnACheckedNetworkOffTheSupportedNetworksIsRefused() external {
        supportOnly(LibRainDeploy.ARBITRUM_ONE, "");
        sBeacons.declare(8453, declared("beacon-implementation@0_0_1", OWNER));
        vm.expectRevert(abi.encodeWithSelector(BeaconOnUncheckedNetwork.selector, 8453, 0));
        this.externalCheckDeclaration();
    }

    function testResolvingABeaconLeavesItsDeclarationUnwritten() external {
        DeployBeacon memory beacon = this.externalResolveBeaconLeavesDeclaration(bySuite("beacon@0_0_1", OWNER));
        assertEq(beacon.beacon, address(0));
        assertEq(beacon.beaconCodeHash, bytes32(0));
    }

    function testBeaconOnAnEarlierCheckedNetworkResolves() external {
        sBeacons.declare(42161, declared("beacon-implementation@0_0_1", OWNER));
        supportOnly(LibRainDeploy.ARBITRUM_ONE, LibRainDeploy.BASE);
        this.externalCheckDeclaration();
    }

    function testRepeatedMigrationIsRefusedWhileResolving() external {
        sBeacons.declare(42161, declared("beacon-implementation@0_0_1", OWNER));
        sBeacons.declare(42161, repeating(migrating("beacon-upgrade@0_0_1", OWNER)));
        supportOnly(LibRainDeploy.ARBITRUM_ONE, "");
        vm.expectRevert(
            abi.encodeWithSelector(LibRainDeployBeacon.BeaconTransitionMigrationRepeated.selector, 42161, sBeacon, 1)
        );
        this.externalCheckDeclaration();
    }

    function testRepeatedMigrationOnASuiteBeaconNamesItsDerivedAddress() external {
        DeployBeacon memory beacon = migrating("beacon-upgrade@0_0_1", OWNER);
        beacon.beaconSuite = "beacon@0_0_1";
        beacon.beacon = address(0);
        beacon.beaconCodeHash = bytes32(0);
        sBeacons.declare(42161, repeating(beacon));
        supportOnly(LibRainDeploy.ARBITRUM_ONE, "");
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRainDeployBeacon.BeaconTransitionMigrationRepeated.selector, 42161, sSuiteBeacon, 1
            )
        );
        this.externalCheckDeclaration();
    }

    function testNarrowedCheckResolvesOnlyTheBeaconsOnItsNetworks() external {
        sBeacons.declare(8453, declared("beacon-upgrade@0_0_1", OWNER));
        sBeacons.declare(42161, declared("beacon-implementation@0_0_1", OWNER));
        vm.expectCall(LibRainDeploy.ZOLTU_FACTORY, type(MockDeployable).creationCode, 0);
        vm.expectCall(LibRainDeploy.ZOLTU_FACTORY, type(MockDeployableV2).creationCode, 1);
        this.externalResolveBeacons(arbitrum());
    }

    function testNarrowedResolveCountsOnlyTheBeaconsOnItsNetworks() external {
        sBeacons.declare(8453, declared("beacon-implementation@0_0_1", OWNER));
        sBeacons.declare(42161, declared("beacon-implementation@0_0_1", OWNER));
        DeployBeacon memory other = declared("beacon-upgrade@0_0_1", OWNER);
        other.beacon = address(0xBEAC0);
        sBeacons.declare(8453, other);
        assertEq(this.externalResolvedCount(arbitrum()), 1);
        assertEq(this.externalResolvedCount(networksNamed(LibRainDeploy.BASE, "")), 2);
        assertEq(this.externalResolvedCount(networksNamed(LibRainDeploy.ARBITRUM_ONE, LibRainDeploy.BASE)), 3);
    }

    function testNarrowedResolveWithNoBeaconOnItsNetworksIsEmpty() external {
        sBeacons.declare(8453, declared("beacon-implementation@0_0_1", OWNER));
        assertEq(this.externalResolvedCount(arbitrum()), 0);
    }

    function testNoBeaconsResolveWithoutReadingSupportedNetworks() external {
        supportOnly("not-a-catalogue-network", "");
        this.externalCheckDeclaration();
    }

    function testBeaconSuiteSeatingAnotherImplementationIsRefused() external {
        DeployBeacon memory beacon = bySuite("beacon@0_0_1", OWNER);
        beacon.initial.implementation = "beacon-upgrade@0_0_1";
        sBeacons.declare(42161, beacon);
        supportOnly(LibRainDeploy.ARBITRUM_ONE, "");
        vm.expectRevert(
            abi.encodeWithSelector(BeaconSeatedImplementation.selector, 42161, 0, abi.encode(sImplementation))
        );
        this.externalCheckDeclaration();
    }

    function testBeaconSuiteSeatingItsInitialStateResolves() external {
        sBeacons.declare(42161, bySuite("beacon@0_0_1", OWNER));
        supportOnly(LibRainDeploy.ARBITRUM_ONE, "");
        this.externalCheckDeclaration();
    }

    function testSeatedStateDeployIsReverted() external {
        sBeacons.declare(42161, bySuite("beacon@0_0_1", OWNER));
        vm.prank(OWNER);
        UpgradeableBeacon(sSuiteBeacon).transferOwnership(NEW_OWNER);
        supportOnly(LibRainDeploy.ARBITRUM_ONE, "");
        this.externalCheckDeclaration();
        assertEq(UpgradeableBeacon(sSuiteBeacon).owner(), NEW_OWNER);
    }

    function testBeaconSuiteSeatingItsInitialStateBeforeATransitionResolves() external {
        DeployBeacon memory beacon = bySuite("beacon@0_0_1", OWNER);
        beacon.transitions = migrating("beacon-upgrade@0_0_1", NEW_OWNER).transitions;
        sBeacons.declare(42161, beacon);
        supportOnly(LibRainDeploy.ARBITRUM_ONE, "");
        this.externalCheckDeclaration();
    }

    function testBeaconSuiteSeatingAnotherOwnerIsRefusedAtItsIndex() external {
        sBeacons.declare(42161, declared("beacon-implementation@0_0_1", OWNER));
        sBeacons.declare(42161, bySuite("beacon@0_0_1", NEW_OWNER));
        supportOnly(LibRainDeploy.ARBITRUM_ONE, "");
        vm.expectRevert(abi.encodeWithSelector(BeaconSeatedOwner.selector, 42161, 1, abi.encode(OWNER)));
        this.externalCheckDeclaration();
    }

    function testAReadThatRevertsSeatsNothing() external pure {
        assertFalse(seatsOther(false, abi.encode(NEW_OWNER), OWNER));
    }

    function testAReadAnsweringNothingSeatsNothing() external pure {
        assertFalse(seatsOther(true, "", OWNER));
    }

    function testAReadAnsweringAnotherAddressSeatsIt() external pure {
        assertTrue(seatsOther(true, abi.encode(NEW_OWNER), OWNER));
        assertFalse(seatsOther(true, abi.encode(OWNER), OWNER));
    }

    function testAReadAnsweringTheExpectedWordAndMoreSeatsOther() external pure {
        assertTrue(seatsOther(true, abi.encodePacked(abi.encode(OWNER), bytes32(0)), OWNER));
        assertTrue(seatsOther(true, abi.encodePacked(abi.encode(OWNER), bytes1(0)), OWNER));
    }

    function testAReadAnsweringTheExpectedAddressUnderDirtyUpperBitsSeatsOther() external pure {
        assertTrue(seatsOther(true, abi.encode(uint256(uint160(OWNER)) | (uint256(1) << 160)), OWNER));
        assertTrue(seatsOther(true, abi.encode(uint256(uint160(OWNER)) | (uint256(1) << 255)), OWNER));
    }

    function testAReadAnsweringLessThanAWordSeatsOther() external pure {
        assertTrue(seatsOther(true, abi.encodePacked(OWNER), OWNER));
        assertTrue(seatsOther(true, hex"00", address(0)));
    }

    function testFuzzAReadAnsweringAnyOtherWordSeatsOther(uint256 word, address expected) external pure {
        vm.assume(word != uint256(uint160(expected)));
        assertTrue(seatsOther(true, abi.encode(word), expected));
        assertFalse(seatsOther(false, abi.encode(word), expected));
    }

    function testFuzzAReadAnsweringTheExpectedWordWithASuffixSeatsOther(address expected, bytes memory suffix)
        external
        pure
    {
        vm.assume(suffix.length != 0);
        assertTrue(seatsOther(true, abi.encodePacked(abi.encode(expected), suffix), expected));
        assertFalse(seatsOther(true, abi.encode(expected), expected));
    }

    function testBeaconSuiteSeatingAnotherImplementationIsRefusedAtItsIndex() external {
        sBeacons.declare(42161, declared("beacon-implementation@0_0_1", OWNER));
        DeployBeacon memory beacon = bySuite("beacon@0_0_1", OWNER);
        beacon.initial.implementation = "beacon-upgrade@0_0_1";
        sBeacons.declare(42161, beacon);
        supportOnly(LibRainDeploy.ARBITRUM_ONE, "");
        vm.expectRevert(
            abi.encodeWithSelector(BeaconSeatedImplementation.selector, 42161, 1, abi.encode(sImplementation))
        );
        this.externalCheckDeclaration();
    }
}
