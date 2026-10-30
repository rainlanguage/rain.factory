// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {DeployDeclaration, DeploySuite} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {RainDeployVerifyChain} from "rain-deploy-0.1.29/src/abstract/RainDeployVerifyChain.sol";
import {LibRainDeploy} from "rain-deploy-0.1.29/src/lib/LibRainDeploy.sol";
import {LibRainDeployCloneMechanism} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {PerNetworkCloneDeploys, etchPerNetworkCloneRelease} from "../../abstract/PerNetworkCloneDeploys.sol";

/// @title RainDeployVerifyChainClonePerNetworkTest
/// @notice The chain matrix over a per-network clone release, which is at a different address on
/// each of its two networks.
contract RainDeployVerifyChainClonePerNetworkTest is PerNetworkCloneDeploys, RainDeployVerifyChain {
    /// Puts the release's dependencies, and its clone at its address for each network, on every
    /// fork.
    function setUp() external {
        DeployDeclaration memory d = declaration();
        DeploySuite memory release = d.released[0];
        etchPerNetworkCloneRelease(vm, release, deployedAddresses(d, release));
    }

    /// Without Polygon's clone, the matrix refuses on Polygon at Polygon's address, having passed
    /// Arbitrum One at Arbitrum One's.
    function testPerNetworkCloneMissingOnPolygonIsRefusedAtPolygonsAddress() external {
        DeployDeclaration memory d = declaration();
        DeploySuite memory release = d.released[0];
        address polygonAddress = LibRainDeployCloneMechanism.deployedAddress(d, release, 137);
        vm.etch(polygonAddress, hex"");

        vm.expectRevert(
            abi.encodeWithSelector(LibRainDeploy.NotDeployedOnNetwork.selector, LibRainDeploy.POLYGON, polygonAddress)
        );
        this.testSuitesLiveOnEverySupportedNetwork();
    }

    /// Without Arbitrum One's clone, the matrix refuses on Arbitrum One at Arbitrum One's address,
    /// though Polygon's address holds the clone.
    function testPerNetworkCloneMissingOnArbitrumIsRefusedAtArbitrumsAddress() external {
        DeployDeclaration memory d = declaration();
        DeploySuite memory release = d.released[0];
        address arbitrumAddress = LibRainDeployCloneMechanism.deployedAddress(d, release, 42161);
        vm.etch(arbitrumAddress, hex"");

        vm.expectRevert(
            abi.encodeWithSelector(
                LibRainDeploy.NotDeployedOnNetwork.selector, LibRainDeploy.ARBITRUM_ONE, arbitrumAddress
            )
        );
        this.testSuitesLiveOnEverySupportedNetwork();
    }
}
