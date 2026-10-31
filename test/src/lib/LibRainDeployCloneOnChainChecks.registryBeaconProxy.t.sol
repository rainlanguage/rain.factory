// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/UpgradeableBeacon.sol";
import {DeployDeclaration, DeploySuite} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeploy} from "rain-deploy-0.1.29/src/lib/LibRainDeploy.sol";
import {LibRainDeployCloneMechanism} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {LibRainDeployCloneOnChainChecks} from "../../../src/lib/LibRainDeployCloneOnChainChecks.sol";
import {
    LibRainDeployRegistryBeaconProxy,
    RegistryBeaconProxyTarget
} from "../../../src/lib/LibRainDeployRegistryBeaconProxy.sol";
import {LibRegistryBeaconProxyTest} from "../../lib/LibRegistryBeaconProxyTest.sol";
import {MockCloneableV2} from "../../concrete/MockCloneableV2.sol";

/// @title LibRainDeployCloneOnChainChecksRegistryBeaconProxyTest
/// @notice `checkOnChain` passes a registry beacon proxy suite whose binding on the network resolves to its declared
/// beacon, with no beacon in the layer config, and refuses `RegistryBeaconProxyBeaconMismatch` when the binding
/// resolves to another.
contract LibRainDeployCloneOnChainChecksRegistryBeaconProxyTest is Test {
    uint256 constant ARBITRUM_ONE_CHAIN_ID = 42161;

    function checkOnChain(DeploySuite memory suite) external view {
        DeployDeclaration memory d;
        LibRainDeployCloneMechanism.extend(d);
        LibRainDeployCloneOnChainChecks.checkOnChain(
            d, suite, LibRainDeploy.ARBITRUM_ONE, ARBITRUM_ONE_CHAIN_ID, suite.storedDeployedAddress
        );
    }

    function liveSuite() internal returns (RegistryBeaconProxyTarget memory, DeploySuite memory) {
        RegistryBeaconProxyTarget memory target = LibRegistryBeaconProxyTest.live(
            vm, address(new MockCloneableV2()), address(this), hex"deadbeef", bytes32(uint256(5))
        );
        DeploySuite memory suite =
        LibRainDeployCloneMechanism.registryBeaconProxyCandidate(
            LibRegistryBeaconProxyTest.declared(
                "registry-beacon-proxy@0_0_1", target, LibRegistryBeaconProxyTest.runtimeOf(vm, target)
            )
        )
        .snapshot;
        return (target, suite);
    }

    function testCheckOnChainPassesARegistryBeaconProxyWhoseBindingResolvesToItsDeclaredBeacon() external {
        (, DeploySuite memory suite) = liveSuite();
        this.checkOnChain(suite);
    }

    function testCheckOnChainRefusesARegistryBeaconProxyWhoseBindingResolvesToAnotherBeacon() external {
        (RegistryBeaconProxyTarget memory target, DeploySuite memory suite) = liveSuite();
        address bound = address(new UpgradeableBeacon(address(new MockCloneableV2()), address(this)));
        vm.warp(block.timestamp + 1);
        LibRegistryBeaconProxyTest.bind(vm, target.registry, bound);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRainDeployRegistryBeaconProxy.RegistryBeaconProxyBeaconMismatch.selector,
                LibRainDeploy.ARBITRUM_ONE,
                target.beacon,
                bound
            )
        );
        this.checkOnChain(suite);
    }
}
