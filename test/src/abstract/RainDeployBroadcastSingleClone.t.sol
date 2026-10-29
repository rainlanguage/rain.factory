// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {DeploySuite} from "rain-deploy-0.1.27/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeploy} from "rain-deploy-0.1.27/src/lib/LibRainDeploy.sol";
import {ZoltuDeployOrAdopt} from "../../abstract/ZoltuDeployOrAdopt.sol";
import {ExampleCloneDeploy} from "../../concrete/ExampleCloneDeploy.sol";
import {MockCloneFactory} from "../../concrete/MockCloneFactory.sol";
import {MockCloneable} from "../../concrete/MockCloneable.sol";

/// @title RainDeployBroadcastSingleCloneTest
/// @notice `broadcastSuite` over the example declaration's single-clone suites.
contract RainDeployBroadcastSingleCloneTest is ZoltuDeployOrAdopt {
    /// `broadcastSuite` hands a clone suite to the clone broadcast with the clone the KEY selects
    /// and the address the suite RECORDS.
    function testBroadcastSuiteHandsOverTheSelectedCloneAndTheRecordedAddress() external {
        ExampleCloneDeploy deploy = new ExampleCloneDeploy();

        DeploySuite memory suite = deploy.externalSuiteByName("example-clone-second-salt");
        address derived = deploy.externalDeployedAddresses(suite)[0];

        assertEq(suite.storedDeployedAddress, derived, "the declaration must agree before it is staled");
        assertNotEq(
            derived,
            deploy.externalDeployedAddresses(deploy.externalSuiteByName("example-clone"))[0],
            "the two declared clones must derive apart"
        );
        assertNotEq(derived, LibRainDeploy.zoltuAddress(suite.creationCode), "the clone is not at its Zoltu address");

        suite.storedDeployedAddress = address(uint160(derived) + 1);

        string[] memory networks = new string[](1);
        networks[0] = LibRainDeploy.ARBITRUM_ONE;

        vm.expectRevert(
            abi.encodeWithSelector(
                LibRainDeploy.UnexpectedDeployedAddress.selector, suite.storedDeployedAddress, derived
            )
        );
        deploy.externalBroadcastSuite(suite, networks, 1);
    }

    /// A frozen clone release is broadcast by its key like any other release.
    function testBroadcastsTheFrozenCloneReleaseByKey() external {
        ExampleCloneDeploy deploy = new ExampleCloneDeploy();
        vm.makePersistent(address(this));
        vm.makePersistent(address(deploy));
        vm.createSelectFork(LibRainDeploy.ARBITRUM_ONE);

        vm.makePersistent(zoltuDeployOrAdopt(type(MockCloneFactory).creationCode, type(MockCloneFactory).runtimeCode));
        vm.makePersistent(zoltuDeployOrAdopt(type(MockCloneable).creationCode, type(MockCloneable).runtimeCode));

        DeploySuite memory release = deploy.externalSuiteByName("example-clone@0_0_1");
        assertEq(release.storedDeployedAddress.code.length, 0, "the release must not already be deployed");

        string[] memory networks = new string[](1);
        networks[0] = LibRainDeploy.ARBITRUM_ONE;
        deploy.externalBroadcastSuite(release, networks, 1);

        assertEq(release.storedDeployedAddress.code, release.storedRuntimeCode);
        assertEq(release.storedDeployedAddress.codehash, release.storedBytecodeHash);
    }
}
