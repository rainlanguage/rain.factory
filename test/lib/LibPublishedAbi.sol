// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Vm} from "forge-std-1.16.1/src/Vm.sol";

/// @dev The `Vm` address, as forge-std computes it. Duplicated here rather than
/// inherited from `Test` so this helper is usable from a plain library.
Vm constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

/// @title LibPublishedAbi
/// @notice Reads a compiled artifact's `abi` array so a test can pin what the
/// EVM cannot see.
///
/// Everything in `src/interface` is a PUBLISHED surface: downstream indexers
/// and soldeer consumers decode `NewClone` and call `initialize` from the ABI,
/// BY NAME. Four things in a declaration are consumer-visible but completely
/// invisible on chain:
///
/// - parameter NAMES,
/// - the ORDER of parameters that share a type (swapping two `address` event
///   parameters changes no topic, no log data byte and no selector),
/// - `indexed` flags on parameters that are not currently indexed,
/// - RETURN types (they are not part of a function selector).
///
/// A log-level or selector-level assertion cannot discriminate any of them, so
/// the compiled artifact is the only oracle. `forge test` recompiles before it
/// runs, so the artifact read here is never stale with respect to the source
/// under test.
library LibPublishedAbi {
    /// The full artifact JSON for `<file>.sol/<name>.json` under `out`.
    /// @param file The solidity file name, without extension.
    /// @param name The contract or interface name within it.
    /// @return The artifact JSON.
    function artifactJson(string memory file, string memory name) internal view returns (string memory) {
        return VM.readFile(string.concat("out/", file, ".sol/", name, ".json"));
    }
}
