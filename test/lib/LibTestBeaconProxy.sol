// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Vm} from "forge-std-1.17.0/src/Vm.sol";
import {IERC1967} from "@openzeppelin-contracts-5.7.0/interfaces/IERC1967.sol";

/// @title LibTestBeaconProxy
/// @notice Shared assertions on a deployed OZ `BeaconProxy`.
library LibTestBeaconProxy {
    /// Asserts `log` is `proxy`'s constructor `BeaconUpgraded(beacon)`.
    /// @param vm The cheatcode instance.
    /// @param log The recorded log.
    /// @param proxy The proxy expected to emit it.
    /// @param beacon The beacon expected in its topic.
    function checkBeaconUpgradedLog(Vm vm, Vm.Log memory log, address proxy, address beacon) internal pure {
        vm.assertEq(log.emitter, proxy);
        vm.assertEq(log.topics.length, 2);
        vm.assertEq(log.topics[0], IERC1967.BeaconUpgraded.selector);
        vm.assertEq(log.topics[1], bytes32(uint256(uint160(beacon))));
        vm.assertEq(log.data.length, 0);
    }
}
