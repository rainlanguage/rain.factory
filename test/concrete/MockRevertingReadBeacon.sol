// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

contract MockRevertingReadBeacon {
    error Unanswered();

    address internal sImplementation;
    address internal sOwner;
    bool internal sOwnerReverts;

    //forge-lint: disable-next-line(missing-zero-check)
    constructor(address beaconImplementation, address initialOwner, bool ownerReverts) {
        sImplementation = beaconImplementation;
        sOwner = initialOwner;
        sOwnerReverts = ownerReverts;
    }

    function owner() external view returns (address) {
        if (sOwnerReverts) {
            revert Unanswered();
        }
        return sOwner;
    }

    function implementation() external view returns (address) {
        if (!sOwnerReverts) {
            revert Unanswered();
        }
        return sImplementation;
    }
}
