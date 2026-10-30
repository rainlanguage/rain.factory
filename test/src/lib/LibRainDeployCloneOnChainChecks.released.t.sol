// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {
    DeployCandidate,
    DeployDeclaration,
    DeploySuite
} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {CloneNetworks} from "../../../src/lib/LibRainDeployClone.sol";
import {ChainDeploy, LibRainDeployExtendedNetworks} from "../../../src/lib/LibRainDeployExtendedNetworks.sol";
import {LibRainDeployCloneMechanism} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {
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
