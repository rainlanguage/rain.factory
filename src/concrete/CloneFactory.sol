// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "../interface/ICloneableV2.sol";
import {ICloneableFactoryV2} from "../interface/ICloneableFactoryV2.sol";
import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";

/// Thrown when an implementation has zero code size which is always a mistake.
error ZeroImplementationCodeSize();

/// Thrown when initialization fails.
error InitializationFailed();

/// @title CloneFactory
/// @notice A fairly minimal implementation of `ICloneableFactoryV2` and
/// `DeployerDiscoverableMetaV2` that uses Open Zeppelin `Clones` to create
/// EIP1167 clones of a reference bytecode. The reference bytecode MUST implement
/// `ICloneableV2`.
contract CloneFactory is ICloneableFactoryV2 {
    /// @inheritdoc ICloneableFactoryV2
    function clone(address implementation, bytes calldata data) external returns (address) {
        // Explicitly check that the implementation has code. This is a common
        // mistake that will cause the clone to fail. Notably this catches the
        // case of address(0). This check is not strictly necessary as a zero
        // sized implementation will fail to initialize the child, but it gives
        // a better error message.
        if (implementation.code.length == 0) {
            revert ZeroImplementationCodeSize();
        }
        // Standard Open Zeppelin clone here.
        address child = Clones.clone(implementation);
        // NewClone does NOT include the data passed to initialize.
        // The implementation is responsible for emitting an event if it wants.
        emit NewClone(msg.sender, implementation, child);
        // Checking the return value of initialize is mandatory as per
        // ICloneableFactoryV2.
        if (ICloneableV2(child).initialize(data) != ICLONEABLE_V2_SUCCESS) {
            revert InitializationFailed();
        }
        return child;
    }
}
