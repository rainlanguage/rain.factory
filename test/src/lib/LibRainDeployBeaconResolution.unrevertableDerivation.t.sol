// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {DeploySuite, DerivationSnapshotRevertFailed} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {DerivedDeploy} from "rain-deploy-0.1.29/src/abstract/RainDeployVerifyBase.sol";
import {LibRainDeploy} from "rain-deploy-0.1.29/src/lib/LibRainDeploy.sol";
import {LibRainDeployBeaconResolution} from "../../../src/lib/LibRainDeployBeaconResolution.sol";
import {MockSnapshotDeletingCreation} from "../../concrete/MockSnapshotDeletingCreation.sol";
import {LibBeaconTest} from "../../lib/LibBeaconTest.sol";
import {BeaconVerifyFixture} from "../../abstract/BeaconVerifyFixture.sol";

/// @title LibRainDeployBeaconResolutionUnrevertableDerivationTest
/// @notice A derivation whose state cannot be reverted is refused rather than left in place.
contract LibRainDeployBeaconResolutionUnrevertableDerivationTest is BeaconVerifyFixture {
    function externalDeriveDeployment(DeploySuite memory suite) external returns (DerivedDeploy memory) {
        return LibRainDeployBeaconResolution.deriveDeployment(declaration(), suite);
    }

    function testDerivationThatCannotBeRevertedIsRefused() external {
        DeploySuite memory suite = LibBeaconTest.zoltuSuite(
            "snapshot-deleting@0_0_1",
            type(MockSnapshotDeletingCreation).creationCode,
            type(MockSnapshotDeletingCreation).runtimeCode,
            "test/concrete/MockSnapshotDeletingCreation.sol:MockSnapshotDeletingCreation"
        );
        suite.networks = new string[](1);
        suite.networks[0] = LibRainDeploy.ARBITRUM_ONE;
        uint256 derivationSnapshotId = vm.snapshotState() + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                DerivationSnapshotRevertFailed.selector, "snapshot-deleting@0_0_1", derivationSnapshotId
            )
        );
        this.externalDeriveDeployment(suite);
    }
}
