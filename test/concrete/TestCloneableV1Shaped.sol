// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV1} from "src/interface/deprecated/ICloneableV1.sol";

/// @title TestCloneableV1Shaped
/// @notice A legacy `ICloneableV1`: `initialize(bytes)` with NO return value.
/// Its selector is `initialize(bytes)` — byte for byte the same selector
/// `ICloneableV2` publishes — so a V4 factory will happily call it and only
/// the return arity distinguishes the two interfaces. The fixture exists so
/// that difference is exercised rather than assumed.
contract TestCloneableV1Shaped is ICloneableV1 {
    /// Set by `initialize`, so a test can prove the call actually landed.
    bytes public sData;

    /// @inheritdoc ICloneableV1
    function initialize(bytes memory data) external {
        sData = data;
    }
}
