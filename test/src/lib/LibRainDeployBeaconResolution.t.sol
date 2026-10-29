// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {SupportedNetwork} from "rain-deploy-0.1.29/src/lib/LibRainDeploy.sol";
import {ChainBeacon, DeployBeacon} from "../../../src/lib/LibRainDeployBeacon.sol";
import {BeaconDeclaredTwice} from "../../../src/lib/LibRainDeployBeaconDeclarationChecks.sol";
import {BeaconNamedTwice} from "../../../src/lib/LibRainDeployCloneOnChainChecks.sol";
import {LibRainDeployBeaconResolution} from "../../../src/lib/LibRainDeployBeaconResolution.sol";
import {LibBeaconDeclarations} from "../../lib/LibBeaconDeclarations.sol";
import {BeaconVerifyFixture} from "../../abstract/BeaconVerifyFixture.sol";

/// @title LibRainDeployBeaconResolutionTest
/// @notice A refusal while resolving a narrowed set of networks names the beacon's index among every declared beacon.
contract LibRainDeployBeaconResolutionTest is BeaconVerifyFixture {
    using LibBeaconDeclarations for ChainBeacon[];

    function externalResolveBeacons(SupportedNetwork[] memory networks) external {
        LibRainDeployBeaconResolution.resolveBeacons(declaration(), networks);
    }

    function testNarrowedResolveNamesABeaconNamedTwiceAtItsDeclaredIndex() external {
        sBeacons.declare(8453, declared("beacon-implementation@0_0_1", OWNER));
        DeployBeacon memory beacon = bySuite("beacon@0_0_1", OWNER);
        beacon.beacon = sBeacon;
        sBeacons.declare(42161, beacon);
        vm.expectRevert(abi.encodeWithSelector(BeaconNamedTwice.selector, 42161, 1));
        this.externalResolveBeacons(arbitrum());
    }

    function testNarrowedResolveNamesABeaconDeclaredTwiceAtItsDeclaredIndex() external {
        sBeacons.declare(8453, declared("beacon-implementation@0_0_1", OWNER));
        sBeacons.declare(42161, declared("beacon-implementation@0_0_1", OWNER));
        sBeacons.declare(42161, declared("beacon-implementation@0_0_1", OWNER));
        vm.expectRevert(abi.encodeWithSelector(BeaconDeclaredTwice.selector, 42161, 2));
        this.externalResolveBeacons(arbitrum());
    }
}
