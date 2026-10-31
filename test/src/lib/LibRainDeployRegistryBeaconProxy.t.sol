// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/UpgradeableBeacon.sol";
import {ICloneableFactoryV7} from "../../../src/interface/ICloneableFactoryV7.sol";
import {REGISTRY_BEACON_PROXY_CREATION_CODE} from "../../../src/generated/RegistryBeaconProxy.sol";
import {DelegatedBeacon} from "../../../src/lib/LibICloneableFactoryV5.sol";
import {BeaconBindingTypeMismatch} from "../../../src/lib/LibICloneableFactoryV7.sol";
import {TestCloneFactory} from "../../../src/test/TestCloneFactory.sol";
import {LibRainDeploy} from "rain-deploy-0.1.29/src/lib/LibRainDeploy.sol";
import {IConfigRegistryV5} from "rain-deploy-0.1.29/src/interface/IConfigRegistryV5.sol";
import {
    LibRainDeployRegistryBeaconProxy,
    REGISTRY_BEACON_PROXY_ARTIFACT_PATH,
    RegistryBeaconProxyTarget
} from "../../../src/lib/LibRainDeployRegistryBeaconProxy.sol";
import {RegistryBeaconProxy} from "../../../script/RegistryBeaconProxy.sol";
import {LibRegistryBeaconProxyTest} from "../../lib/LibRegistryBeaconProxyTest.sol";
import {MockCloneableV2} from "../../concrete/MockCloneableV2.sol";
import {MockDirtyOwnerCloneable} from "../../concrete/MockDirtyOwnerCloneable.sol";
import {MockLongOwnerCloneable} from "../../concrete/MockLongOwnerCloneable.sol";
import {MockMisansweringOwnerCloneable} from "../../concrete/MockMisansweringOwnerCloneable.sol";
import {MockOriginOwnedCloneable} from "../../concrete/MockOriginOwnedCloneable.sol";

