// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2} from "src/interface/ICloneableV2.sol";

/// @title TestCloneableLiteralSuccess
/// @notice An `ICloneableV2` that returns the success sentinel written out from
/// the LITERAL STRING the spec names, rather than importing
/// `ICLONEABLE_V2_SUCCESS`. That is the whole point of it.
///
/// `TestCloneable` imports the same constant the library compares against, so
/// the two move in lockstep: change the constant and every clone still
/// initializes, because both sides changed. A third party implementing
/// `ICloneableV2` has no such luxury — `ICloneableV2` tells them to return
/// `keccak256("ICloneableV2.initialize")` and they hard-code that value. This
/// contract stands in for that third party, so a drift in the constant shows up
/// as a real `InitializationFailed` through a real factory.
contract TestCloneableLiteralSuccess is ICloneableV2 {
    bytes public sData;

    /// @inheritdoc ICloneableV2
    function initialize(bytes memory data) external returns (bytes32) {
        sData = data;
        return keccak256("ICloneableV2.initialize");
    }
}
