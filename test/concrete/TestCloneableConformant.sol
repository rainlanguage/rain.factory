// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "src/interface/ICloneableV2.sol";

/// @title TestCloneableConformant
/// @notice The `ICloneableV2` fixture that honours the interface's two
/// normative MUSTs, which `TestCloneable` does not:
///
/// - `initialize` MUST NOT be callable more than once, so a second call
///   reverts instead of overwriting state;
/// - the RECOMMENDED typed overload MUST revert `InitializeSignatureFn`
///   always, so it is never accidentally called instead of the generic
///   `initialize(bytes)` that the factory calls.
///
/// It exists so those obligations are executable rather than prose:
/// `TestCloneable` is deliberately the minimum a factory flow test needs and
/// satisfies neither.
contract TestCloneableConformant is ICloneableV2 {
    /// Set once, by the first and only `initialize`.
    bytes public sData;

    /// Whether `initialize` has already run. Set before the data so a
    /// re-entrant call cannot slip past the guard.
    bool public sInitialized;

    /// Thrown by a second `initialize`.
    error AlreadyInitialized();

    /// @inheritdoc ICloneableV2
    function initialize(bytes memory data) external returns (bytes32) {
        if (sInitialized) {
            revert AlreadyInitialized();
        }
        sInitialized = true;
        sData = data;
        return ICLONEABLE_V2_SUCCESS;
    }

    /// The RECOMMENDED typed overload of `initialize`, which exists only so
    /// the initialization config type appears in the ABI. It MUST revert
    /// always, per `ICloneableV2`.
    /// @param value The typed config that a caller would otherwise have
    /// passed. Never read.
    function initialize(uint256 value) external pure returns (bytes32) {
        value;
        revert InitializeSignatureFn();
    }
}
