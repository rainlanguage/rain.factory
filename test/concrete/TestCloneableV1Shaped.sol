// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV1} from "src/interface/deprecated/ICloneableV1.sol";

/// @title TestCloneableV1Shaped
/// @notice A legacy `ICloneableV1`: `initialize(bytes)`, the selector
/// `ICloneableV2.initialize` also has, succeeding with no return value.
contract TestCloneableV1Shaped is ICloneableV1 {
    /// The data `initialize` was last called with.
    bytes public sData;

    /// @inheritdoc ICloneableV1
    function initialize(bytes memory data) external {
        sData = data;
    }
}
