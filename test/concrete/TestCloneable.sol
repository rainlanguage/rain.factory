// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2} from "src/interface/ICloneableV2.sol";

/// Thrown by a second call to `TestCloneable.initialize`. `ICloneableV2` says
/// the implementation MUST ensure `initialize` can NOT be called more than
/// once; this is how this fixture ensures it.
error TestCloneableAlreadyInitialized();

/// @title TestCloneable
/// @notice THE conforming `ICloneableV2` fixture. Every test that needs a
/// clone that initializes successfully uses this one, so there is a single
/// place where "what a correct `ICloneableV2` does" is written down, and every
/// flow test in the suite is run against something that actually honours the
/// interface rather than against the minimum the factory happens to check.
///
/// Three properties, each load bearing:
///
/// - It stores whatever `data` it was initialized with in the public `sData`,
///   so a test can prove the bytes reached the clone verbatim.
/// - `initialize` can NOT be called more than once — the interface's first
///   normative MUST. The flag is written before the data so a re-entrant call
///   cannot slip past the guard.
/// - It returns the success sentinel written out from the LITERAL STRING
///   `ICloneableV2` names, NOT the imported `ICLONEABLE_V2_SUCCESS`. Importing
///   the constant would put both sides of the library's comparison in
///   lockstep: change the constant and every clone still initializes, because
///   the fixture changed with it. A third party implementing `ICloneableV2`
///   has no such luxury — the interface tells them to return
///   `keccak256("ICloneableV2.initialize")` and they hard-code that value — so
///   the fixture hard-codes it too, and a drift in the constant surfaces as a
///   real `InitializationFailed` through a real factory.
///
/// It also carries the RECOMMENDED typed overload, which the interface
/// requires to revert `InitializeSignatureFn` always.
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
