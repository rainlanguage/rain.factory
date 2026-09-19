// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2} from "src/interface/ICloneableV2.sol";

/// Thrown unconditionally by `TestCloneableRevert.initialize`, carrying the
/// data it was called with so a test can prove both that the revert came from
/// the implementation rather than the factory, and that its arguments survive
/// the trip verbatim.
/// @param data The initialization data the clone was called with.
error TestCloneableRevertInitialize(bytes data);

/// @title TestCloneableRevert
/// @notice An `ICloneableV2` whose `initialize` REVERTS, with its own typed
/// error carrying its own data.
///
/// This is the other half of "initialization failed" from
/// `TestCloneableFailure`, and the two are not interchangeable.
/// `TestCloneableFailure` RETURNS a non-success value, which is the case the
/// library answers with its own `InitializationFailed`. This one REFUSES —
/// what a real implementation does when its `data` does not decode or its
/// invariants do not hold — and the library must let that revert through
/// untouched instead of flattening it. A fixture that returns cannot exercise
/// that, and a fixture that reverts cannot exercise the sentinel comparison,
/// so both exist.
contract TestCloneableRevert is ICloneableV2 {
    /// @inheritdoc ICloneableV2
    function initialize(bytes memory data) external pure returns (bytes32) {
        revert TestCloneableRevertInitialize(data);
    }
}
