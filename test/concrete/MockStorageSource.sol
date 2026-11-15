// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

/// @title MockStorageSource
/// @notice One storage word another contract's `initialize` reads.
contract MockStorageSource {
    /// The word read.
    uint256 public sValue;
}
