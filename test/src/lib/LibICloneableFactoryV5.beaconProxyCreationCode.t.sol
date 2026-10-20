// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.17.0/src/Test.sol";

import {BeaconProxy} from "@openzeppelin-contracts-5.6.1/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.6.1/proxy/beacon/UpgradeableBeacon.sol";
import {ERC1967Utils} from "@openzeppelin-contracts-5.6.1/proxy/ERC1967/ERC1967Utils.sol";
import {IERC1967} from "@openzeppelin-contracts-5.6.1/interfaces/IERC1967.sol";
import {BEACON_PROXY_CREATION_CODE} from "../../../src/generated/BeaconProxy.sol";
import {ICLONEABLE_FACTORY_V5_BEACON_PROXY_CREATION_CODE_HASH} from "../../../src/interface/ICloneableFactoryV5.sol";
import {LibICloneableFactoryV5} from "../../../src/lib/LibICloneableFactoryV5.sol";
import {TestCloneable} from "../../concrete/TestCloneable.sol";

/// @title LibICloneableFactoryV5BeaconProxyCreationCodeTest
/// @notice Pins `BEACON_PROXY_CREATION_CODE` and
/// `LibICloneableFactoryV5.beaconProxyCreationCode` to OpenZeppelin
/// `BeaconProxy` as compiled here.
contract LibICloneableFactoryV5BeaconProxyCreationCodeTest is Test {
    /// The pinned constant is `BeaconProxy`'s creation code.
    function testBeaconProxyCreationCodePin() external pure {
        assertEq(BEACON_PROXY_CREATION_CODE, type(BeaconProxy).creationCode);
    }

    /// The pinned constant hashes to
    /// `ICLONEABLE_FACTORY_V5_BEACON_PROXY_CREATION_CODE_HASH`.
    function testBeaconProxyCreationCodeHash() external pure {
        assertEq(keccak256(BEACON_PROXY_CREATION_CODE), ICLONEABLE_FACTORY_V5_BEACON_PROXY_CREATION_CODE_HASH);
    }

    /// The creation code is `BeaconProxy`'s with `(beacon, "")` as constructor
    /// arguments.
    function testBeaconProxyCreationCode(address beacon) external pure {
        assertEq(
            LibICloneableFactoryV5.beaconProxyCreationCode(beacon),
            abi.encodePacked(type(BeaconProxy).creationCode, abi.encode(beacon, bytes("")))
        );
    }

    /// Deploying the creation code leaves `new BeaconProxy(beacon, "")`'s
    /// runtime, writes `beacon` to the ERC-1967 beacon slot, emits one
    /// `BeaconUpgraded(beacon)` and calls nothing on the implementation.
    function testBeaconProxyCreationCodeDeploys(bytes32 salt) external {
        UpgradeableBeacon beacon = new UpgradeableBeacon(address(new TestCloneable()), address(this));
        bytes memory creationCode = LibICloneableFactoryV5.beaconProxyCreationCode(address(beacon));
        vm.expectCall(beacon.implementation(), "", 0);
        vm.recordLogs();
        address proxy;
        assembly ("memory-safe") {
            proxy := create2(0, add(creationCode, 0x20), mload(creationCode), salt)
        }
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertTrue(proxy != address(0));
        assertEq(proxy.code, address(new BeaconProxy(address(beacon), "")).code);
        assertEq(vm.load(proxy, ERC1967Utils.BEACON_SLOT), bytes32(uint256(uint160(address(beacon)))));
        assertEq(logs.length, 1);
        assertEq(logs[0].emitter, proxy);
        assertEq(logs[0].topics.length, 2);
        assertEq(logs[0].topics[0], IERC1967.BeaconUpgraded.selector);
        assertEq(logs[0].topics[1], bytes32(uint256(uint160(address(beacon)))));
        assertEq(logs[0].data.length, 0);
    }
}
