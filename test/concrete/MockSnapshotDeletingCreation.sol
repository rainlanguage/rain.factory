// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {StdConstants} from "forge-std-1.17.0/src/StdConstants.sol";

/// @title MockSnapshotDeletingCreation
/// @notice A creation code whose constructor deletes every state snapshot.
contract MockSnapshotDeletingCreation {
    constructor() {
        StdConstants.VM.deleteStateSnapshots();
    }
}
