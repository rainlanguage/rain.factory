// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2} from "src/interface/ICloneableV2.sol";

/// Thrown by a second call to `TestCloneable.initialize`. `ICloneableV2` says
/// the implementation MUST ensure `initialize` can NOT be called more than
/// once; this is how this fixture ensures it.
error TestCloneableAlreadyInitialized();

/// @title TestCloneable
/// @notice A conforming `ICloneableV2`. Stores the `data` it was initialized
/// with in `sData`, reverts a second `initialize`, and reverts the typed
/// overload with `InitializeSignatureFn`.
///
/// The success sentinel is the literal `keccak256("ICloneableV2.initialize")`,
/// not the imported `ICLONEABLE_V2_SUCCESS`: importing it would move both
/// sides of the library's comparison together, so a drift in the constant
/// would still initialize.
contract TestCloneable is ICloneableV2 {
    /// The data this clone was initialized with. Set once.
    bytes public sData;

    /// Whether `initialize` has already run on this clone. Storage lives on
    /// the clone, not the implementation, because the factory reaches this
    /// code through an EIP-1167 `DELEGATECALL` proxy.
    bool public sInitialized;

    /// @inheritdoc ICloneableV2
    function initialize(bytes memory data) external returns (bytes32) {
        if (sInitialized) {
            revert TestCloneableAlreadyInitialized();
        }
        sInitialized = true;
        sData = data;
        // Deliberately the literal, not `ICLONEABLE_V2_SUCCESS`. See the
        // contract notice.
        return keccak256("ICloneableV2.initialize");
    }

    /// The RECOMMENDED typed overload of `initialize`, which exists only so an
    /// initialization config type appears in the ABI. `ICloneableV2` requires
    /// it to revert `InitializeSignatureFn` ALWAYS, so that it is never
    /// accidentally called in place of the generic `initialize(bytes)` the
    /// factory calls. The parameter is unnamed because it is never read.
    /// @return Never returns; the declared return type only exists so the
    /// overload has the shape a real typed `initialize` would.
    function initialize(uint256) external pure returns (bytes32) {
        revert InitializeSignatureFn();
    }
}
