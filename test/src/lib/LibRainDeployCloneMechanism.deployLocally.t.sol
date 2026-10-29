// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {
    DeployDeclaration,
    DeployDependency,
    DeploySuite
} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeploy} from "rain-deploy-0.1.29/src/lib/LibRainDeploy.sol";
import {CLONE_ARTIFACT_PATH, CloneNetworks, LibRainDeployClone} from "../../../src/lib/LibRainDeployClone.sol";
import {
    CLONE_PER_NETWORK_MECHANISM,
    CloneSnapshotRevertFailed,
    LibRainDeployCloneMechanism
} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {ChainDeploy} from "../../../src/lib/LibRainDeployExtendedNetworks.sol";
import {MockCloneFactory} from "../../concrete/MockCloneFactory.sol";
import {MockSnapshotDeletingCloneable} from "../../concrete/MockSnapshotDeletingCloneable.sol";

/// @title LibRainDeployCloneMechanismDeployLocallyTest
/// @notice `LibRainDeployCloneMechanism.deployLocally` of a per-network clone whose networks share an address.
contract LibRainDeployCloneMechanismDeployLocallyTest is Test {
    function externalDeployLocally(DeploySuite memory suite) external returns (address[] memory) {
        DeployDeclaration memory d;
        return LibRainDeployCloneMechanism.deployLocally(d, vm, suite);
    }

    function sharedSnapshotDeletingSuite() internal pure returns (DeploySuite memory) {
        CloneNetworks memory clones = CloneNetworks({
            factory: LibRainDeploy.zoltuAddress(type(MockCloneFactory).creationCode),
            implementation: LibRainDeploy.zoltuAddress(type(MockSnapshotDeletingCloneable).creationCode),
            salt: bytes32(uint256(7)),
            networks: new ChainDeploy[](2)
        });
        clones.networks[0] = ChainDeploy({chainId: 42161, data: hex"01", deployedAddress: address(0)});
        clones.networks[1] = ChainDeploy({chainId: 8453, data: hex"01", deployedAddress: address(0)});
        DeployDependency[] memory dependencies = new DeployDependency[](2);
        dependencies[0] =
            DeployDependency({deployedAddress: clones.factory, runtimeCode: type(MockCloneFactory).runtimeCode});
        dependencies[1] = DeployDependency({
            deployedAddress: clones.implementation, runtimeCode: type(MockSnapshotDeletingCloneable).runtimeCode
        });
        string[] memory networks = new string[](2);
        networks[0] = LibRainDeploy.ARBITRUM_ONE;
        networks[1] = LibRainDeploy.BASE;
        bytes memory runtimeCode = LibRainDeployClone.cloneRuntimeCode(clones.implementation);
        return DeploySuite({
            suite: "snapshot-deleting-clone@0_0_1",
            creationCode: LibRainDeployClone.cloneCreationCode(clones.implementation),
            storedDeployedAddress: address(0),
            storedBytecodeHash: keccak256(runtimeCode),
            storedRuntimeCode: runtimeCode,
            artifactPath: CLONE_ARTIFACT_PATH,
            dependencies: dependencies,
            mechanismData: abi.encode(CLONE_PER_NETWORK_MECHANISM, abi.encode(clones)),
            networks: networks
        });
    }

    function testSharedNetworkDeployWhoseSnapshotCannotBeRevertedIsRefused() external {
        DeploySuite memory suite = sharedSnapshotDeletingSuite();
        uint256 sharedSnapshotId = vm.snapshotState() + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                CloneSnapshotRevertFailed.selector, "snapshot-deleting-clone@0_0_1", sharedSnapshotId
            )
        );
        this.externalDeployLocally(suite);
    }
}
