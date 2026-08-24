// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "src/interface/ICloneableV2.sol";

/// @title TestCloneableEmitter
/// @notice An `ICloneableV2` that EMITS during `initialize`, and records every
/// call it receives. Neither `TestCloneable` nor `TestCloneableFailure` does
/// either, which leaves two clauses of the shared factory spec unobservable:
/// the ordering of `NewClone` against the clone's own initialization logs, and
/// the MUST NOT that no other function is called on the proxy before
/// `initialize`.
contract TestCloneableEmitter is ICloneableV2 {
    /// Emitted from inside `initialize`, so a test can place it in the log
    /// stream relative to `NewClone`.
    /// @param data The initialization data as the clone received it.
    event Initialized(bytes data);

    /// Emitted by the fallback, i.e. by ANY call that is not
    /// `initialize(bytes)`. Its presence before `Initialized` would be a spec
    /// violation by the factory.
    /// @param callData The calldata of the unexpected call.
    event UnexpectedCall(bytes callData);

    /// @inheritdoc ICloneableV2
    function initialize(bytes memory data) external returns (bytes32) {
        emit Initialized(data);
        return ICLONEABLE_V2_SUCCESS;
    }

    /// Any call other than `initialize(bytes)` lands here and is recorded.
    fallback() external {
        emit UnexpectedCall(msg.data);
    }
}
