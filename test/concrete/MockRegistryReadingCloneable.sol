// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "../../src/interface/ICloneableV2.sol";
import {IConfigRegistryV5} from "rain-deploy-0.1.32/src/interface/IConfigRegistryV5.sol";

/// @title MockRegistryReadingCloneable
/// @notice A cloneable whose `initialize` keeps the value a registry binds to a name, read under the chain id its
/// init data names, or under any when it names zero.
contract MockRegistryReadingCloneable is ICloneableV2 {
    /// The value read.
    bytes public sValue;

    /// @inheritdoc ICloneableV2
    function initialize(bytes calldata data) external returns (bytes32) {
        (address registry, address authority, bytes32 name, uint256 chainId) =
            abi.decode(data, (address, address, bytes32, uint256));
        if (chainId == 0 || chainId == block.chainid) {
            (sValue,,) = IConfigRegistryV5(registry).getV5(authority, name);
        }
        return ICLONEABLE_V2_SUCCESS;
    }
}
