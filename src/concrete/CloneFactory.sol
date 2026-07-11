// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "../interface/ICloneableV2.sol";
import {ICloneableFactoryV2} from "../interface/ICloneableFactoryV2.sol";
import {ICloneableFactoryV3} from "../interface/ICloneableFactoryV3.sol";
import {Clones} from "@openzeppelin-contracts-5.6.1/proxy/Clones.sol";

/// Thrown when an implementation has zero code size which is always a mistake.
error ZeroImplementationCodeSize();

/// Thrown when initialization fails.
error InitializationFailed();

/// @title CloneFactory
/// @notice A fairly minimal implementation of `ICloneableFactoryV3`
/// that uses Open Zeppelin `Clones` to create EIP1167 clones of a reference
/// bytecode. The reference bytecode MUST implement `ICloneableV2`.
///
/// `clone` deploys via `CREATE` (nonce-dependent address). `cloneDeterministic`
/// deploys via `CREATE2` at a pre-computable address
/// (`predictDeterministicAddress`), namespacing the caller-supplied salt by
/// `msg.sender` so a caller's `(implementation, salt)` address cannot be squatted
/// by another account.
contract CloneFactory is ICloneableFactoryV3 {
    /// @inheritdoc ICloneableFactoryV2
    function clone(address implementation, bytes calldata data) external returns (address) {
        // Explicitly check that the implementation has code. This is a common
        // mistake that will cause the clone to fail. Notably this catches the
        // case of address(0). This check is not strictly necessary as a zero
        // sized implementation will fail to initialize the child, but it gives
        // a better error message.
        _requireImplementationCode(implementation);
        // Standard Open Zeppelin clone here.
        address child = Clones.clone(implementation);
        return _initializeClone(implementation, child, data);
    }

    /// @inheritdoc ICloneableFactoryV3
    function cloneDeterministic(address implementation, bytes calldata data, bytes32 salt) external returns (address) {
        _requireImplementationCode(implementation);
        // CREATE2 clone at a salt namespaced by the caller (see `_effectiveSalt`).
        address child = Clones.cloneDeterministic(implementation, _effectiveSalt(msg.sender, salt));
        return _initializeClone(implementation, child, data);
    }

    /// @inheritdoc ICloneableFactoryV3
    function predictDeterministicAddress(address implementation, bytes32 salt, address deployer)
        external
        view
        returns (address)
    {
        return Clones.predictDeterministicAddress(implementation, _effectiveSalt(deployer, salt), address(this));
    }

    /// @dev The CREATE2 salt actually used: the caller-supplied `salt` namespaced
    /// by the deploying account. Prevents a caller's `(implementation, salt)`
    /// address being front-run/squatted by another account, while still letting a
    /// single caller mint many clones of one implementation via distinct salts.
    function _effectiveSalt(address deployer, bytes32 salt) internal pure returns (bytes32) {
        return keccak256(abi.encode(deployer, salt));
    }

    /// @dev Reverts with a clear error if `implementation` has no code.
    function _requireImplementationCode(address implementation) internal view {
        if (implementation.code.length == 0) {
            revert ZeroImplementationCodeSize();
        }
    }

    /// @dev Emit `NewClone` and run the mandatory `ICloneableV2.initialize` check.
    /// `NewClone` does NOT include the `data` passed to initialize; the
    /// implementation is responsible for emitting a data event if it wants.
    function _initializeClone(address implementation, address child, bytes calldata data) internal returns (address) {
        emit NewClone(msg.sender, implementation, child);
        // Checking the return value of initialize is mandatory as per
        // ICloneableFactoryV2.
        if (ICloneableV2(child).initialize(data) != ICLONEABLE_V2_SUCCESS) {
            revert InitializationFailed();
        }
        return child;
    }
}
