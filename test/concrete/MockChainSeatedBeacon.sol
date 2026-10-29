// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

contract MockChainSeatedBeacon {
    address internal sImplementation;
    address internal sOwner;

    // Answered back verbatim, authorising nothing.
    //forge-lint: disable-next-line(missing-zero-check)
    constructor(address beaconImplementation, address ownerOnChain, address ownerElsewhere, uint256 chainId) {
        sImplementation = beaconImplementation;
        sOwner = block.chainid == chainId ? ownerOnChain : ownerElsewhere;
    }

    function implementation() external view returns (address) {
        return sImplementation;
    }

    function owner() external view returns (address) {
        return sOwner;
    }
}
