// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Proxy} from "@openzeppelin-contracts-5.6.1/proxy/Proxy.sol";
import {ERC1967Utils} from "@openzeppelin-contracts-5.6.1/proxy/ERC1967/ERC1967Utils.sol";
import {IBeacon} from "@openzeppelin-contracts-5.6.1/proxy/beacon/IBeacon.sol";

import {ICloneableFactoryV6} from "../src/interface/ICloneableFactoryV6.sol";

/// @title RegistryBeaconProxy
/// @notice OpenZeppelin `BeaconProxy` with no constructor argument: it adopts
/// the beacon its deploying factory holds as `pendingBeacon`, so its creation
/// code, and so its CREATE2 address, is the same on every chain. Not deployed
/// on its own: `script/Build.sol` snapshots its creation code into
/// `src/generated/RegistryBeaconProxy.sol`, which `LibICloneableFactoryV6` deploys.
contract RegistryBeaconProxy is Proxy {
    /// The beacon, as `BeaconProxy` keeps it.
    address private immutable iBeacon;

    constructor() {
        address beacon = ICloneableFactoryV6(msg.sender).pendingBeacon();
        ERC1967Utils.upgradeBeaconToAndCall(beacon, "");
        iBeacon = beacon;
    }

    /// @inheritdoc Proxy
    function _implementation() internal view virtual override returns (address) {
        return IBeacon(iBeacon).implementation();
    }
}
