// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {LibRainDeployCloneMechanism} from "../../../src/lib/LibRainDeployCloneMechanism.sol";

/// @title LibRainDeployCloneMechanismInPlayAddressesTest
/// @notice `LibRainDeployCloneMechanism.inPlayAddresses` keeps exactly the in-play entries, in order.
contract LibRainDeployCloneMechanismInPlayAddressesTest is Test {
    function testInPlayAddressesKeepsOnlyTheInPlayEntriesInOrder() external pure {
        address[] memory addresses = new address[](4);
        addresses[0] = address(0xA);
        addresses[1] = address(0xB);
        addresses[2] = address(0xC);
        addresses[3] = address(0xD);
        bool[] memory inPlay = new bool[](4);
        inPlay[1] = true;
        inPlay[3] = true;

        address[] memory expected = new address[](2);
        expected[0] = address(0xB);
        expected[1] = address(0xD);
        assertEq(LibRainDeployCloneMechanism.inPlayAddresses(addresses, inPlay), expected);
    }

    function testInPlayAddressesKeepsARepeatedAddressOncePerInPlayEntry() external pure {
        address[] memory addresses = new address[](3);
        addresses[0] = address(0xA);
        addresses[1] = address(0xA);
        addresses[2] = address(0xA);
        bool[] memory inPlay = new bool[](3);
        inPlay[0] = true;
        inPlay[2] = true;

        address[] memory expected = new address[](2);
        expected[0] = address(0xA);
        expected[1] = address(0xA);
        assertEq(LibRainDeployCloneMechanism.inPlayAddresses(addresses, inPlay), expected);
    }

    function testInPlayAddressesOfNothingInPlayIsEmpty() external pure {
        address[] memory addresses = new address[](2);
        addresses[0] = address(0xA);
        addresses[1] = address(0xB);
        assertEq(LibRainDeployCloneMechanism.inPlayAddresses(addresses, new bool[](2)).length, 0);
        assertEq(LibRainDeployCloneMechanism.inPlayAddresses(new address[](0), new bool[](0)).length, 0);
    }

    /// Bit `i` of `mask` puts entry `i` in play.
    function testInPlayAddressesIsTheInPlaySubsequence(address[] memory addresses, uint256 mask) external pure {
        vm.assume(addresses.length <= 256);
        bool[] memory inPlay = new bool[](addresses.length);
        uint256 count = 0;
        for (uint256 i = 0; i < addresses.length; i++) {
            inPlay[i] = (mask >> i) & 1 == 1;
            if (inPlay[i]) {
                count++;
            }
        }

        address[] memory kept = LibRainDeployCloneMechanism.inPlayAddresses(addresses, inPlay);
        assertEq(kept.length, count);
        uint256 k = 0;
        for (uint256 i = 0; i < addresses.length; i++) {
            if (inPlay[i]) {
                assertEq(kept[k], addresses[i]);
                k++;
            }
        }
    }
}
