// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2} from "src/interface/ICloneableV2.sol";

/// @title TestCloneableNearMissSuccess
/// @notice An `ICloneableV2` that returns the hash of a string ONE CHARACTER
/// away from the one the spec names. It is a well-formed 32-byte return, so it
/// reaches the sentinel comparison rather than reverting earlier, and it proves
/// the comparison is over the exact hash and not over "looks like a hash".
contract TestCloneableNearMissSuccess is ICloneableV2 {
    /// @inheritdoc ICloneableV2
    function initialize(bytes memory) external pure returns (bytes32) {
        return keccak256("ICloneableV2.initialise");
    }
}
