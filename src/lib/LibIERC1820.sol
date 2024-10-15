// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity ^0.8.18;

import "openzeppelin-contracts/contracts/utils/introspection/IERC1820Registry.sol";

/// @dev https://eips.ethereum.org/EIPS/eip-1820#single-use-registry-deployment-account
IERC1820Registry constant IERC1820_REGISTRY = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
