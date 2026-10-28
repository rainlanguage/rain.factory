// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {DeploySuite} from "rain-deploy-0.1.27/src/abstract/RainDeploySuitesBase.sol";
import {ExternalDeployment} from "rain-deploy-0.1.27/src/abstract/RainDeployDeclarationChecks.sol";
import {LibRainDeploy} from "rain-deploy-0.1.27/src/lib/LibRainDeploy.sol";
import {RainDeployCloneBroadcast} from "../../../src/abstract/RainDeployCloneBroadcast.sol";
import {RainDeployCloneBuildScript} from "../../../src/abstract/RainDeployCloneBuildScript.sol";
import {RainDeployCloneVerify} from "../../../src/abstract/RainDeployCloneVerify.sol";
import {RainDeployCloneVerifyChain} from "../../../src/abstract/RainDeployCloneVerifyChain.sol";
import {RainDeployCloneVerifyDeclaration} from "../../../src/abstract/RainDeployCloneVerifyDeclaration.sol";
import {RainDeployCloneVerifySnapshot} from "../../../src/abstract/RainDeployCloneVerifySnapshot.sol";
import {LibRainDeployCloneMechanism} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {exampleCloneRelease} from "../../abstract/ExampleCloneDeploys.sol";

function exampleCloneSuite() pure returns (DeploySuite memory) {
    return LibRainDeployCloneMechanism.cloneCandidate(exampleCloneRelease(), new uint256[](0)).snapshot;
}

function noSuites() pure returns (DeploySuite[] memory) {
    return new DeploySuite[](0);
}

contract CloneBroadcast is RainDeployCloneBroadcast {
    function releasedSuites() internal pure override returns (DeploySuite[] memory) {
        return noSuites();
    }

    function cloneAddress() external view returns (address) {
        return deployedAddresses(exampleCloneSuite())[0];
    }
}

contract CloneBuildScript is RainDeployCloneBuildScript {
    function releasedSuites() internal pure override returns (DeploySuite[] memory) {
        return noSuites();
    }

    function regenerateSnapshots() internal override {}

    function regenerateLibs() internal override {}

    function snapshotContractNames() internal pure override returns (string[] memory) {
        return new string[](0);
    }

    function cloneAddress() external view returns (address) {
        return deployedAddresses(exampleCloneSuite())[0];
    }
}

contract CloneVerifyChain is RainDeployCloneVerifyChain {
    function releasedSuites() internal pure override returns (DeploySuite[] memory) {
        return noSuites();
    }

    function cloneAddress() external view returns (address) {
        return deployedAddresses(exampleCloneSuite())[0];
    }
}

contract CloneVerifySnapshot is RainDeployCloneVerifySnapshot {
    function releasedSuites() internal pure override returns (DeploySuite[] memory) {
        return noSuites();
    }

    function cloneAddress() external view returns (address) {
        return deployedAddresses(exampleCloneSuite())[0];
    }
}

contract CloneVerify is RainDeployCloneVerify {
    function releasedSuites() internal pure override returns (DeploySuite[] memory) {
        return noSuites();
    }

    function cloneAddress() external view returns (address) {
        return deployedAddresses(exampleCloneSuite())[0];
    }
}

contract CloneVerifyDeclaration is RainDeployCloneVerifyDeclaration {
    function releasedSuites() internal pure override returns (DeploySuite[] memory) {
        return noSuites();
    }

    function sourceCreationCode(string memory) internal pure override returns (bytes memory) {
        return "";
    }

    function externalDeployments() internal pure override returns (ExternalDeployment[] memory) {
        return new ExternalDeployment[](0);
    }

    function cloneAddress() external view returns (address) {
        return deployedAddresses(exampleCloneSuite())[0];
    }
}

interface ICloneAddress {
    function cloneAddress() external view returns (address);
}

/// @title RainDeployCloneRoleBasesTest
/// @notice A concrete inheriting one clone role base, overriding no mechanism hook, reads a clone suite through
/// the clone mechanism rather than Zoltu.
contract RainDeployCloneRoleBasesTest is Test {
    function checkClone(address role) internal view {
        DeploySuite memory suite = exampleCloneSuite();
        address cloneAddress = ICloneAddress(role).cloneAddress();
        assertEq(cloneAddress, suite.storedDeployedAddress);
        assertNotEq(cloneAddress, LibRainDeploy.zoltuAddress(suite.creationCode));
    }

    function testEveryRoleBaseReadsACloneSuiteThroughTheCloneMechanism() external {
        checkClone(address(new CloneBroadcast()));
        checkClone(address(new CloneBuildScript()));
        checkClone(address(new CloneVerifyChain()));
        checkClone(address(new CloneVerifySnapshot()));
        checkClone(address(new CloneVerify()));
        checkClone(address(new CloneVerifyDeclaration()));
    }
}
