// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

/// @title TestFallbackRawReturn
/// @notice A contract with no `initialize(bytes)` whose fallback answers every
/// call by returning RAW bytes of the caller's choosing: it ABI decodes the
/// call's single `bytes` argument and returns those bytes verbatim, with no ABI
/// encoding around them. A factory calling `initialize(rawReturn)` on a clone
/// of this therefore sees `rawReturn` as the return data of `initialize` —
/// empty, short, over-long, or exactly one word — so a test can drive the
/// factory's return-shape check through every shape from one fixture.
contract TestFallbackRawReturn {
    fallback() external {
        bytes memory rawReturn = abi.decode(msg.data[4:], (bytes));
        assembly ("memory-safe") {
            return(add(rawReturn, 0x20), mload(rawReturn))
        }
    }
}
