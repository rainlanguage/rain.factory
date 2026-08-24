// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2} from "src/interface/ICloneableV2.sol";

/// Thrown by `TestCloneableRevert.initialize`, carrying the data it was called
/// with so a test can prove the revert came from the implementation and not
/// from the factory.
/// @param data The initialization data the clone was called with.
error TestCloneableRevertInitialize(bytes data);

/// @title TestCloneableRevert
/// @notice A cloneable contract whose `initialize` REVERTS rather than
/// returning a non-success value. `TestCloneableFailure` covers the
/// wrong-return-value half of "initialization failed"; this covers the half
/// where the implementation refuses outright, which is what a real
/// implementation does when its `data` does not decode or its invariants do
/// not hold.
contract TestCloneableRevert is ICloneableV2 {
    /// @inheritdoc ICloneableV2
    function initialize(bytes memory data) external pure returns (bytes32) {
        revert TestCloneableRevertInitialize(data);
    }
}
