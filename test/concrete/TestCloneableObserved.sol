// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2} from "src/interface/ICloneableV2.sol";
import {TestInitializeObserver} from "./TestInitializeObserver.sol";

/// @title TestCloneableObserved
/// @notice An `ICloneableV2` whose `initialize` calls out to a
/// `TestInitializeObserver` BEFORE it writes any state, so a third party sees
/// the clone in the window between the factory's `CREATE2` and the state
/// `initialize` sets. Same `sData` / `sInitialized` shape as `TestCloneable`,
/// so the observer reads the pre-initialization state through the same
/// getters a test reads the post-initialization state through.
///
/// `initialize` returns `I_RESULT`, fixed at construction: the literal
/// `keccak256("ICloneableV2.initialize")` for a clone that initializes, or
/// anything else for one whose deploying transaction the factory reverts after
/// the observer has already run. Both are immutables, embedded in the
/// implementation's code, so every clone delegating to it sees them.
contract TestCloneableObserved is ICloneableV2 {
    /// The third party `initialize` reaches.
    TestInitializeObserver public immutable I_OBSERVER;

    /// What `initialize` returns.
    bytes32 public immutable I_RESULT;

    /// The data this clone was initialized with. Empty until then.
    bytes public sData;

    /// Whether `initialize` has run to the point of writing state on this
    /// clone. False while the observer is looking.
    bool public sInitialized;

    /// @param observer The third party `initialize` calls out to.
    /// @param result What `initialize` returns.
    constructor(TestInitializeObserver observer, bytes32 result) {
        I_OBSERVER = observer;
        I_RESULT = result;
    }

    /// @inheritdoc ICloneableV2
    function initialize(bytes memory data) external returns (bytes32) {
        I_OBSERVER.observe(address(this));
        sInitialized = true;
        sData = data;
        return I_RESULT;
    }
}
