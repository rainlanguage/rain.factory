// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.6.1/proxy/beacon/UpgradeableBeacon.sol";
import {LibICloneableFactoryV4} from "../../../src/lib/LibICloneableFactoryV4.sol";
import {LibICloneableFactoryV5} from "../../../src/lib/LibICloneableFactoryV5.sol";
import {TestCloneableCallRecorder} from "../../concrete/TestCloneableCallRecorder.sol";

contract LibICloneableFactoryV4DeployAndInitializeTest is Test {
    /// Every creation code this repo passes to `deployAndInitialize`, each
    /// delegating to `target`. A new derivation adds its code here.
    function shippedCreationCodes(address target) internal returns (bytes[] memory) {
        bytes[] memory codes = new bytes[](2);
        codes[0] = LibICloneableFactoryV4.cloneCreationCode(target);
        codes[1] = LibICloneableFactoryV5.beaconProxyCreationCode(address(new UpgradeableBeacon(target, address(this))));
        return codes;
    }

    /// `deployAndInitialize`'s precondition: no shipped creation code calls
    /// its delegation target while constructing.
    function testShippedCreationCodesDoNotCallTarget(bytes32 salt) external {
        address target = address(new TestCloneableCallRecorder());
        bytes[] memory codes = shippedCreationCodes(target);
        for (uint256 i = 0; i < codes.length; ++i) {
            bytes memory code = codes[i];
            address deployed;
            assembly ("memory-safe") {
                deployed := create2(0, add(code, 0x20), mload(code), salt)
            }
            assertTrue(deployed != address(0));
            assertEq(TestCloneableCallRecorder(deployed).selectors().length, 0);
            assertEq(TestCloneableCallRecorder(target).selectors().length, 0);
        }
    }
}
