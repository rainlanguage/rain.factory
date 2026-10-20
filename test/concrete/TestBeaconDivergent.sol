// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

/// @title TestBeaconDivergent
/// @notice A beacon that answers `implementation()` with a real implementation
/// to the factory and the zero address to every other caller, so it passes the
/// factory's beacon check and fails the `BeaconProxy` constructor's.
contract TestBeaconDivergent {
    /// The caller that gets `iImplementation`.
    address internal immutable iFactory;
    /// The implementation the factory is shown.
    address internal immutable iImplementation;

    //forge-lint: disable-next-line(missing-zero-check)
    constructor(address factory, address factoryImplementation) {
        iFactory = factory;
        iImplementation = factoryImplementation;
    }

    /// `iImplementation` to `iFactory`, the zero address to anyone else.
    function implementation() external view returns (address) {
        return msg.sender == iFactory ? iImplementation : address(0);
    }
}
