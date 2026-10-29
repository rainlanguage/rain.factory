// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {DeploySuite} from "rain-deploy-0.1.27/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeploy} from "rain-deploy-0.1.27/src/lib/LibRainDeploy.sol";
import {LibRainDeployBeaconDeclarationChecks} from "../../../src/lib/LibRainDeployBeaconDeclarationChecks.sol";
import {ChainBeacon} from "../../../src/lib/LibRainDeployBeacon.sol";
import {MockDeployableV2} from "../../concrete/MockDeployableV2.sol";
import {MockRevertingReadBeacon} from "../../concrete/MockRevertingReadBeacon.sol";
import {LibBeaconDeclarations} from "../../lib/LibBeaconDeclarations.sol";
import {LibBeaconTest} from "../../lib/LibBeaconTest.sol";
import {BeaconVerifyFixture} from "../../abstract/BeaconVerifyFixture.sol";

contract RainDeployVerifyBaseBeaconRevertingReadTest is BeaconVerifyFixture {
    using LibBeaconDeclarations for ChainBeacon[];

    function releasedSuites() internal pure override returns (DeploySuite[] memory) {
        DeploySuite[] memory fixture = super.releasedSuites();
        DeploySuite[] memory released = new DeploySuite[](fixture.length + 2);
        for (uint256 i = 0; i < fixture.length; i++) {
            released[i] = fixture[i];
        }
        released[fixture.length] = revertingReadSuite("owner-reverting-beacon@0_0_1", true);
        released[fixture.length + 1] = revertingReadSuite("implementation-reverting-beacon@0_0_1", false);
        return released;
    }

    function revertingReadSuite(string memory key, bool ownerReverts) internal pure returns (DeploySuite memory) {
        return LibBeaconTest.zoltuSuite(
            key,
            abi.encodePacked(
                type(MockRevertingReadBeacon).creationCode,
                abi.encode(LibRainDeploy.zoltuAddress(type(MockDeployableV2).creationCode), OWNER, ownerReverts)
            ),
            type(MockRevertingReadBeacon).runtimeCode,
            "test/concrete/MockRevertingReadBeacon.sol:MockRevertingReadBeacon"
        );
    }

    function externalCheckDeclaration() external {
        LibRainDeployBeaconDeclarationChecks.checkDeclaration(declaration());
    }

    function testBeaconSuiteWhoseOwnerReadRevertsWithDataResolves() external {
        sBeacons.declare(42161, bySuite("owner-reverting-beacon@0_0_1", OWNER));
        supportOnly(LibRainDeploy.ARBITRUM_ONE, "");
        this.externalCheckDeclaration();
    }

    function testBeaconSuiteWhoseImplementationReadRevertsWithDataResolves() external {
        sBeacons.declare(42161, bySuite("implementation-reverting-beacon@0_0_1", OWNER));
        supportOnly(LibRainDeploy.ARBITRUM_ONE, "");
        this.externalCheckDeclaration();
    }
}
