// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

/// @title TestCloneableRawAnswer
/// @notice `initialize(abi.encode(reverts, answer))` reverts with, or returns,
/// the raw bytes `answer`.
contract TestCloneableRawAnswer {
    function initialize(bytes calldata data) external pure {
        (bool reverts, bytes memory answer) = abi.decode(data, (bool, bytes));
        assembly ("memory-safe") {
            if reverts { revert(add(answer, 0x20), mload(answer)) }
            return(add(answer, 0x20), mload(answer))
        }
    }
}
