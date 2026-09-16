// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2} from "src/interface/ICloneableV2.sol";

/// @title TestCloneableRawRevert
/// @notice An `ICloneableV2` whose `initialize` always reverts, with the RAW
/// bytes it was given as the revert data: empty `data` is a bare `revert()`,
/// non-empty `data` is a revert carrying exactly those bytes. A factory calling
/// `initialize(data)` on a clone of this sees `data` bubble out of the EIP-1167
/// proxy as the revert data of `initialize`, so a test can pin what the factory
/// does with a reverting `initialize` for both the with-data and no-data
/// shapes from one fixture.
contract TestCloneableRawRevert is ICloneableV2 {
    /// @inheritdoc ICloneableV2
    function initialize(bytes memory data) external pure returns (bytes32) {
        assembly ("memory-safe") {
            revert(add(data, 0x20), mload(data))
        }
    }
}
