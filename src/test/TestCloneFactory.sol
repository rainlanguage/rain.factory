// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

// `ICloneableFactoryV3` and `ICloneableFactoryV4` are imported for the
// `@inheritdoc` references on the functions they declare; each newer interface
// inherits rather than redeclares them, so the tag must name the declaring
// interface and it must be in scope here.
import {ICloneableFactoryV3} from "../interface/deprecated/ICloneableFactoryV3.sol";
import {ICloneableFactoryV4} from "../interface/deprecated/ICloneableFactoryV4.sol";
import {ICloneableFactoryV5} from "../interface/ICloneableFactoryV5.sol";
import {LibICloneableFactoryV5} from "../lib/LibICloneableFactoryV5.sol";

/// @title TestCloneFactory
/// @notice A concrete `ICloneableFactoryV5` written the way the deploy half is
/// meant to write one: every function is a single delegation into
/// `LibICloneableFactoryV5` and nothing else. It
/// exists so the flow tests exercise the libraries through a real external
/// surface — `msg.sender` namespacing and the `NewClone` event are observable
/// only across an external call — and it doubles as the executable proof that
/// the library surface suffices for a pure-delegation concrete.
contract TestCloneFactory is ICloneableFactoryV5 {
    /// @inheritdoc ICloneableFactoryV3
    function cloneDeterministic(address implementation, bytes calldata data, bytes32 salt) external returns (address) {
        return LibICloneableFactoryV5.cloneDeterministic(implementation, data, salt);
    }

    /// @inheritdoc ICloneableFactoryV3
    function predictDeterministicAddress(address implementation, bytes32 salt, address deployer)
        external
        view
        returns (address)
    {
        return LibICloneableFactoryV5.predictDeterministicAddress(implementation, salt, deployer);
    }

    /// @inheritdoc ICloneableFactoryV4
    function cloneDeterministicOpenSalt(address implementation, bytes calldata data, bytes32 salt)
        external
        returns (address)
    {
        return LibICloneableFactoryV5.cloneDeterministicOpenSalt(implementation, data, salt);
    }

    /// @inheritdoc ICloneableFactoryV4
    function predictDeterministicAddressOpenSalt(address implementation, bytes calldata data, bytes32 salt)
        external
        view
        returns (address)
    {
        return LibICloneableFactoryV5.predictDeterministicAddressOpenSalt(implementation, data, salt);
    }

    /// @inheritdoc ICloneableFactoryV5
    function beaconProxyDeterministicOpenSalt(address beacon, bytes calldata data, bytes32 salt)
        external
        returns (address)
    {
        return LibICloneableFactoryV5.beaconProxyDeterministicOpenSalt(beacon, data, salt);
    }

    /// @inheritdoc ICloneableFactoryV5
    function predictBeaconProxyAddressOpenSalt(address beacon, bytes calldata data, bytes32 salt)
        external
        view
        returns (address)
    {
        return LibICloneableFactoryV5.predictBeaconProxyAddressOpenSalt(beacon, data, salt);
    }
}
