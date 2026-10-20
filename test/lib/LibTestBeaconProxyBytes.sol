// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC1967Utils} from "@openzeppelin-contracts-5.6.1/proxy/ERC1967/ERC1967Utils.sol";
import {IERC1967} from "@openzeppelin-contracts-5.6.1/interfaces/IERC1967.sol";

/// @title LibTestBeaconProxyBytes
/// @notice The minimal ERC-1967 beacon proxy `ICloneableFactoryV5` deploys,
/// written out opcode by opcode, with the ERC-1967 beacon slot and the
/// `BeaconUpgraded` topic taken from OpenZeppelin, so the tests never check the
/// library's constants against themselves.
library LibTestBeaconProxyBytes {
    /// The runtime: `STATICCALL beacon.implementation()`, bubble its revert,
    /// revert empty on a short or non-address answer, else `DELEGATECALL` it
    /// and return or revert its return data.
    function expectedRuntime(address beacon) internal pure returns (bytes memory) {
        return abi.encodePacked(
            // 00 PUSH4 0x5c60da1b PUSH0 MSTORE: selector at memory 0x1c.
            hex"635c60da1b5f52",
            // 07 PUSH1 0x20 PUSH0 PUSH1 0x04 PUSH1 0x1c: ret 0..0x20, args 0x1c..0x20.
            hex"60205f6004601c",
            // 0e PUSH20 beacon.
            hex"73",
            beacon,
            // 23 GAS STATICCALL.
            hex"5afa",
            // 25 DUP1 ISZERO PUSH1 0x43 JUMPI.
            hex"8015604357",
            // 2a PUSH0 MLOAD DUP1 PUSH1 0xa0 SHR.
            hex"5f518060a01c",
            // 30 PUSH1 0x20 RETURNDATASIZE LT OR.
            hex"60203d1017",
            // 35 PUSH1 0x52 JUMPI.
            hex"605257",
            // 38 CALLDATASIZE PUSH0 PUSH0 CALLDATACOPY.
            hex"365f5f37",
            // 3c PUSH0 PUSH0 CALLDATASIZE PUSH0 DUP5 GAS DELEGATECALL.
            hex"5f5f365f845af4",
            // 43 JUMPDEST RETURNDATASIZE PUSH0 PUSH0 RETURNDATACOPY.
            hex"5b3d5f5f3e",
            // 48 PUSH1 0x4e JUMPI RETURNDATASIZE PUSH0 REVERT.
            hex"604e573d5ffd",
            // 4e JUMPDEST RETURNDATASIZE PUSH0 RETURN.
            hex"5b3d5ff3",
            // 52 JUMPDEST PUSH0 PUSH0 REVERT.
            hex"5b5f5ffd"
        );
    }

    /// The constructor: write `beacon` to the ERC-1967 beacon slot, emit
    /// `BeaconUpgraded(beacon)`, return the runtime.
    function expectedCreationCode(address beacon) internal pure returns (bytes memory) {
        return abi.encodePacked(
            // 00 PUSH20 beacon DUP1.
            hex"73",
            beacon,
            hex"80",
            // 16 PUSH32 BEACON_SLOT SSTORE.
            hex"7f",
            ERC1967Utils.BEACON_SLOT,
            hex"55",
            // 38 PUSH32 BeaconUpgraded PUSH0 PUSH0 LOG2.
            hex"7f",
            IERC1967.BeaconUpgraded.selector,
            hex"5f5fa2",
            // 5c PUSH1 0x56 DUP1 PUSH1 0x65 PUSH0 CODECOPY PUSH0 RETURN.
            hex"60568060655f395ff3",
            // 65 runtime.
            expectedRuntime(beacon)
        );
    }
}
