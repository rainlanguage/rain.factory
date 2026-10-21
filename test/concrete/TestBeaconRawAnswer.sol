// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

/// @title TestBeaconRawAnswer
/// @notice A beacon whose `implementation()` reverts with, or returns, the raw
/// bytes last passed to `set`, so a test can drive a beacon proxy through every
/// shape of beacon answer, well formed or not.
contract TestBeaconRawAnswer {
    /// Whether `implementation()` reverts.
    bool internal sReverts;
    /// What `implementation()` reverts with or returns.
    bytes internal sAnswer;

    /// Sets the next `implementation()` answer.
    /// @param reverts Whether `implementation()` reverts.
    /// @param answer The raw bytes it reverts with or returns.
    function set(bool reverts, bytes memory answer) external {
        sReverts = reverts;
        sAnswer = answer;
    }

    /// Reverts with, or returns, the raw bytes last passed to `set`.
    function implementation() external view {
        bool reverts = sReverts;
        bytes memory answer = sAnswer;
        assembly ("memory-safe") {
            if reverts { revert(add(answer, 0x20), mload(answer)) }
            return(add(answer, 0x20), mload(answer))
        }
    }
}
