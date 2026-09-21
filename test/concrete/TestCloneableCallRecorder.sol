// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2} from "src/interface/ICloneableV2.sol";

/// @title TestCloneableCallRecorder
/// @notice An `ICloneableV2` that records the selector of every call the proxy
/// receives other than its own `selectors()` and `sData()` accessors, in order,
/// and emits `Initializing` from inside `initialize`, so a test can read the
/// call sequence and where `NewClone` falls in it.
///
/// It refuses nothing: no once-only guard on `initialize`, no typed overload.
/// A call the factory should not have made is recorded, not reverted, so this
/// is not a conforming `ICloneableV2`.
contract TestCloneableCallRecorder is ICloneableV2 {
    /// Emitted from inside `initialize`, so the log stream orders the
    /// factory's `NewClone` against the initialization call itself.
    /// @param data The initialization data as the clone received it.
    event Initializing(bytes data);

    /// Every selector the proxy has been called with, in order, except this
    /// fixture's own `selectors()` and `sData()`. Storage lives on the clone,
    /// not the implementation, because the factory reaches this code through an
    /// EIP-1167 `DELEGATECALL` proxy.
    bytes4[] internal sSelectors;

    /// The data this clone was initialized with.
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
        // Deliberately the literal rather than `ICLONEABLE_V2_SUCCESS`, for
        // the same reason `TestCloneable` writes it out: a fixture that
        // imports the constant the library compares against moves in lockstep
        // with it and cannot discriminate a drift.
        return keccak256("ICloneableV2.initialize");
    }

    /// Records any other call the proxy receives, so a call the factory makes
    /// before `initialize` cannot go unseen. Deliberately does not revert: a
    /// factory that ignored the result of a stray call would otherwise leave
    /// no trace at all.
    fallback() external {
        sSelectors.push(msg.sig);
    }
}
