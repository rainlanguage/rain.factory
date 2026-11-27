// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {DeploySuite} from "rain-deploy-0.1.43/src/abstract/RainDeploySuitesBase.sol";
import {DeploySuiteIndex} from "rain-deploy-0.1.43/src/lib/LibRainDeployDeclaration.sol";

/// @title LibSuiteIndexPointers
/// @notice Where an index and its built arrays live in memory, to tell one index, and one build of it, from another.
library LibSuiteIndexPointers {
    function pointer(DeploySuiteIndex memory index) internal pure returns (uint256) {
        uint256 at;
        assembly ("memory-safe") {
            at := index
        }
        return at;
    }

    function pointer(DeploySuite[] memory suites) internal pure returns (uint256) {
        uint256 at;
        assembly ("memory-safe") {
            at := suites
        }
        return at;
    }

    function pointer(address[][] memory recorded) internal pure returns (uint256) {
        uint256 at;
        assembly ("memory-safe") {
            at := recorded
        }
        return at;
    }
}
