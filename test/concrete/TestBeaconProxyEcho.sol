// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

/// @title TestBeaconProxyEcho
/// @notice A beacon proxy implementation that makes its execution context
/// observable, so two proxies can be compared call for call. Calldata whose
/// first byte is `0x00` reverts with the calldata; first byte `0x01` writes the
/// next 32 bytes to the ERC-1967 beacon slot and returns nothing; anything else,
/// including empty calldata, returns `abi.encode(address(this), msg.sender,
/// msg.value, msg.data)`.
contract TestBeaconProxyEcho {
    /// `bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1)`.
    bytes32 internal constant BEACON_SLOT = bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1);

    fallback(bytes calldata data) external payable returns (bytes memory) {
        if (data.length > 0 && data[0] == 0x00) {
            assembly ("memory-safe") {
                calldatacopy(0, 0, calldatasize())
                revert(0, calldatasize())
            }
        }
        if (data.length > 32 && data[0] == 0x01) {
            bytes32 slot = BEACON_SLOT;
            bytes32 value = bytes32(data[1:33]);
            assembly ("memory-safe") {
                sstore(slot, value)
            }
            return "";
        }
        return abi.encode(address(this), msg.sender, msg.value, data);
    }
}