/// @title LibRainDeployRegistryBeaconProxyTest
/// @notice `LibRainDeployRegistryBeaconProxy`'s derivations, generator and deploy step, against a real
/// `TestCloneFactory`, `ConfigRegistry` and `UpgradeableBeacon`.
contract LibRainDeployRegistryBeaconProxyTest is Test {
    bytes32 constant TEST_SALT = 0x1122334455667788990011223344556677889900112233445566778899001122;

    bytes constant TEST_DATA = hex"deadbeefcafe0102030405060708090a0b0c0d0e0f";

    address constant DEPLOYER = address(0xD3910E8);

    function externalDeployStep(string memory network, address deployer, bytes memory targetData)
        external
        returns (address)
    {
        return LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployStep(vm, network, deployer, targetData);
    }

    function externalRuntimeCode(
        RegistryBeaconProxyTarget memory target,
        address implementation,
        bytes memory implementationCode
    ) external returns (bytes memory) {
        return LibRainDeployRegistryBeaconProxy.registryBeaconProxyRuntimeCode(
            vm, target, implementation, implementationCode
        );
    }

    function externalCheckBeacon(string memory network, RegistryBeaconProxyTarget memory target) external view {
        LibRainDeployRegistryBeaconProxy.checkBeacon(network, target);
    }

    function liveTarget(address implementation, bytes memory data) internal returns (RegistryBeaconProxyTarget memory) {
        return LibRegistryBeaconProxyTest.live(vm, implementation, address(this), data, TEST_SALT);
    }

    function copy(RegistryBeaconProxyTarget memory target) internal pure returns (RegistryBeaconProxyTarget memory) {
        return RegistryBeaconProxyTarget({
            factory: target.factory,
            registry: target.registry,
            authority: target.authority,
            beaconName: target.beaconName,
            beacon: target.beacon,
            data: target.data,
            salt: target.salt
        });
    }

    function expectSeatsDeployKey(RegistryBeaconProxyTarget memory target) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRainDeployRegistryBeaconProxy.RegistryBeaconProxySeatsDeployKey.selector,
                LibRainDeploy.ARBITRUM_ONE,
                LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(target)
            )
        );
    }

    function testRegistryBeaconProxyCreationCode(RegistryBeaconProxyTarget memory target) external pure {
        bytes memory arguments = abi.encode(target.registry, target.authority, target.beaconName);
        assertEq(
            LibRainDeployRegistryBeaconProxy.registryBeaconProxyCreationCode(target),
            bytes.concat(REGISTRY_BEACON_PROXY_CREATION_CODE, arguments)
        );
    }

    function testRegistryBeaconProxyAddressIsTheV7Formula(RegistryBeaconProxyTarget memory target) external pure {
        bytes32 salt =
            keccak256(abi.encode(keccak256("rain.factory.registrybeaconproxy"), target.salt, keccak256(target.data)));
        bytes32 initCodeHash = keccak256(
            bytes.concat(
                type(RegistryBeaconProxy).creationCode, abi.encode(target.registry, target.authority, target.beaconName)
            )
        );
        address expected =
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), target.factory, salt, initCodeHash)))));
        assertEq(LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(target), expected);
    }

    function testRegistryBeaconProxyAddressMatchesARealFactory(bytes32 salt, bytes memory data) external {
        RegistryBeaconProxyTarget memory target =
            LibRegistryBeaconProxyTest.live(vm, address(new MockCloneableV2()), address(this), data, salt);
        ICloneableFactoryV7 factory = ICloneableFactoryV7(target.factory);
        address expected = LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(target);
        assertEq(
            factory.predictRegistryBeaconProxyAddress(target.registry, target.authority, target.beaconName, data, salt),
            expected
        );
        assertEq(
            factory.registryBeaconProxy(target.registry, target.authority, target.beaconName, data, salt), expected
        );
    }

    function testRegistryBeaconProxyAddressMovesWithEveryCommittedInputButNotTheBeacon(
        RegistryBeaconProxyTarget memory target,
        uint160 delta,
        bytes32 other
    ) external pure {
        vm.assume(delta != 0 && other != target.salt && other != target.beaconName);
        address base = LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(target);
        RegistryBeaconProxyTarget memory moved = copy(target);
        unchecked {
            moved.factory = address(uint160(target.factory) + delta);
        }
        assertNotEq(LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(moved), base, "factory");
        moved = copy(target);
        unchecked {
            moved.registry = address(uint160(target.registry) + delta);
        }
        assertNotEq(LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(moved), base, "registry");
        moved = copy(target);
        unchecked {
            moved.authority = address(uint160(target.authority) + delta);
        }
        assertNotEq(LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(moved), base, "authority");
        moved = copy(target);
        moved.beaconName = other;
        assertNotEq(LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(moved), base, "beacon name");
        moved = copy(target);
        moved.salt = other;
        assertNotEq(LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(moved), base, "salt");
        moved = copy(target);
        moved.data = abi.encodePacked(target.data, hex"00");
        assertNotEq(LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(moved), base, "data");
        moved = copy(target);
        unchecked {
            moved.beacon = address(uint160(target.beacon) + delta);
        }
        assertEq(LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(moved), base, "beacon");
    }

    function testRegistryBeaconProxyArtifactPathResolvesToNothing() external view {
        string[] memory parts = vm.split(REGISTRY_BEACON_PROXY_ARTIFACT_PATH, ".sol:");
        assertEq(parts.length, 2, "one .sol: separator");
        assertEq(parts[1], "RegistryBeaconProxy", "contract name");
        try vm.getCode(REGISTRY_BEACON_PROXY_ARTIFACT_PATH) returns (bytes memory) {
            revert("artifact path resolved");
        } catch {}
    }

    function testRegistryBeaconProxyRuntimeCodeIsWhatARealFactoryDeploys(
        address registryAt,
        address beaconAt,
        bytes32 salt,
        bytes memory data
    ) external {
        assumeNotForgeAddress(registryAt);
        assumeNotForgeAddress(beaconAt);
        vm.assume(uint160(registryAt) > 0xffff && uint160(beaconAt) > 0xffff && registryAt != beaconAt);
        vm.assume(registryAt.code.length == 0 && beaconAt.code.length == 0);
        MockCloneableV2 implementation = new MockCloneableV2();
        TestCloneFactory factory = new TestCloneFactory();
        vm.assume(registryAt != address(implementation) && beaconAt != address(implementation));
        vm.assume(registryAt != address(factory) && beaconAt != address(factory));
        RegistryBeaconProxyTarget memory target = RegistryBeaconProxyTarget({
            factory: address(factory),
            registry: registryAt,
            authority: LibRegistryBeaconProxyTest.AUTHORITY,
            beaconName: LibRegistryBeaconProxyTest.BEACON_NAME,
            beacon: beaconAt,
            data: data,
            salt: salt
        });

        bytes memory generated = LibRainDeployRegistryBeaconProxy.registryBeaconProxyRuntimeCode(
            vm, target, address(implementation), address(implementation).code
        );
        assertEq(registryAt.code.length, 0, "registry left behind");
        assertEq(beaconAt.code.length, 0, "beacon left behind");

        deployCodeTo("ConfigRegistry.sol:ConfigRegistry", registryAt);
        deployCodeTo(
            "UpgradeableBeacon.sol:UpgradeableBeacon", abi.encode(address(implementation), address(this)), beaconAt
        );
        LibRegistryBeaconProxyTest.bind(vm, registryAt, beaconAt);
        address proxy = factory.registryBeaconProxy(
            registryAt, LibRegistryBeaconProxyTest.AUTHORITY, LibRegistryBeaconProxyTest.BEACON_NAME, data, salt
        );
        assertEq(proxy, LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(target));
        assertEq(proxy.code, generated);
        assertEq(MockCloneableV2(proxy).version(), 2);
    }

    function testRegistryBeaconProxyRuntimeCodeCommitsToTheBeacon(uint160 delta) external {
        vm.assume(delta != 0);
        RegistryBeaconProxyTarget memory target = RegistryBeaconProxyTarget({
            factory: address(0xFAC7),
            registry: address(0x12E6),
            authority: LibRegistryBeaconProxyTest.AUTHORITY,
            beaconName: LibRegistryBeaconProxyTest.BEACON_NAME,
            beacon: address(0xBEAC0),
            data: TEST_DATA,
            salt: TEST_SALT
        });
        MockCloneableV2 implementation = new MockCloneableV2();
        bytes memory base = LibRainDeployRegistryBeaconProxy.registryBeaconProxyRuntimeCode(
            vm, target, address(implementation), address(implementation).code
        );
        RegistryBeaconProxyTarget memory moved = copy(target);
        unchecked {
            moved.beacon = address(uint160(target.beacon) + delta);
        }
        vm.assume(
            uint160(moved.beacon) > 0xffff && moved.beacon != target.registry && moved.beacon != address(implementation)
                && moved.beacon.code.length == 0
        );
        assumeNotForgeAddress(moved.beacon);
        assertNotEq(
            LibRainDeployRegistryBeaconProxy.registryBeaconProxyRuntimeCode(
                vm, moved, address(implementation), address(implementation).code
            ),
            base
        );
    }

    function testRegistryBeaconProxyRuntimeCodeRefusesAnImplementationWithoutCode() external {
        RegistryBeaconProxyTarget memory target = RegistryBeaconProxyTarget({
            factory: address(0xFAC7),
            registry: address(0x12E6),
            authority: LibRegistryBeaconProxyTest.AUTHORITY,
            beaconName: LibRegistryBeaconProxyTest.BEACON_NAME,
            beacon: address(0xBEAC0),
            data: TEST_DATA,
            salt: TEST_SALT
        });
        address implementation = address(0x1A9E);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRainDeployRegistryBeaconProxy.RegistryBeaconProxyBeaconConstructionFailed.selector,
                target.beacon,
                implementation
            )
        );
        this.externalRuntimeCode(target, implementation, "");
    }

    function testCheckBeaconAcceptsTheBoundBeacon() external {
        RegistryBeaconProxyTarget memory target = liveTarget(address(new MockCloneableV2()), TEST_DATA);
        this.externalCheckBeacon(LibRainDeploy.ARBITRUM_ONE, target);
    }

    function testCheckBeaconRefusesAnotherBeacon(address declared) external {
        RegistryBeaconProxyTarget memory target = liveTarget(address(new MockCloneableV2()), TEST_DATA);
        vm.assume(declared != target.beacon);
        address bound = target.beacon;
        target.beacon = declared;
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRainDeployRegistryBeaconProxy.RegistryBeaconProxyBeaconMismatch.selector,
                LibRainDeploy.ARBITRUM_ONE,
                declared,
                bound
            )
        );
        this.externalCheckBeacon(LibRainDeploy.ARBITRUM_ONE, target);
    }

    function testRegistryBeaconProxyDeployStepDeploysTheDerivedAddress() external {
        RegistryBeaconProxyTarget memory target = liveTarget(address(new MockCloneableV2()), TEST_DATA);
        address deployed = this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(target));
        assertEq(deployed, LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(target));
        assertEq(deployed.code, LibRegistryBeaconProxyTest.runtimeOf(vm, target));
        assertEq(MockCloneableV2(deployed).sInitData(), TEST_DATA);
    }

    function testRegistryBeaconProxyDeployStepReturnsWhereTheFactoryDeployed() external {
        RegistryBeaconProxyTarget memory target = liveTarget(address(new MockCloneableV2()), TEST_DATA);
        address elsewhere =
            address(uint160(LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(target)) + 1);
        vm.mockCall(
            target.factory,
            abi.encodeWithSelector(ICloneableFactoryV7.registryBeaconProxy.selector),
            abi.encode(elsewhere)
        );
        address deployed = this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(target));
        assertEq(deployed, elsewhere);
    }

    function testRegistryBeaconProxyDeployStepStopsItsBroadcast() external {
        RegistryBeaconProxyTarget memory target = liveTarget(address(new MockCloneableV2()), TEST_DATA);
        this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(target));
        vm.startBroadcast(DEPLOYER);
        vm.stopBroadcast();
    }

    function testRegistryBeaconProxyDeployStepPredictionMismatchReverts() external {
        RegistryBeaconProxyTarget memory target = liveTarget(address(new MockCloneableV2()), TEST_DATA);
        address expected = LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(target);
        address predicted = address(uint160(expected) + 1);
        vm.mockCall(
            target.factory,
            abi.encodeWithSelector(ICloneableFactoryV7.predictRegistryBeaconProxyAddress.selector),
            abi.encode(predicted)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRainDeployRegistryBeaconProxy.RegistryBeaconProxyFactoryPredictionMismatch.selector,
                LibRainDeploy.ARBITRUM_ONE,
                target.factory,
                expected,
                predicted
            )
        );
        this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(target));
        assertEq(expected.code.length, 0);
    }

    function testRegistryBeaconProxyDeployStepRefusesABindingToAnotherBeacon() external {
        RegistryBeaconProxyTarget memory target = liveTarget(address(new MockCloneableV2()), TEST_DATA);
        address bound = address(new UpgradeableBeacon(address(new MockCloneableV2()), address(this)));
        vm.warp(block.timestamp + 1);
        LibRegistryBeaconProxyTest.bind(vm, target.registry, bound);
        address expected = LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(target);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRainDeployRegistryBeaconProxy.RegistryBeaconProxyBeaconMismatch.selector,
                LibRainDeploy.ARBITRUM_ONE,
                target.beacon,
                bound
            )
        );
        this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(target));
        assertEq(expected.code.length, 0);
    }

    function testRegistryBeaconProxyDeployStepRefusesABindingNotTypedAddress() external {
        RegistryBeaconProxyTarget memory target = liveTarget(address(new MockCloneableV2()), TEST_DATA);
        vm.warp(block.timestamp + 1);
        vm.prank(target.authority);
        IConfigRegistryV5(target.registry)
            .registerV5(target.authority, target.beaconName, "uint256", abi.encode(target.beacon), "");
        address expected = LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(target);
        vm.expectRevert(
            abi.encodeWithSelector(
                BeaconBindingTypeMismatch.selector,
                target.registry,
                target.authority,
                target.beaconName,
                keccak256("uint256")
            )
        );
        this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(target));
        assertEq(expected.code.length, 0);
    }

    function testRegistryBeaconProxyDeployStepRefusesADelegatedBeacon(address delegate) external {
        RegistryBeaconProxyTarget memory target = liveTarget(address(new MockCloneableV2()), TEST_DATA);
        vm.etch(target.beacon, abi.encodePacked(hex"ef0100", delegate));
        address expected = LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(target);
        vm.expectRevert(abi.encodeWithSelector(DelegatedBeacon.selector));
        this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(target));
        assertEq(expected.code.length, 0);
    }

    function testRegistryBeaconProxyDeployStepRefusesTheDeployKeySeated() external {
        RegistryBeaconProxyTarget memory target =
            liveTarget(address(new MockOriginOwnedCloneable()), abi.encode(address(0)));
        expectSeatsDeployKey(target);
        this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(target));
    }

    function testRegistryBeaconProxyDeployStepAcceptsAnotherOwner(address owner) external {
        vm.assume(owner != DEPLOYER && owner != address(0));
        RegistryBeaconProxyTarget memory target = liveTarget(address(new MockOriginOwnedCloneable()), abi.encode(owner));
        address deployed = this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(target));
        assertEq(MockOriginOwnedCloneable(deployed).owner(), owner);
    }

    function testRegistryBeaconProxyDeployStepAcceptsAnOwnerThatDoesNotAnswer(bool short) external {
        RegistryBeaconProxyTarget memory target =
            liveTarget(address(new MockMisansweringOwnerCloneable()), abi.encode(short));
        address deployed = this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(target));
        assertEq(deployed, LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(target));
        (bool answered, bytes memory owner) = deployed.staticcall(abi.encodeWithSignature("owner()"));
        assertEq(answered, short);
        assertEq(owner.length, short ? 0x1f : 0x20);
        assertEq(owner, short ? owner : abi.encode(DEPLOYER));
    }

    function testRegistryBeaconProxyDeployStepRefusesTheDeployKeyUnderDirtyHighBits(uint96 high) external {
        vm.assume(high != 0);
        RegistryBeaconProxyTarget memory target = liveTarget(address(new MockDirtyOwnerCloneable()), abi.encode(high));
        expectSeatsDeployKey(target);
        this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(target));
    }

    function testRegistryBeaconProxyDeployStepRefusesTheDeployKeyInALongerAnswer(bytes32 trailing) external {
        RegistryBeaconProxyTarget memory target =
            liveTarget(address(new MockLongOwnerCloneable()), abi.encode(trailing));
        expectSeatsDeployKey(target);
        this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(target));
    }
}
