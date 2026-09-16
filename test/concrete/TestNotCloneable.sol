// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

/// @title TestNotCloneable
/// @notice A contract with code that is not an `ICloneableV2` at all: no
/// `initialize(bytes)` and no fallback, so a call to `initialize` on a clone of
/// it has no function to dispatch to and reverts with no data. This is the
/// plainest shape of "the implementation doesn't support `ICloneableV2`".
contract TestNotCloneable {
    /// The one function this contract has, so it is a plausible contract and
    /// not an empty one. Unrelated to `ICloneableV2`.
    function unrelated() external pure returns (uint256) {
        return 1;
    }
}
