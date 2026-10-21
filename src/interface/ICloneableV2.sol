// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @dev Returned by a successful `ICloneableV2.initialize`.
bytes32 constant ICLONEABLE_V2_SUCCESS = keccak256("ICloneableV2.initialize");

/// @title ICloneableV2
interface ICloneableV2 {
    /// A typed `initialize` overload, recommended for ABI tooling, MUST always
    /// revert with this.
    error InitializeSignatureFn();

    /// Constructor for a clone. MUST be callable at most once; functions called
    /// before it MUST be safe or revert. MUST return `ICLONEABLE_V2_SUCCESS`.
    function initialize(bytes calldata data) external returns (bytes32 success);
}
