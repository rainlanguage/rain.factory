// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "../../src/interface/ICloneableV2.sol";
import {MockStorageSource} from "./MockStorageSource.sol";

/// Thrown when `initialize` is told to revert.
error MockInitializeRefused();

/// How `MockStorageReadingCloneable.initialize` treats its source.
/// `Read` reads it. `Refuse` reverts with `MockInitializeRefused` without touching it.
enum SourceUse {
    Read,
    Refuse
}

/// @title MockStorageReadingCloneable
/// @notice A cloneable whose `initialize` reads a `MockStorageSource`, or reverts, as its data says.
contract MockStorageReadingCloneable is ICloneableV2 {
    /// @inheritdoc ICloneableV2
    function initialize(bytes calldata data) external returns (bytes32) {
        (MockStorageSource source, SourceUse use) = abi.decode(data, (MockStorageSource, SourceUse));
        if (use == SourceUse.Refuse) {
            revert MockInitializeRefused();
        }
        source.sValue();
        return ICLONEABLE_V2_SUCCESS;
    }
}
