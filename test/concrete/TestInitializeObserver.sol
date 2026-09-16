// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {TestCloneableObserved} from "./TestCloneableObserved.sol";

/// @title TestInitializeObserver
/// @notice A third party that `TestCloneableObserved.initialize` reaches while
/// it is running, and that writes down what it can see of the caller at that
/// moment: its address, its code size and its `ICloneableV2` state as read
/// through the caller's own getters. Everything it records lives in its own
/// storage, so a test can compare what was observable INSIDE the deploying
/// transaction with what is observable after it, and whether the record
/// survives the transaction at all.
contract TestInitializeObserver {
    /// The `msg.sender` of the last `observe`. Zero until then.
    address public sObserved;

    /// `sObserved.code.length` at the moment of observation.
    uint256 public sCodeLength;

    /// `TestCloneableObserved(sObserved).sInitialized()` at the moment of
    /// observation.
    bool public sInitialized;

    /// `TestCloneableObserved(sObserved).sData()` at the moment of
    /// observation.
    bytes public sData;

    /// Records the caller's address, code size and `ICloneableV2` state as
    /// they are when called. The caller is the clone mid-`initialize`, so the
    /// address is taken from `msg.sender` rather than trusted from an
    /// argument.
    function observe() external {
        address clone = msg.sender;
        sObserved = clone;
        sCodeLength = clone.code.length;
        sInitialized = TestCloneableObserved(clone).sInitialized();
        sData = TestCloneableObserved(clone).sData();
    }
}
