// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Vm} from "forge-std-1.16.1/src/Vm.sol";

/// @title LibPublishedAbi
/// @notice Reads a compiled artifact so a test can assert on the ABI entries
/// it publishes. Parameter names, the order of parameters that share a type,
/// `indexed` flags and return types are in the ABI but not in any selector,
/// topic or log, so the artifact is where a test observes them. `forge test`
/// compiles before it runs, so the artifact is the one built from the source
/// under test.
library LibPublishedAbi {
    /// The artifact JSON at `out/<file>.sol/<name>.json`.
    /// @param vm forge-std's cheatcode handle, which reads the file.
    /// @param file The source file name, without the `.sol` extension.
    /// @param name The contract or interface name within it.
    /// @return The artifact JSON.
    function artifactJson(Vm vm, string memory file, string memory name) internal view returns (string memory) {
        return vm.readFile(string.concat("out/", file, ".sol/", name, ".json"));
    }
}
