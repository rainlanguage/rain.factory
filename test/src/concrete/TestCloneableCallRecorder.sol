// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "src/interface/ICloneableV2.sol";

/// @title TestCloneableCallRecorder
/// @notice A cloneable contract that records the selector of every call the
/// proxy receives, in order, and emits a log of its own from inside
/// `initialize`. `TestCloneable` observes only the end state, so nothing about
/// the CALL SEQUENCE on a fresh clone — "MUST call `initialize` ... MUST NOT
/// call anything else on the proxy first", and `NewClone` before `initialize`
/// — is visible through it. This one makes both observable: `sSelectors` is
/// the whole sequence, and `Initializing` lands in the log stream at the
/// moment `initialize` runs.
contract TestCloneableCallRecorder is ICloneableV2 {
    /// Emitted from inside `initialize`, so the log stream orders the factory's
    /// `NewClone` against the initialization call itself.
    /// @param data The initialization data.
    event Initializing(bytes data);

    /// Every selector the proxy has been called with, in order. Storage lives
    /// on the clone, because the factory reaches this code through a
    /// `DELEGATECALL` proxy.
    bytes4[] internal sSelectors;

    /// The data the proxy was initialized with.
    bytes public sData;

    /// The selectors recorded so far, in call order.
    /// @return The recorded selectors.
    function selectors() external view returns (bytes4[] memory) {
        return sSelectors;
    }

    /// @inheritdoc ICloneableV2
    function initialize(bytes memory data) external returns (bytes32) {
        sSelectors.push(msg.sig);
        sData = data;
        emit Initializing(data);
        return ICLONEABLE_V2_SUCCESS;
    }

    /// Records any other call the proxy receives, so a call the factory makes
    /// before `initialize` cannot go unseen. Deliberately does not revert: a
    /// factory that ignored the return value of a stray call would otherwise
    /// leave no trace at all.
    fallback() external {
        sSelectors.push(msg.sig);
    }
}
