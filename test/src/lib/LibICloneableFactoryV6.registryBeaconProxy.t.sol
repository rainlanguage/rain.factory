// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.17.0/src/Test.sol";
import {Create2} from "@openzeppelin-contracts-5.6.1/utils/Create2.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.6.1/proxy/beacon/UpgradeableBeacon.sol";
import {ERC1967Utils} from "@openzeppelin-contracts-5.6.1/proxy/ERC1967/ERC1967Utils.sol";

import {ICloneableFactoryV6} from "../../../src/interface/ICloneableFactoryV6.sol";
import {NonCanonicalBeaconBinding} from "../../../src/lib/LibICloneableFactoryV6.sol";
import {ZeroBeaconCodeSize} from "../../../src/lib/LibICloneableFactoryV5.sol";
import {TestCloneFactory} from "../../../src/test/TestCloneFactory.sol";
import {TestCloneable} from "../../../src/test/TestCloneable.sol";
import {RegistryBeaconProxy} from "../../../script/RegistryBeaconProxy.sol";
import {TestRegistryBeaconSource, TestNameNotRegistered} from "../../concrete/TestRegistryBeaconSource.sol";

/// @title LibICloneableFactoryV6RegistryBeaconProxyTest
/// `registryBeaconProxy` through `TestCloneFactory`: the beacon comes from the
/// registry binding, and the address does not depend on the beacon.
contract LibICloneableFactoryV6RegistryBeaconProxyTest is Test {
    address internal constant AUTHORITY = address(uint160(uint256(keccak256("authority"))));
    bytes32 internal constant BEACON_NAME = keccak256("st0x.vault-beacon.v1");

    TestCloneFactory internal immutable iFactory;
    TestRegistryBeaconSource internal immutable iRegistry;

    constructor() {
        iFactory = new TestCloneFactory();
        iRegistry = new TestRegistryBeaconSource();
    }

    function newBeacon() internal returns (address) {
        return address(new UpgradeableBeacon(address(new TestCloneable()), address(this)));
    }

    /// The address from first principles: CREATE2 over the proxy's creation
    /// code with its arguments and the domain-separated salt.
    function expected(bytes memory data, bytes32 salt) internal view returns (address) {
        bytes32 derivedSalt =
            keccak256(abi.encode(keccak256("rain.factory.registrybeaconproxy"), salt, keccak256(data)));
        bytes memory creationCode = bytes.concat(
            type(RegistryBeaconProxy).creationCode, abi.encode(address(iRegistry), AUTHORITY, BEACON_NAME)
        );
        return Create2.computeAddress(derivedSalt, keccak256(creationCode), address(iFactory));
    }

    /// The proxy lands at the predicted address, serves the bound beacon's
    /// implementation and is initialized with `data`.
    function testRegistryBeaconProxyDeploys(bytes memory data, bytes32 salt) external {
        address beacon = newBeacon();
        iRegistry.bind(AUTHORITY, BEACON_NAME, abi.encode(beacon));

        address predicted =
            iFactory.predictRegistryBeaconProxyAddress(address(iRegistry), AUTHORITY, BEACON_NAME, data, salt);
        assertEq(predicted, expected(data, salt));

        vm.expectEmit(address(iFactory));
        emit ICloneableFactoryV6.NewRegistryBeaconProxy(
            address(this), address(iRegistry), AUTHORITY, BEACON_NAME, beacon, predicted, salt, data
        );
        address proxy = iFactory.registryBeaconProxy(address(iRegistry), AUTHORITY, BEACON_NAME, data, salt);

        assertEq(proxy, predicted);
        assertEq(address(uint160(uint256(vm.load(proxy, ERC1967Utils.BEACON_SLOT)))), beacon);
        assertTrue(TestCloneable(proxy).sInitialized());
        assertEq(TestCloneable(proxy).sData(), data);
    }

    /// Two chains binding different beacons get the proxy at the same address,
    /// each serving its own beacon.
    function testSameAddressWhateverTheBeacon(bytes memory data, bytes32 salt) external {
        uint256 start = vm.snapshotState();
        address beaconA = newBeacon();
        iRegistry.bind(AUTHORITY, BEACON_NAME, abi.encode(beaconA));
        address proxyA = iFactory.registryBeaconProxy(address(iRegistry), AUTHORITY, BEACON_NAME, data, salt);
        assertEq(address(uint160(uint256(vm.load(proxyA, ERC1967Utils.BEACON_SLOT)))), beaconA);

        vm.revertToState(start);
        newBeacon();
        address beaconB = newBeacon();
        assertTrue(beaconA != beaconB);
        iRegistry.bind(AUTHORITY, BEACON_NAME, abi.encode(beaconB));
        address proxyB = iFactory.registryBeaconProxy(address(iRegistry), AUTHORITY, BEACON_NAME, data, salt);

        assertEq(proxyA, proxyB);
        assertEq(address(uint160(uint256(vm.load(proxyB, ERC1967Utils.BEACON_SLOT)))), beaconB);
    }

    /// The address commits to the registry, the authority and the name.
    function testAddressCommitsToTheBinding(bytes memory data, bytes32 salt, address otherAuthority, bytes32 otherName)
        external
        view
    {
        vm.assume(otherAuthority != AUTHORITY && otherName != BEACON_NAME);
        address base =
            iFactory.predictRegistryBeaconProxyAddress(address(iRegistry), AUTHORITY, BEACON_NAME, data, salt);
        assertTrue(base != iFactory.predictRegistryBeaconProxyAddress(address(1), AUTHORITY, BEACON_NAME, data, salt));
        assertTrue(
            base
                != iFactory.predictRegistryBeaconProxyAddress(
                    address(iRegistry), otherAuthority, BEACON_NAME, data, salt
                )
        );
        assertTrue(
            base != iFactory.predictRegistryBeaconProxyAddress(address(iRegistry), AUTHORITY, otherName, data, salt)
        );
    }

    /// An unbound name refuses with the registry's own error.
    function testUnboundName(bytes memory data, bytes32 salt) external {
        vm.expectRevert(abi.encodeWithSelector(TestNameNotRegistered.selector, AUTHORITY, BEACON_NAME));
        iFactory.registryBeaconProxy(address(iRegistry), AUTHORITY, BEACON_NAME, data, salt);
    }

    /// A binding that is not one clean `abi.encode(address)` word is refused.
    function testNonCanonicalBinding(bytes memory value, bytes memory data, bytes32 salt) external {
        vm.assume(value.length != 0);
        vm.assume(value.length != 0x20 || uint256(bytes32(value)) >> 160 != 0);
        iRegistry.bind(AUTHORITY, BEACON_NAME, value);
        vm.expectRevert(
            abi.encodeWithSelector(NonCanonicalBeaconBinding.selector, address(iRegistry), AUTHORITY, BEACON_NAME)
        );
        iFactory.registryBeaconProxy(address(iRegistry), AUTHORITY, BEACON_NAME, data, salt);
    }

    /// A bound address with no code is refused as a beacon.
    function testBeaconWithoutCode(address beacon, bytes memory data, bytes32 salt) external {
        vm.assume(beacon.code.length == 0);
        iRegistry.bind(AUTHORITY, BEACON_NAME, abi.encode(beacon));
        vm.expectRevert(abi.encodeWithSelector(ZeroBeaconCodeSize.selector));
        iFactory.registryBeaconProxy(address(iRegistry), AUTHORITY, BEACON_NAME, data, salt);
    }
}
