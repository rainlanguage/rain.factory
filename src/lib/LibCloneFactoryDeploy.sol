// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @title LibCloneFactoryDeploy
/// A library containing the deployed address and code hash of the CloneFactory
/// contract when deployed with the rain standard zoltu deployer. This allows
/// idempotent deployments against precommitted addresses and hashes that can be
/// easily verified automatically in tests and scripts rather than relying on
/// registries or manual verification.
library LibCloneFactoryDeploy {
    /// The address of the `CloneFactory` contract when deployed with the rain
    /// standard zoltu deployer.
    address constant CLONE_FACTORY_DEPLOYED_ADDRESS = address(0x444acC29d63fa643E8adCC35FD9aa6DE111dCb39);

    /// The code hash of the `CloneFactory` contract when deployed with the rain
    /// standard zoltu deployer. This can be used to verify that the deployed
    /// contract has the expected bytecode, which provides stronger guarantees
    /// than just checking the address.
    bytes32 constant CLONE_FACTORY_DEPLOYED_CODEHASH =
        bytes32(0xf21b813c7075a1621285df3a8369d0652c31ea80cb807be1aaadafeecd134475);
}
