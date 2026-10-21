// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @title IBeaconImplementation
/// @notice The OpenZeppelin `IBeacon` read, declared here as `src/` imports
/// nothing from outside this repo.
interface IBeaconImplementation {
    /// @return The implementation the beacon serves.
    function implementation() external view returns (address);
}
