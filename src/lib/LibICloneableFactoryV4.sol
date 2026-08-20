// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

import {
    ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN,
    ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN
} from "../interface/ICloneableFactoryV4.sol";

/// @title LibICloneableFactoryV4
/// @notice The executable form of the two effective-`CREATE2`-salt derivations
/// that `ICloneableFactoryV4` pins to exact bytes, so a factory, an indexer or a
/// consumer predicting a clone address computes them from one place instead of
/// re-deriving the formulas inline. Each function reproduces its interface
/// formula byte for byte and reads its domain tag from the interface, so the
/// tags have a single source of truth and the derivation cannot drift from the
/// spec. See `ICloneableFactoryV4` for what each salt commits to and why the two
/// images are disjoint.
library LibICloneableFactoryV4 {
    /// The effective `CREATE2` salt for the namespaced derivation
    /// (`cloneDeterministic` / `predictDeterministicAddress`): the caller-chosen
    /// `salt` behind the namespaced domain tag and `deployer`, so the salt — and
    /// therefore the clone address — is namespaced to the account that deploys.
    /// @param deployer The account whose namespace the salt belongs to (the
    /// `msg.sender` of `cloneDeterministic`, or the `deployer` argument of
    /// `predictDeterministicAddress`).
    /// @param salt The caller-chosen salt, before namespacing.
    /// @return The effective salt `CREATE2` hashes.
    function effectiveSalt(address deployer, bytes32 salt) internal pure returns (bytes32) {
        return keccak256(abi.encode(ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN, deployer, salt));
    }

    /// The effective `CREATE2` salt for the open-salt derivation
    /// (`cloneDeterministicOpenSalt` / `predictDeterministicAddressOpenSalt`):
    /// the caller-chosen `salt` and the hash of the initialization `data` behind
    /// the open-salt domain tag, and nothing about the caller, so the clone
    /// address commits to `salt` and `data` and every account reaches the same
    /// one. `data` MAY be empty.
    /// @param salt The caller-chosen salt.
    /// @param data The initialization data passed to `ICloneableV2.initialize`.
    /// @return The effective salt `CREATE2` hashes.
    function effectiveOpenSalt(bytes32 salt, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data)));
    }
}
