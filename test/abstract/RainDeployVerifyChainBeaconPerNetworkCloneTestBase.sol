// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {UpgradeableBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/UpgradeableBeacon.sol";
import {DeployDeclaration, DeploySuite} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {DerivedDeploy} from "rain-deploy-0.1.29/src/abstract/RainDeployVerifyBase.sol";
import {LibRainDeploy} from "rain-deploy-0.1.29/src/lib/LibRainDeploy.sol";
import {LibRainDeployBeaconResolution} from "../../src/lib/LibRainDeployBeaconResolution.sol";
import {
    PER_NETWORK_CLONE_ARBITRUM_ONE_CHAIN_ID,
    PER_NETWORK_CLONE_POLYGON_CHAIN_ID,
    perNetworkCloneReleaseAddress
} from "./PerNetworkCloneDeploys.sol";
import {PerNetworkCloneBeaconVerifyChain} from "./PerNetworkCloneBeaconVerifyChain.sol";

/// @title RainDeployVerifyChainBeaconPerNetworkCloneTestBase
/// @notice The per-network clone beacon tests, run over each per-network clone release fixture.
abstract contract RainDeployVerifyChainBeaconPerNetworkCloneTestBase is PerNetworkCloneBeaconVerifyChain {
    function setUp() external {
        DeploySuite memory release = released()[0];
        for (uint256 i = 0; i < release.dependencies.length; i++) {
            vm.etch(release.dependencies[i].deployedAddress, release.dependencies[i].runtimeCode);
            vm.makePersistent(release.dependencies[i].deployedAddress);
        }
        address[] memory addresses = new address[](2);
        addresses[0] = perNetworkCloneReleaseAddress(PER_NETWORK_CLONE_ARBITRUM_ONE_CHAIN_ID);
        addresses[1] = perNetworkCloneReleaseAddress(PER_NETWORK_CLONE_POLYGON_CHAIN_ID);
        for (uint256 i = 0; i < addresses.length; i++) {
            vm.etch(addresses[i], release.storedRuntimeCode);
            vm.makePersistent(addresses[i]);
        }
        sBeacon = address(new UpgradeableBeacon(addresses[1], OWNER));
        vm.makePersistent(sBeacon);
    }

    function testBeaconImplementationAtAnotherNetworksCloneIsRefused() external {
        address polygonAddress = perNetworkCloneReleaseAddress(PER_NETWORK_CLONE_POLYGON_CHAIN_ID);
        address arbitrumAddress = perNetworkCloneReleaseAddress(PER_NETWORK_CLONE_ARBITRUM_ONE_CHAIN_ID);
        vm.prank(OWNER);
        UpgradeableBeacon(sBeacon).upgradeTo(arbitrumAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRainDeploy.UnexpectedResolvedAddress.selector,
                LibRainDeploy.POLYGON,
                sBeacon,
                0,
                polygonAddress,
                arbitrumAddress
            )
        );
        this.testSuitesLiveOnEverySupportedNetwork();
    }

    /// External wrapper for `resolveBeacon` over the declared beacon on one network.
    /// @param chainId The network.
    /// @return The beacon's address on it.
    function externalResolveBeacon(uint256 chainId) external returns (address) {
        DeployDeclaration memory d = declaration();
        return LibRainDeployBeaconResolution.resolveBeacon(
                d,
                beacons()[0].beacon,
                chainId,
                0,
                new DeploySuite[](d.released.length),
                new DerivedDeploy[](d.released.length)
            ).beacon.beacon;
    }

    function testBeaconNamedBySuiteIsAtItsNetworksClone() external {
        sBeaconBySuite = true;
        address resolved = this.externalResolveBeacon(PER_NETWORK_CLONE_POLYGON_CHAIN_ID);
        assertEq(resolved, perNetworkCloneReleaseAddress(PER_NETWORK_CLONE_POLYGON_CHAIN_ID));
        assertTrue(resolved != perNetworkCloneReleaseAddress(PER_NETWORK_CLONE_ARBITRUM_ONE_CHAIN_ID));
    }
}
