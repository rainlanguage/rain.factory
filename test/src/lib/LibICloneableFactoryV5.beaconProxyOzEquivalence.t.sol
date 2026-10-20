// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {BeaconProxy} from "@openzeppelin-contracts-5.6.1/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.6.1/proxy/beacon/UpgradeableBeacon.sol";
import {ERC1967Utils} from "@openzeppelin-contracts-5.6.1/proxy/ERC1967/ERC1967Utils.sol";
import {LibICloneableFactoryV5} from "src/lib/LibICloneableFactoryV5.sol";
import {TestBeaconProxyEcho} from "test/concrete/TestBeaconProxyEcho.sol";
import {TestBeaconRawAnswer} from "test/concrete/TestBeaconRawAnswer.sol";
import {TestBeaconStrictCalldata} from "test/concrete/TestBeaconStrictCalldata.sol";

/// @title LibICloneableFactoryV5BeaconProxyOzEquivalenceTest
/// @notice The beacon proxy `LibICloneableFactoryV5.beaconProxyCreationCode`
/// builds behaves as OpenZeppelin `BeaconProxy` constructed with empty data:
/// the same beacon slot, the same delegation context, the same return and
/// revert data, and the same answer to every shape of beacon reply. OZ is an
/// independent implementation of the behaviour `ICloneableFactoryV5` specifies,
/// so each test runs both proxies and compares.
contract LibICloneableFactoryV5BeaconProxyOzEquivalenceTest is Test {
    /// Deploys ours by `CREATE` of the library's creation code.
    function deployOurs(address beacon) internal returns (address) {
        bytes memory creationCode = LibICloneableFactoryV5.beaconProxyCreationCode(beacon);
        address proxy;
        assembly ("memory-safe") {
            proxy := create(0, add(creationCode, 0x20), mload(creationCode))
        }
        assertTrue(proxy != address(0));
        return proxy;
    }

    /// Calls `proxy` with `value` and `data`.
    function callProxy(address proxy, uint256 value, bytes memory data) internal returns (bool, bytes memory) {
        vm.deal(address(this), value);
        // slither-disable-next-line arbitrary-send-eth
        return proxy.call{value: value}(data);
    }

    /// What `TestBeaconProxyEcho` answers `data` with when run as `proxy`.
    function echoAnswer(address proxy, uint256 value, bytes memory data) internal view returns (bool, bytes memory) {
        bool success = data.length == 0 || data[0] != 0x00;
        if (!success) {
            return (success, data);
        }
        if (data.length > 32 && data[0] == 0x01) {
            return (success, "");
        }
        return (success, abi.encode(proxy, address(this), value, data));
    }

    /// Calls both proxies with `value` and `data` and checks each answers as
    /// `TestBeaconProxyEcho` run as itself, and both hold the same balance.
    function checkSameEcho(address ours, address oz, uint256 value, bytes memory data) internal {
        (bool oursSuccess, bytes memory oursData) = callProxy(ours, value, data);
        (bool ozSuccess, bytes memory ozData) = callProxy(oz, value, data);
        (bool expectedOurs, bytes memory expectedOursData) = echoAnswer(ours, value, data);
        assertEq(oursSuccess, ozSuccess);
        assertEq(oursSuccess, expectedOurs);
        assertEq(oursData, expectedOursData);
        (, bytes memory expectedOzData) = echoAnswer(oz, value, data);
        assertEq(ozData, expectedOzData);
        assertEq(ours.balance, oz.balance);
    }

    /// Both proxies hold `beacon` in the ERC-1967 beacon slot.
    function testBeaconSlotMatchesOz() external {
        UpgradeableBeacon beacon = new UpgradeableBeacon(address(new TestBeaconProxyEcho()), address(this));
        address ours = deployOurs(address(beacon));
        address oz = address(new BeaconProxy(address(beacon), ""));
        assertEq(vm.load(ours, ERC1967Utils.BEACON_SLOT), vm.load(oz, ERC1967Utils.BEACON_SLOT));
        assertEq(vm.load(ours, ERC1967Utils.BEACON_SLOT), bytes32(uint256(uint160(address(beacon)))));
    }

    /// Any call, with any value, delegates to the beacon's implementation in
    /// the proxy's own context with the caller and value preserved, and
    /// returns or reverts with the implementation's data, as on OZ.
    function testCallMatchesOz(uint256 value, bytes memory data) external {
        value = bound(value, 0, type(uint128).max);
        UpgradeableBeacon beacon = new UpgradeableBeacon(address(new TestBeaconProxyEcho()), address(this));
        address ours = deployOurs(address(beacon));
        address oz = address(new BeaconProxy(address(beacon), ""));

        checkSameEcho(ours, oz, value, data);
    }

    /// Both proxies call the beacon with exactly the 4-byte `implementation()`
    /// selector: a beacon that answers only that calldata serves both.
    function testBeaconCalldataMatchesOz(uint256 value, bytes memory data) external {
        value = bound(value, 0, type(uint128).max);
        TestBeaconStrictCalldata beacon = new TestBeaconStrictCalldata(address(new TestBeaconProxyEcho()));
        address ours = deployOurs(address(beacon));
        address oz = address(new BeaconProxy(address(beacon), ""));

        checkSameEcho(ours, oz, value, data);
    }

    /// Retargeting the beacon retargets both proxies.
    function testUpgradeMatchesOz(bytes memory data) external {
        UpgradeableBeacon beacon = new UpgradeableBeacon(address(new TestBeaconRawAnswer()), address(this));
        address ours = deployOurs(address(beacon));
        address oz = address(new BeaconProxy(address(beacon), ""));

        beacon.upgradeTo(address(new TestBeaconProxyEcho()));

        checkSameEcho(ours, oz, 0, data);
    }

    /// An implementation overwriting the beacon slot does not move either
    /// proxy off the beacon fixed at construction.
    function testBeaconSlotOverwriteMatchesOz(address other, bytes memory data) external {
        UpgradeableBeacon beacon = new UpgradeableBeacon(address(new TestBeaconProxyEcho()), address(this));
        address ours = deployOurs(address(beacon));
        address oz = address(new BeaconProxy(address(beacon), ""));
        bytes memory overwrite = abi.encodePacked(hex"01", bytes32(uint256(uint160(other))));

        (bool oursSuccess,) = callProxy(ours, 0, overwrite);
        (bool ozSuccess,) = callProxy(oz, 0, overwrite);
        assertTrue(oursSuccess);
        assertTrue(ozSuccess);
        assertEq(vm.load(ours, ERC1967Utils.BEACON_SLOT), bytes32(uint256(uint160(other))));
        assertEq(vm.load(oz, ERC1967Utils.BEACON_SLOT), bytes32(uint256(uint160(other))));

        checkSameEcho(ours, oz, 0, data);
    }

    /// Whatever the beacon answers `implementation()` with — a revert with any
    /// data, any return of any length, clean or dirty — both proxies answer
    /// the call identically. An answer naming a contract is left to the
    /// echo tests, since what that contract does may depend on the proxy's
    /// own address.
    function testBeaconAnswerMatchesOz(bool reverts, bytes memory answer, bytes memory data) external {
        TestBeaconRawAnswer beacon = new TestBeaconRawAnswer();
        beacon.set(false, abi.encode(address(beacon)));
        address ours = deployOurs(address(beacon));
        address oz = address(new BeaconProxy(address(beacon), ""));
        if (!reverts && answer.length >= 32) {
            uint256 word = abi.decode(answer, (uint256));
            // casting to 'uint160' is safe because the left operand short-circuits any word with high bits set
            // forge-lint: disable-next-line(unsafe-typecast)
            vm.assume(word >> 160 != 0 || address(uint160(word)).code.length == 0);
        }
        beacon.set(reverts, answer);

        (bool oursSuccess, bytes memory oursData) = callProxy(ours, 0, data);
        (bool ozSuccess, bytes memory ozData) = callProxy(oz, 0, data);
        assertEq(oursSuccess, ozSuccess);
        assertEq(oursData, ozData);
    }

    /// The boundary beacon answers, each run through both proxies: every
    /// return length from 0 to 64 around a clean address word, a clean word
    /// with each of the 96 high bits set alone, and reverts with no data, a
    /// selector and a word.
    function testBeaconAnswerBoundariesMatchOz(bytes memory data) external {
        TestBeaconRawAnswer beacon = new TestBeaconRawAnswer();
        beacon.set(false, abi.encode(address(beacon)));
        address ours = deployOurs(address(beacon));
        address oz = address(new BeaconProxy(address(beacon), ""));
        address echo = address(new TestBeaconProxyEcho());

        bytes memory word = abi.encode(echo, bytes32(type(uint256).max));
        for (uint256 length = 0; length <= 64; ++length) {
            bytes memory answer = new bytes(length);
            for (uint256 i = 0; i < length; ++i) {
                answer[i] = word[i];
            }
            checkBeaconAnswer(beacon, ours, oz, false, answer, data);
        }
        for (uint256 bit = 160; bit < 256; ++bit) {
            checkBeaconAnswer(beacon, ours, oz, false, abi.encode(uint256(uint160(echo)) | (uint256(1) << bit)), data);
        }
        checkBeaconAnswer(beacon, ours, oz, true, "", data);
        checkBeaconAnswer(beacon, ours, oz, true, hex"deadbeef", data);
        checkBeaconAnswer(beacon, ours, oz, true, abi.encode(echo), data);
    }

    /// Sets `beacon`'s answer and checks both proxies agree on the call. An
    /// answer that resolves to the echo implementation returns each proxy's
    /// own address, so that case is compared against `echoAnswer`.
    function checkBeaconAnswer(
        TestBeaconRawAnswer beacon,
        address ours,
        address oz,
        bool reverts,
        bytes memory answer,
        bytes memory data
    ) internal {
        beacon.set(reverts, answer);
        (bool oursSuccess, bytes memory oursData) = callProxy(ours, 0, data);
        (bool ozSuccess, bytes memory ozData) = callProxy(oz, 0, data);
        assertEq(oursSuccess, ozSuccess, "success");
        if (oursSuccess && keccak256(oursData) != keccak256(ozData)) {
            (, bytes memory expectedOursData) = echoAnswer(ours, 0, data);
            (, bytes memory expectedOzData) = echoAnswer(oz, 0, data);
            assertEq(oursData, expectedOursData, "ours echo");
            assertEq(ozData, expectedOzData, "oz echo");
        } else {
            assertEq(oursData, ozData, "data");
        }
    }

    /// A beacon whose code is gone reverts both proxies with no data.
    function testCodelessBeaconMatchesOz(bytes memory data) external {
        UpgradeableBeacon beacon = new UpgradeableBeacon(address(new TestBeaconProxyEcho()), address(this));
        address ours = deployOurs(address(beacon));
        address oz = address(new BeaconProxy(address(beacon), ""));
        vm.etch(address(beacon), "");

        (bool oursSuccess, bytes memory oursData) = callProxy(ours, 0, data);
        (bool ozSuccess, bytes memory ozData) = callProxy(oz, 0, data);
        assertFalse(oursSuccess);
        assertFalse(ozSuccess);
        assertEq(oursData, "");
        assertEq(ozData, "");
    }

    /// A beacon naming a codeless implementation makes every call succeed with
    /// no data on both proxies.
    function testCodelessImplementationMatchesOz(address implementation, bytes memory data) external {
        vm.assume(implementation.code.length == 0);
        assumeNotPrecompile(implementation);
        TestBeaconRawAnswer beacon = new TestBeaconRawAnswer();
        beacon.set(false, abi.encode(address(beacon)));
        address ours = deployOurs(address(beacon));
        address oz = address(new BeaconProxy(address(beacon), ""));
        beacon.set(false, abi.encode(implementation));

        (bool oursSuccess, bytes memory oursData) = callProxy(ours, 0, data);
        (bool ozSuccess, bytes memory ozData) = callProxy(oz, 0, data);
        assertTrue(oursSuccess);
        assertTrue(ozSuccess);
        assertEq(oursData, "");
        assertEq(ozData, "");
    }
}
