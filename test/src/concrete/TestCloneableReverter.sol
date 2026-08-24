// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2} from "src/interface/ICloneableV2.sol";

/// @title TestCloneableReverter
/// @notice An `ICloneableV2` whose `initialize` REVERTS with its own typed
/// error carrying its own data. `TestCloneableFailure` returns a non-success
/// hash instead, so on its own the suite never distinguishes "initialize
/// failed the sentinel check" from "initialize reverted" — and never proves
/// that the implementation's own revert reaches the caller instead of being
/// flattened into the library's `InitializationFailed`.
contract TestCloneableReverter is ICloneableV2 {
    /// Thrown unconditionally by `initialize`.
    /// @param data The data the clone was initialized with, echoed back so a
    /// test can prove the revert reason survives verbatim.
    error InitializeReverted(bytes data);

    /// @inheritdoc ICloneableV2
    function initialize(bytes memory data) external pure returns (bytes32) {
        revert InitializeReverted(data);
    }
}
