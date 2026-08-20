// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

// `ICloneableFactoryV3` is imported for the `@inheritdoc` references on the
// functions it declares; `ICloneableFactoryV4` inherits rather than redeclares
// them, so the tag must name V3 and V3 must be in scope here.
import {ICloneableFactoryV3} from "src/interface/ICloneableFactoryV3.sol";
import {ICloneableFactoryV4} from "src/interface/ICloneableFactoryV4.sol";
import {LibCloneFactory} from "src/lib/LibCloneFactory.sol";

/// @title TestCloneFactory
/// @notice A concrete `ICloneableFactoryV4` written the way the deploy half is
/// meant to write one: every function is a single delegation into
/// `LibCloneFactory` and nothing else. It exists so the flow tests exercise the
/// library through a real external surface — `msg.sender` namespacing and the
/// `NewClone` event are observable only across an external call — and it
/// doubles as the executable proof that the library surface suffices for a
/// pure-delegation concrete.
contract TestCloneFactory is ICloneableFactoryV4 {
    /// @inheritdoc ICloneableFactoryV3
    function cloneDeterministic(address implementation, bytes calldata data, bytes32 salt) external returns (address) {
        return LibCloneFactory.cloneDeterministic(implementation, data, salt);
    }

    /// @inheritdoc ICloneableFactoryV3
    function predictDeterministicAddress(address implementation, bytes32 salt, address deployer)
        external
        view
        returns (address)
    {
        return LibCloneFactory.predictDeterministicAddress(implementation, salt, deployer);
    }

    /// @inheritdoc ICloneableFactoryV4
    function cloneDeterministicOpenSalt(address implementation, bytes calldata data, bytes32 salt)
        external
        returns (address)
    {
        return LibCloneFactory.cloneDeterministicOpenSalt(implementation, data, salt);
    }

    /// @inheritdoc ICloneableFactoryV4
    function predictDeterministicAddressOpenSalt(address implementation, bytes calldata data, bytes32 salt)
        external
        view
        returns (address)
    {
        return LibCloneFactory.predictDeterministicAddressOpenSalt(implementation, data, salt);
    }
}
