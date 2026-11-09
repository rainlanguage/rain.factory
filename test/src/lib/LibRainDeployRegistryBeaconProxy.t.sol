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
import {LibRainDeploy} from "rain-deploy-0.1.30/src/lib/LibRainDeploy.sol";
import {IConfigRegistryV5} from "rain-deploy-0.1.30/src/interface/IConfigRegistryV5.sol";
import {
    LibRainDeployRegistryBeaconProxy,
    REGISTRY_BEACON_PROXY_ARTIFACT_PATH,
    RegistryBeaconProxyParams
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

    function externalDeployStep(string memory network, address deployer, bytes memory paramsData)
        external
        returns (address)
    {
        return LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployStep(vm, network, deployer, paramsData);
    }

    function externalRuntimeCode(
        RegistryBeaconProxyParams memory params,
        address implementation,
        bytes memory implementationCode
    ) external returns (bytes memory) {
        return LibRainDeployRegistryBeaconProxy.registryBeaconProxyRuntimeCode(
            vm, params, implementation, implementationCode
        );
    }

    function externalCheckBeacon(string memory network, RegistryBeaconProxyParams memory params) external view {
        LibRainDeployRegistryBeaconProxy.checkBeacon(network, params);
    }

    function liveParams(address implementation, bytes memory data) internal returns (RegistryBeaconProxyParams memory) {
        return LibRegistryBeaconProxyTest.live(vm, implementation, address(this), data, TEST_SALT);
    }

    function unlivedParams() internal pure returns (RegistryBeaconProxyParams memory) {
        return RegistryBeaconProxyParams({
            factory: address(0xFAC7),
            registry: address(0x12E6),
            authority: LibRegistryBeaconProxyTest.AUTHORITY,
            beaconName: LibRegistryBeaconProxyTest.BEACON_NAME,
            beacon: address(0xBEAC0),
            data: TEST_DATA,
            salt: TEST_SALT
        });
    }

    function copy(RegistryBeaconProxyParams memory params) internal pure returns (RegistryBeaconProxyParams memory) {
        return RegistryBeaconProxyParams({
            factory: params.factory,
            registry: params.registry,
            authority: params.authority,
            beaconName: params.beaconName,
            beacon: params.beacon,
            data: params.data,
            salt: params.salt
        });
    }

    function expectSeatsDeployKey(RegistryBeaconProxyParams memory params) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRainDeployRegistryBeaconProxy.RegistryBeaconProxySeatsDeployKey.selector,
                LibRainDeploy.ARBITRUM_ONE,
                LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(params)
            )
        );
    }

    function testRegistryBeaconProxyCreationCode(RegistryBeaconProxyParams memory params) external pure {
        bytes memory arguments = abi.encode(params.registry, params.authority, params.beaconName);
        assertEq(
            LibRainDeployRegistryBeaconProxy.registryBeaconProxyCreationCode(params),
            bytes.concat(REGISTRY_BEACON_PROXY_CREATION_CODE, arguments)
        );
    }

    function testRegistryBeaconProxyAddressIsTheV7Formula(RegistryBeaconProxyParams memory params) external pure {
        bytes32 salt =
            keccak256(abi.encode(keccak256("rain.factory.registrybeaconproxy"), params.salt, keccak256(params.data)));
        bytes32 initCodeHash = keccak256(
            bytes.concat(
                type(RegistryBeaconProxy).creationCode, abi.encode(params.registry, params.authority, params.beaconName)
            )
        );
        address expected =
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), params.factory, salt, initCodeHash)))));
        assertEq(LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(params), expected);
    }

    function testRegistryBeaconProxyAddressMatchesARealFactory(bytes32 salt, bytes memory data) external {
        RegistryBeaconProxyParams memory params =
            LibRegistryBeaconProxyTest.live(vm, address(new MockCloneableV2()), address(this), data, salt);
        ICloneableFactoryV7 factory = ICloneableFactoryV7(params.factory);
        address expected = LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(params);
        assertEq(
            factory.predictRegistryBeaconProxyAddress(params.registry, params.authority, params.beaconName, data, salt),
            expected
        );
        assertEq(
            factory.registryBeaconProxy(params.registry, params.authority, params.beaconName, data, salt), expected
        );
    }

    function testRegistryBeaconProxyAddressMovesWithEveryCommittedInputButNotTheBeacon(
        RegistryBeaconProxyParams memory params,
        uint160 delta,
        bytes32 other
    ) external pure {
        vm.assume(delta != 0 && other != params.salt && other != params.beaconName);
        address base = LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(params);
        RegistryBeaconProxyParams memory moved = copy(params);
        unchecked {
            moved.factory = address(uint160(params.factory) + delta);
        }
        assertNotEq(LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(moved), base, "factory");
        moved = copy(params);
        unchecked {
            moved.registry = address(uint160(params.registry) + delta);
        }
        assertNotEq(LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(moved), base, "registry");
        moved = copy(params);
        unchecked {
            moved.authority = address(uint160(params.authority) + delta);
        }
        assertNotEq(LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(moved), base, "authority");
        moved = copy(params);
        moved.beaconName = other;
        assertNotEq(LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(moved), base, "beacon name");
        moved = copy(params);
        moved.salt = other;
        assertNotEq(LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(moved), base, "salt");
        moved = copy(params);
        moved.data = abi.encodePacked(params.data, hex"00");
        assertNotEq(LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(moved), base, "data");
        moved = copy(params);
        unchecked {
            moved.beacon = address(uint160(params.beacon) + delta);
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
        RegistryBeaconProxyParams memory params = RegistryBeaconProxyParams({
            factory: address(factory),
            registry: registryAt,
            authority: LibRegistryBeaconProxyTest.AUTHORITY,
            beaconName: LibRegistryBeaconProxyTest.BEACON_NAME,
            beacon: beaconAt,
            data: data,
            salt: salt
        });

        bytes memory generated = LibRainDeployRegistryBeaconProxy.registryBeaconProxyRuntimeCode(
            vm, params, address(implementation), address(implementation).code
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
        assertEq(proxy, LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(params));
        assertEq(proxy.code, generated);
        assertEq(MockCloneableV2(proxy).version(), 2);
    }

    function testRegistryBeaconProxyRuntimeCodeCommitsToTheBeacon(uint160 delta) external {
        vm.assume(delta != 0);
        RegistryBeaconProxyParams memory params = RegistryBeaconProxyParams({
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
            vm, params, address(implementation), address(implementation).code
        );
        RegistryBeaconProxyParams memory moved = copy(params);
        unchecked {
            moved.beacon = address(uint160(params.beacon) + delta);
        }
        vm.assume(
            uint160(moved.beacon) > 0xffff && moved.beacon != params.registry && moved.beacon != address(implementation)
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
        RegistryBeaconProxyParams memory params = RegistryBeaconProxyParams({
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
                params.beacon,
                implementation
            )
        );
        this.externalRuntimeCode(params, implementation, "");
    }

    function testRegistryBeaconProxyRuntimeCodeOutlastsABindingAfterTheClock(uint32 ahead) external {
        vm.assume(ahead != 0);
        RegistryBeaconProxyParams memory params = liveParams(address(new MockCloneableV2()), TEST_DATA);
        bytes memory expected = LibRegistryBeaconProxyTest.runtimeOf(vm, params);
        uint256 moment = block.timestamp;
        vm.warp(moment + ahead);
        LibRegistryBeaconProxyTest.bind(vm, params.registry, params.beacon);
        vm.warp(moment);
        assertEq(LibRegistryBeaconProxyTest.runtimeOf(vm, params), expected);
        assertEq(block.timestamp, moment, "clock left moved");
    }

    function testRegistryBeaconProxyRuntimeCodeEtchesTheImplementationCodeItIsGiven() external {
        RegistryBeaconProxyParams memory params = unlivedParams();
        MockCloneableV2 deployed = new MockCloneableV2();
        bytes memory expected = LibRainDeployRegistryBeaconProxy.registryBeaconProxyRuntimeCode(
            vm, params, address(deployed), address(deployed).code
        );
        address implementation = address(0x1A9E);
        assertEq(
            LibRainDeployRegistryBeaconProxy.registryBeaconProxyRuntimeCode(
                vm, params, implementation, address(deployed).code
            ),
            expected
        );
        assertEq(implementation.code.length, 0, "implementation left behind");
    }

    function testRegistryBeaconProxyRuntimeCodeRefusesAProxyThatCannotDeploy() external {
        RegistryBeaconProxyParams memory params = unlivedParams();
        MockCloneableV2 implementation = new MockCloneableV2();
        vm.mockCall(
            params.beacon,
            abi.encodeWithSelector(UpgradeableBeacon.implementation.selector),
            abi.encode(address(0x1A9E))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRainDeployRegistryBeaconProxy.RegistryBeaconProxyLocalDeployFailed.selector,
                params.registry,
                params.authority,
                params.beaconName
            )
        );
        this.externalRuntimeCode(params, address(implementation), address(implementation).code);
    }

    function testCheckBeaconAcceptsTheBoundBeacon() external {
        RegistryBeaconProxyParams memory params = liveParams(address(new MockCloneableV2()), TEST_DATA);
        this.externalCheckBeacon(LibRainDeploy.ARBITRUM_ONE, params);
    }

    function testCheckBeaconRefusesAnotherBeacon(address declared) external {
        RegistryBeaconProxyParams memory params = liveParams(address(new MockCloneableV2()), TEST_DATA);
        vm.assume(declared != params.beacon);
        address bound = params.beacon;
        params.beacon = declared;
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRainDeployRegistryBeaconProxy.RegistryBeaconProxyBeaconMismatch.selector,
                LibRainDeploy.ARBITRUM_ONE,
                declared,
                bound
            )
        );
        this.externalCheckBeacon(LibRainDeploy.ARBITRUM_ONE, params);
    }

    function testRegistryBeaconProxyDeployStepDeploysTheDerivedAddress() external {
        RegistryBeaconProxyParams memory params = liveParams(address(new MockCloneableV2()), TEST_DATA);
        address deployed = this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(params));
        assertEq(deployed, LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(params));
        assertEq(deployed.code, LibRegistryBeaconProxyTest.runtimeOf(vm, params));
        assertEq(MockCloneableV2(deployed).sInitData(), TEST_DATA);
    }

    function testRegistryBeaconProxyDeployStepReturnsWhereTheFactoryDeployed() external {
        RegistryBeaconProxyParams memory params = liveParams(address(new MockCloneableV2()), TEST_DATA);
        address elsewhere =
            address(uint160(LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(params)) + 1);
        vm.mockCall(
            params.factory,
            abi.encodeWithSelector(ICloneableFactoryV7.registryBeaconProxy.selector),
            abi.encode(elsewhere)
        );
        address deployed = this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(params));
        assertEq(deployed, elsewhere);
    }

    function testRegistryBeaconProxyDeployStepStopsItsBroadcast() external {
        RegistryBeaconProxyParams memory params = liveParams(address(new MockCloneableV2()), TEST_DATA);
        this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(params));
        vm.startBroadcast(DEPLOYER);
        vm.stopBroadcast();
    }

    function testRegistryBeaconProxyDeployStepPredictionMismatchReverts() external {
        RegistryBeaconProxyParams memory params = liveParams(address(new MockCloneableV2()), TEST_DATA);
        address expected = LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(params);
        address predicted = address(uint160(expected) + 1);
        vm.mockCall(
            params.factory,
            abi.encodeWithSelector(ICloneableFactoryV7.predictRegistryBeaconProxyAddress.selector),
            abi.encode(predicted)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRainDeployRegistryBeaconProxy.RegistryBeaconProxyFactoryPredictionMismatch.selector,
                LibRainDeploy.ARBITRUM_ONE,
                params.factory,
                expected,
                predicted
            )
        );
        this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(params));
        assertEq(expected.code.length, 0);
    }

    function testRegistryBeaconProxyDeployStepRefusesABindingToAnotherBeacon() external {
        RegistryBeaconProxyParams memory params = liveParams(address(new MockCloneableV2()), TEST_DATA);
        address bound = address(new UpgradeableBeacon(address(new MockCloneableV2()), address(this)));
        vm.warp(block.timestamp + 1);
        LibRegistryBeaconProxyTest.bind(vm, params.registry, bound);
        address expected = LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(params);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRainDeployRegistryBeaconProxy.RegistryBeaconProxyBeaconMismatch.selector,
                LibRainDeploy.ARBITRUM_ONE,
                params.beacon,
                bound
            )
        );
        this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(params));
        assertEq(expected.code.length, 0);
    }

    function testRegistryBeaconProxyDeployStepRefusesABindingNotTypedAddress() external {
        RegistryBeaconProxyParams memory params = liveParams(address(new MockCloneableV2()), TEST_DATA);
        vm.warp(block.timestamp + 1);
        vm.prank(params.authority);
        IConfigRegistryV5(params.registry)
            .registerV5(params.authority, params.beaconName, "uint256", abi.encode(params.beacon), "");
        address expected = LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(params);
        vm.expectRevert(
            abi.encodeWithSelector(
                BeaconBindingTypeMismatch.selector,
                params.registry,
                params.authority,
                params.beaconName,
                keccak256("uint256")
            )
        );
        this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(params));
        assertEq(expected.code.length, 0);
    }

    function testRegistryBeaconProxyDeployStepRefusesADelegatedBeacon(address delegate) external {
        RegistryBeaconProxyParams memory params = liveParams(address(new MockCloneableV2()), TEST_DATA);
        vm.etch(params.beacon, abi.encodePacked(hex"ef0100", delegate));
        address expected = LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(params);
        vm.expectRevert(abi.encodeWithSelector(DelegatedBeacon.selector));
        this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(params));
        assertEq(expected.code.length, 0);
    }

    function testRegistryBeaconProxyDeployStepRefusesTheDeployKeySeated() external {
        RegistryBeaconProxyParams memory params =
            liveParams(address(new MockOriginOwnedCloneable()), abi.encode(address(0)));
        expectSeatsDeployKey(params);
        this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(params));
    }

    function testRegistryBeaconProxyDeployStepAcceptsAnotherOwner(address owner) external {
        vm.assume(owner != DEPLOYER && owner != address(0));
        RegistryBeaconProxyParams memory params = liveParams(address(new MockOriginOwnedCloneable()), abi.encode(owner));
        address deployed = this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(params));
        assertEq(MockOriginOwnedCloneable(deployed).owner(), owner);
    }

    function testRegistryBeaconProxyDeployStepAcceptsAnOwnerThatDoesNotAnswer(bool short) external {
        RegistryBeaconProxyParams memory params =
            liveParams(address(new MockMisansweringOwnerCloneable()), abi.encode(short));
        address deployed = this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(params));
        assertEq(deployed, LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(params));
        (bool answered, bytes memory owner) = deployed.staticcall(abi.encodeWithSignature("owner()"));
        assertEq(answered, short);
        assertEq(owner.length, short ? 0x1f : 0x20);
        assertEq(owner, short ? owner : abi.encode(DEPLOYER));
    }

    function testRegistryBeaconProxyDeployStepRefusesTheDeployKeyUnderDirtyHighBits(uint96 high) external {
        vm.assume(high != 0);
        RegistryBeaconProxyParams memory params = liveParams(address(new MockDirtyOwnerCloneable()), abi.encode(high));
        expectSeatsDeployKey(params);
        this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(params));
    }

    function testRegistryBeaconProxyDeployStepRefusesTheDeployKeyInALongerAnswer(bytes32 trailing) external {
        RegistryBeaconProxyParams memory params =
            liveParams(address(new MockLongOwnerCloneable()), abi.encode(trailing));
        expectSeatsDeployKey(params);
        this.externalDeployStep(LibRainDeploy.ARBITRUM_ONE, DEPLOYER, abi.encode(params));
    }
}
