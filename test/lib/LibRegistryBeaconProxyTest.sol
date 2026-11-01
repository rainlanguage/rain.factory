// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.17.0/src/Vm.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/UpgradeableBeacon.sol";
import {ConfigRegistry} from "rain-deploy-0.1.29/src/concrete/ConfigRegistry.sol";
import {IConfigRegistryV5} from "rain-deploy-0.1.29/src/interface/IConfigRegistryV5.sol";
import {DeployDependency} from "rain-deploy-0.1.29/src/lib/LibRainDeploy.sol";
import {TestCloneFactory} from "../../src/test/TestCloneFactory.sol";
import {
    LibRainDeployRegistryBeaconProxy,
    RegistryBeaconProxyDeploy,
    RegistryBeaconProxyTarget
} from "../../src/lib/LibRainDeployRegistryBeaconProxy.sol";

/// @title LibRegistryBeaconProxyTest
/// @notice The registry beacon proxy declarations the tests share.
library LibRegistryBeaconProxyTest {
    address internal constant AUTHORITY =
        address(uint160(uint256(keccak256("rain.factory.test.registry-beacon-proxy.authority"))));
    bytes32 internal constant BEACON_NAME = keccak256("rain.factory.test.registry-beacon-proxy.beacon");

    /// Binds `BEACON_NAME` under `AUTHORITY` in `registry` to `beacon`.
    /// @param vm The Vm instance to prank with.
    /// @param registry A `ConfigRegistry`.
    /// @param beacon The beacon.
    function bind(Vm vm, address registry, address beacon) internal {
        vm.prank(AUTHORITY);
        IConfigRegistryV5(registry).registerV5(AUTHORITY, BEACON_NAME, "address", abi.encode(beacon), "");
    }

    /// A fresh `TestCloneFactory`, `ConfigRegistry` and `UpgradeableBeacon` serving `implementation`, the beacon
    /// bound in the registry.
    /// @param vm The Vm instance to prank with.
    /// @param implementation The implementation the beacon serves.
    /// @param beaconOwner The beacon's owner.
    /// @param data The init data.
    /// @param salt The salt.
    /// @return The factory call.
    function live(Vm vm, address implementation, address beaconOwner, bytes memory data, bytes32 salt)
        internal
        returns (RegistryBeaconProxyTarget memory)
    {
        address registry = address(new ConfigRegistry());
        address beacon = address(new UpgradeableBeacon(implementation, beaconOwner));
        bind(vm, registry, beacon);
        return RegistryBeaconProxyTarget({
            factory: address(new TestCloneFactory()),
            registry: registry,
            authority: AUTHORITY,
            beaconName: BEACON_NAME,
            beacon: beacon,
            data: data,
            salt: salt
        });
    }

    /// `target` declared, its factory, registry and beacon its dependencies with the code they hold now.
    /// @param suite The suite key.
    /// @param target The factory call.
    /// @param runtimeCode The proxy's declared runtime code.
    /// @return The declaration.
    function declared(string memory suite, RegistryBeaconProxyTarget memory target, bytes memory runtimeCode)
        internal
        view
        returns (RegistryBeaconProxyDeploy memory)
    {
        DeployDependency[] memory dependencies = new DeployDependency[](3);
        dependencies[0] = DeployDependency({deployedAddress: target.factory, runtimeCode: target.factory.code});
        dependencies[1] = DeployDependency({deployedAddress: target.registry, runtimeCode: target.registry.code});
        dependencies[2] = DeployDependency({deployedAddress: target.beacon, runtimeCode: target.beacon.code});
        return RegistryBeaconProxyDeploy({
            suite: suite,
            factory: target.factory,
            registry: target.registry,
            authority: target.authority,
            beaconName: target.beaconName,
            beacon: target.beacon,
            data: target.data,
            salt: target.salt,
            dependencies: dependencies,
            runtimeCode: runtimeCode
        });
    }

    /// The generated runtime code of `target`'s proxy, its beacon serving the implementation the real beacon at
    /// `target.beacon` serves.
    /// @param vm The Vm instance to generate with.
    /// @param target The factory call, a real beacon at its `beacon`.
    /// @return The proxy's runtime code.
    function runtimeOf(Vm vm, RegistryBeaconProxyTarget memory target) internal returns (bytes memory) {
        address implementation = UpgradeableBeacon(target.beacon).implementation();
        return LibRainDeployRegistryBeaconProxy.registryBeaconProxyRuntimeCode(
            vm, target, implementation, implementation.code
        );
    }
}
