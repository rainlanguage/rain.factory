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
    address constant CLONE_FACTORY_DEPLOYED_ADDRESS = address(0xEf164EB7Be73dc07Ce5f9f7E1Be7cba55Df0B3C8);

    /// The code hash of the `CloneFactory` contract when deployed with the rain
    /// standard zoltu deployer. This can be used to verify that the deployed
    /// contract has the expected bytecode, which provides stronger guarantees
    /// than just checking the address.
    bytes32 constant CLONE_FACTORY_DEPLOYED_CODEHASH =
        bytes32(0xe0719ff63038a9968ccd0664f5446251dca6e680860f1e153027da16c9fac6e3);
}
