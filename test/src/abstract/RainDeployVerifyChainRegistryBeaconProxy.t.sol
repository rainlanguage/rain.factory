// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Vm} from "forge-std-1.17.0/src/Vm.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/UpgradeableBeacon.sol";
import {DeployDeclaration, DeploySuite} from "rain-deploy-0.1.30/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeploy} from "rain-deploy-0.1.30/src/lib/LibRainDeploy.sol";
import {LibRainDeployCloneMechanism} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {
    LibRainDeployRegistryBeaconProxy,
    RegistryBeaconProxyParams
} from "../../../src/lib/LibRainDeployRegistryBeaconProxy.sol";
import {
    PER_NETWORK_CLONE_ARBITRUM_ONE_CHAIN_ID,
    PER_NETWORK_CLONE_POLYGON_CHAIN_ID,
    perNetworkCloneReleaseAddress
} from "../../abstract/PerNetworkCloneDeploys.sol";
import {PerNetworkCloneBeaconVerifyChain} from "../../abstract/PerNetworkCloneBeaconVerifyChain.sol";
import {LocalForkVm} from "../../concrete/LocalForkVm.sol";
import {MockCloneFactory} from "../../concrete/MockCloneFactory.sol";
import {LibRegistryBeaconProxyTest} from "../../lib/LibRegistryBeaconProxyTest.sol";

/// @title RainDeployVerifyChainRegistryBeaconProxyTest
/// @notice The chain matrix, on local forks, over a registry beacon proxy suite whose binding resolves to the beacon
/// declared on Polygon.
contract RainDeployVerifyChainRegistryBeaconProxyTest is PerNetworkCloneBeaconVerifyChain {
    string constant PROXY_SUITE = "registry-beacon-proxy@0_0_1";

    RegistryBeaconProxyParams internal sParams;

    /// Puts the per-network clone release and the beacon at its Polygon clone on every fork, as
    /// `RainDeployVerifyChainBeaconProxyTest` does, plus a factory and a registry binding the beacon.
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
        sParams = LibRegistryBeaconProxyTest.live(vm, addresses[1], OWNER, hex"deadbeef", bytes32(uint256(5)));
        sBeacon = sParams.beacon;
        vm.makePersistent(sParams.factory);
        vm.makePersistent(sParams.registry);
        vm.makePersistent(sBeacon);
    }

    function liveProxySuite() internal returns (DeploySuite memory) {
        RegistryBeaconProxyParams memory params = sParams;
        DeploySuite memory suite =
        LibRainDeployCloneMechanism.registryBeaconProxyCandidate(
            LibRegistryBeaconProxyTest.declared(PROXY_SUITE, params, LibRegistryBeaconProxyTest.runtimeOf(vm, params))
        )
        .snapshot;
        vm.etch(suite.storedDeployedAddress, suite.storedRuntimeCode);
        vm.makePersistent(suite.storedDeployedAddress);
        return suite;
    }

    /// The matrix on local forks over `suite` alone, required on Polygon.
    function externalCheckOnLocalForks(DeploySuite memory suite) external {
        DeploySuite[] memory suites = new DeploySuite[](1);
        suites[0] = suite;
        string[] memory polygon = new string[](1);
        polygon[0] = LibRainDeploy.POLYGON;
        suites[0].networks = polygon;
        DeployDeclaration memory d = declaration();
        checkDeployedOnNetworks(
            d, Vm(address(new LocalForkVm())), LibRainDeploy.declaredNetworkConfigs(d.networks), suites
        );
    }

    function testRegistryBeaconProxyWhoseBindingResolvesToItsDeclaredBeaconPasses() external {
        this.externalCheckOnLocalForks(liveProxySuite());
    }

    function testRegistryBeaconProxyWhoseBindingResolvesToAnotherBeaconIsRefused() external {
        DeploySuite memory suite = liveProxySuite();
        address other =
            address(new UpgradeableBeacon(perNetworkCloneReleaseAddress(PER_NETWORK_CLONE_POLYGON_CHAIN_ID), OWNER));
        vm.makePersistent(other);
        vm.warp(block.timestamp + 1);
        LibRegistryBeaconProxyTest.bind(vm, sParams.registry, other);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRainDeployRegistryBeaconProxy.RegistryBeaconProxyBeaconMismatch.selector,
                LibRainDeploy.POLYGON,
                sBeacon,
                other
            )
        );
        this.externalCheckOnLocalForks(suite);
    }

    function testRegistryBeaconProxyWithAChangedFactoryIsRefusedNamingNetworkAndDependency() external {
        DeploySuite memory suite = liveProxySuite();
        bytes32 declared = sParams.factory.codehash;
        vm.etch(sParams.factory, type(MockCloneFactory).runtimeCode);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRainDeploy.DependencyChanged.selector,
                LibRainDeploy.POLYGON,
                sParams.factory,
                declared,
                keccak256(type(MockCloneFactory).runtimeCode)
            )
        );
        this.externalCheckOnLocalForks(suite);
    }

    function testRegistryBeaconProxyNotLiveIsRefused() external {
        DeploySuite memory suite = liveProxySuite();
        vm.etch(suite.storedDeployedAddress, hex"");
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRainDeploy.NotDeployedOnNetwork.selector, LibRainDeploy.POLYGON, suite.storedDeployedAddress
            )
        );
        this.externalCheckOnLocalForks(suite);
    }
}
