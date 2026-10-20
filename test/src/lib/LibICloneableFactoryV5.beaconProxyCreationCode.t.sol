// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.16.1/src/Test.sol";

import {LibTestBeaconProxyBytes} from "test/lib/LibTestBeaconProxyBytes.sol";
import {ERC1967Utils} from "@openzeppelin-contracts-5.6.1/proxy/ERC1967/ERC1967Utils.sol";
import {IERC1967} from "@openzeppelin-contracts-5.6.1/interfaces/IERC1967.sol";
import {LibICloneableFactoryV5} from "src/lib/LibICloneableFactoryV5.sol";

/// @title LibICloneableFactoryV5BeaconProxyCreationCodeTest
/// @notice Pins `LibICloneableFactoryV5.beaconProxyCreationCode` to bytes
/// written out here opcode by opcode, with the ERC-1967 beacon slot and the
/// `BeaconUpgraded` topic taken from OpenZeppelin, so neither the library's
/// constants nor its arithmetic are checked against themselves. What those
/// bytes DO is checked against OpenZeppelin `BeaconProxy` in
/// `LibICloneableFactoryV5BeaconProxyOzEquivalenceTest`.
contract LibICloneableFactoryV5BeaconProxyCreationCodeTest is Test {
    /// The OpenZeppelin constants the expected bytes are built from are the
    /// ERC-1967 definitions.
    function testErc1967Constants() external pure {
        assertEq(ERC1967Utils.BEACON_SLOT, bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1));
        assertEq(IERC1967.BeaconUpgraded.selector, keccak256("BeaconUpgraded(address)"));
    }

    /// The creation code is the 187 bytes `LibTestBeaconProxyBytes` writes out.
    function testBeaconProxyCreationCodeBytes(address beacon) external pure {
        bytes memory creationCode = LibICloneableFactoryV5.beaconProxyCreationCode(beacon);
        assertEq(creationCode.length, 187);
        assertEq(creationCode, LibTestBeaconProxyBytes.expectedCreationCode(beacon));
        assertEq(LibTestBeaconProxyBytes.expectedRuntime(beacon).length, 0x56);
    }

    /// Deploying the creation code leaves exactly the runtime `LibTestBeaconProxyBytes`
    /// writes out, writes `beacon` to the ERC-1967 beacon slot and nothing else
    /// observable but one `BeaconUpgraded(beacon)` log, and calls nothing.
    function testBeaconProxyCreationCodeDeploys(address beacon, bytes32 salt) external {
        bytes memory creationCode = LibICloneableFactoryV5.beaconProxyCreationCode(beacon);
        vm.expectCall(beacon, "", 0);
        vm.recordLogs();
        vm.record();
        address proxy;
        assembly ("memory-safe") {
            proxy := create2(0, add(creationCode, 0x20), mload(creationCode), salt)
        }
        (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(proxy);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertTrue(proxy != address(0));
        assertEq(proxy.code, LibTestBeaconProxyBytes.expectedRuntime(beacon));
        assertEq(vm.load(proxy, ERC1967Utils.BEACON_SLOT), bytes32(uint256(uint160(beacon))));
        assertEq(writes.length, 1);
        assertEq(writes[0], ERC1967Utils.BEACON_SLOT);
        assertEq(reads.length, 1);
        assertEq(logs.length, 1);
        assertEq(logs[0].emitter, proxy);
        assertEq(logs[0].topics.length, 2);
        assertEq(logs[0].topics[0], IERC1967.BeaconUpgraded.selector);
        assertEq(logs[0].topics[1], bytes32(uint256(uint160(beacon))));
        assertEq(logs[0].data.length, 0);
    }
}
