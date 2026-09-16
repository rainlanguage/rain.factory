// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {TestCloneableObserved} from "./TestCloneableObserved.sol";

/// @title TestInitializeObserver
/// @notice A third party that `TestCloneableObserved.initialize` reaches while
/// it is running, and that writes down what it can see of the clone at that
/// moment: the clone's address, its code size and its `ICloneableV2` state as
/// read through the clone's own getters. Everything it records lives in its
/// own storage, so a test can compare what was observable INSIDE the deploying
/// transaction with what is observable after it, and whether the record
/// survives the transaction at all.
contract TestInitializeObserver {
    /// The clone `observe` was last called for. Zero until then.
    address public sObserved;

    /// `sObserved.code.length` at the moment of observation.
    uint256 public sCodeLength;

    /// `TestCloneableObserved(sObserved).sInitialized()` at the moment of
    /// observation.
    bool public sInitialized;

    /// `TestCloneableObserved(sObserved).sData()` at the moment of
    /// observation.
    bytes public sData;

    /// Records the clone's address, code size and `ICloneableV2` state as they
    /// are when called.
    /// @param clone The clone to observe.
    function observe(address clone) external {
        sObserved = clone;
        sCodeLength = clone.code.length;
        sInitialized = TestCloneableObserved(clone).sInitialized();
        sData = TestCloneableObserved(clone).sData();
    }
}
