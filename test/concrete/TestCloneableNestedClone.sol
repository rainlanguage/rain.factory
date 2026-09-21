// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2} from "src/interface/ICloneableV2.sol";
import {ICloneableFactoryV4} from "src/interface/ICloneableFactoryV4.sol";

/// Thrown by a second call to `TestCloneableNestedClone.initialize`.
error TestCloneableNestedCloneAlreadyInitialized();

/// @title TestCloneableNestedClone
/// @notice An `ICloneableV2` whose `initialize` clones a second implementation
/// through the factory that is initializing it, so the factory is re-entered
/// from inside the `initialize` call it made. Every other fixture only stores,
/// emits, returns or reverts, so none of them can reach the re-entrant path at
/// all.
///
/// `data` is `abi.encode(factory, innerImplementation, innerSalt, innerData)`,
/// and the clone it deployed during its own initialization is `sInner`.
contract TestCloneableNestedClone is ICloneableV2 {
    /// The clone this one deployed during its own initialization.
    address public sInner;

    /// Whether `initialize` has already run on this clone. Written before the
    /// nested call, so the re-entrant deploy cannot slip back past the guard.
    bool public sInitialized;

    /// @inheritdoc ICloneableV2
    function initialize(bytes memory data) external returns (bytes32) {
        if (sInitialized) {
            revert TestCloneableNestedCloneAlreadyInitialized();
        }
        sInitialized = true;
        (address factory, address innerImplementation, bytes32 innerSalt, bytes memory innerData) =
            abi.decode(data, (address, address, bytes32, bytes));
        sInner = ICloneableFactoryV4(factory).cloneDeterministicOpenSalt(innerImplementation, innerData, innerSalt);
        // Deliberately the literal, not `ICLONEABLE_V2_SUCCESS`, as in
        // `TestCloneable`.
        return keccak256("ICloneableV2.initialize");
    }
}
