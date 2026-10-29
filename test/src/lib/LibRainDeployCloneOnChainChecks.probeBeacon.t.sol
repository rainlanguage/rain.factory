// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {DeployDeclaration, DeploySuite} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.29/src/lib/LibRainDeployDeclaration.sol";
import {LibRainDeployZoltuMechanism} from "rain-deploy-0.1.29/src/lib/LibRainDeployZoltuMechanism.sol";
import {LibRainDeployCloneMechanism} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {
    BeaconProbe,
    BeaconSnapshotRevertFailed,
    LibRainDeployCloneOnChainChecks
} from "../../../src/lib/LibRainDeployCloneOnChainChecks.sol";
import {MockSnapshotDeletingCreation} from "../../concrete/MockSnapshotDeletingCreation.sol";
import {LibBeaconTest} from "../../lib/LibBeaconTest.sol";

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
