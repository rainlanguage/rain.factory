// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {StdConstants} from "forge-std-1.17.0/src/StdConstants.sol";
import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "../../src/interface/ICloneableV2.sol";

/// @title MockSnapshotDeletingCloneable
/// @notice A clone implementation whose initialization deletes every state snapshot.
contract MockSnapshotDeletingCloneable is ICloneableV2 {
    /// @inheritdoc ICloneableV2
    function initialize(bytes calldata) external returns (bytes32) {
        StdConstants.VM.deleteStateSnapshots();
        return ICLONEABLE_V2_SUCCESS;
    }
}
