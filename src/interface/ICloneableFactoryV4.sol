// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

import {ICloneableFactoryV3} from "./deprecated/ICloneableFactoryV3.sol";

/// @dev Word 0 of the namespaced effective-salt preimage.
bytes32 constant ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN = keccak256("rain.factory.clone.namespaced");

/// @dev Word 0 of the open-salt effective-salt preimage.
bytes32 constant ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN = keccak256("rain.factory.clone.opensalt");

/// @title ICloneableFactoryV4
/// @notice Adds an open-salt derivation to the namespaced one inherited from
/// `ICloneableFactoryV3`. Effective `CREATE2` salts:
/// - namespaced: `keccak256(abi.encode(NAMESPACED_DOMAIN, msg.sender, salt))`
/// - open-salt: `keccak256(abi.encode(OPEN_SALT_DOMAIN, salt, keccak256(data)))`
/// The distinct word-0 tags make the two images disjoint. Namespaced addresses
/// commit to the deployer, open-salt addresses to `data`.
interface ICloneableFactoryV4 is ICloneableFactoryV3 {
    /// Clones `implementation` at the open-salt address, with the atomic
    /// initialize and raw-salt `NewClone` of
    /// `ICloneableFactoryV3.cloneDeterministic`. MUST NOT mix any caller-derived
    /// value into the salt, nor expose another entry point whose salt image
    /// overlaps this one. Anyone can deploy first, so `initialize` MUST depend
    /// only on `data` and state no third party can set within a transaction:
    /// no `tx.origin`, no gas-dependent state, no mutable delegation target.
    function cloneDeterministicOpenSalt(address implementation, bytes calldata data, bytes32 salt)
        external
        returns (address);

    /// The address `cloneDeterministicOpenSalt` deploys to, for any caller.
    function predictDeterministicAddressOpenSalt(address implementation, bytes calldata data, bytes32 salt)
        external
        view
        returns (address);
}
