// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Proxy} from "@openzeppelin-contracts-5.6.1/proxy/Proxy.sol";
import {ERC1967Utils} from "@openzeppelin-contracts-5.6.1/proxy/ERC1967/ERC1967Utils.sol";
import {IBeacon} from "@openzeppelin-contracts-5.6.1/proxy/beacon/IBeacon.sol";

import {LibICloneableFactoryV7} from "../src/lib/LibICloneableFactoryV7.sol";

/// @title RegistryBeaconProxy
/// @notice OpenZeppelin `BeaconProxy` whose beacon is the one `beaconName` is
/// bound to under `authority` in `registry` on the chain it is deployed to. Its
/// constructor arguments are the same on every chain, so its creation code,
/// and so its CREATE2 address, is too. Not deployed on its own:
/// `script/Build.sol` snapshots its creation code into
/// `src/generated/RegistryBeaconProxy.sol`, which `LibICloneableFactoryV7`
/// deploys.
contract RegistryBeaconProxy is Proxy {
    /// The beacon, as `BeaconProxy` keeps it.
    address private immutable iBeacon;

    /// @param registry An `IConfigRegistryV5`.
    /// @param authority The authority the beacon's name is bound under.
    /// @param beaconName The name the beacon is bound to.
    // A zero registry or authority resolves no binding, so `resolveBeacon` reverts.
    //forge-lint: disable-next-line(missing-zero-check)
    constructor(address registry, address authority, bytes32 beaconName) {
        address beacon = LibICloneableFactoryV7.resolveBeacon(registry, authority, beaconName);
        ERC1967Utils.upgradeBeaconToAndCall(beacon, "");
        iBeacon = beacon;
    }

    /// @inheritdoc Proxy
    function _implementation() internal view virtual override returns (address) {
        return IBeacon(iBeacon).implementation();
    }
}
