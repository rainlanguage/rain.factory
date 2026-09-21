// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2} from "src/interface/ICloneableV2.sol";

/// @title TestCloneableGasRecorder
/// @notice An `ICloneableV2` that records the gas available to `initialize` at
/// the moment the factory calls it. `TestCloneable` exposes only the data the
/// clone was initialized with, which says nothing about the budget the call
/// carried, so the gas the factory hands `initialize` is observable through
/// this fixture and nothing else.
contract TestCloneableGasRecorder is ICloneableV2 {
    /// `gasleft()` on entry to `initialize`. Storage lives on the clone, not
    /// the implementation, because the factory reaches this code through an
    /// EIP-1167 `DELEGATECALL` proxy.
    uint256 public sInitializeGas;

    /// The parameter is unnamed because this fixture records the call's gas and
    /// nothing about its data.
    /// @inheritdoc ICloneableV2
    function initialize(bytes memory) external returns (bytes32) {
        sInitializeGas = gasleft();
        // Deliberately the literal, not `ICLONEABLE_V2_SUCCESS`, as in
        // `TestCloneable`.
        return keccak256("ICloneableV2.initialize");
    }
}
