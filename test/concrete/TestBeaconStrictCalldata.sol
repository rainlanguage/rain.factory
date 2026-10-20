// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

/// @title TestBeaconStrictCalldata
/// @notice A beacon that answers `implementation()` only when the calldata is
/// exactly its 4-byte selector, and otherwise reverts with the calldata it
/// received, so a test observes the exact bytes a proxy sends its beacon.
contract TestBeaconStrictCalldata {
    /// The implementation `implementation()` returns.
    address internal immutable I_IMPLEMENTATION;

    constructor(address implementation) {
        I_IMPLEMENTATION = implementation;
    }

    fallback(bytes calldata data) external returns (bytes memory) {
        if (keccak256(data) != keccak256(abi.encodeWithSignature("implementation()"))) {
            assembly ("memory-safe") {
                calldatacopy(0, 0, calldatasize())
                revert(0, calldatasize())
            }
        }
        return abi.encode(I_IMPLEMENTATION);
    }
}
