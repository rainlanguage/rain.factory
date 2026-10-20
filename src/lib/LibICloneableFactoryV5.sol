// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ICLONEABLE_FACTORY_V5_BEACON_PROXY_OPEN_SALT_DOMAIN} from "../interface/ICloneableFactoryV5.sol";
import {BEACON_PROXY_CREATION_CODE} from "../generated/BeaconProxy.sol";
import {LibICloneableFactoryV4} from "./LibICloneableFactoryV4.sol";

/// The beacon has no code. Without this check its empty `implementation()`
/// answer fails the decode with no data, before `BeaconProxy` checks it.
error ZeroBeaconCodeSize();

/// @title LibICloneableFactoryV5
/// @notice The `ICloneableFactoryV5` beacon-proxy derivation as internal
/// library logic, on `LibICloneableFactoryV4`'s deploy-and-initialize tail.
library LibICloneableFactoryV5 {
    /// The `CREATE2` salt of the open-salt beacon proxy for `(salt, data)`.
    function effectiveBeaconProxyOpenSalt(bytes32 salt, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encode(ICLONEABLE_FACTORY_V5_BEACON_PROXY_OPEN_SALT_DOMAIN, salt, keccak256(data)));
    }

    /// `BEACON_PROXY_CREATION_CODE` with `(beacon, "")` constructor arguments:
    /// empty data, so the constructor calls nothing on the implementation.
    function beaconProxyCreationCode(address beacon) internal pure returns (bytes memory) {
        return abi.encodePacked(BEACON_PROXY_CREATION_CODE, abi.encode(beacon, bytes("")));
    }

    /// `CREATE2` address of the beacon proxy from `factory`, for an already
    /// derived salt.
    function predictBeaconProxyAddress(address factory, address beacon, bytes32 derivedSalt)
        internal
        pure
        returns (address)
    {
        return LibICloneableFactoryV4.predictCreate2Address(
            factory, derivedSalt, keccak256(beaconProxyCreationCode(beacon))
        );
    }

    /// Bubbles a reverting `implementation()`; a short or non-address answer
    /// reverts with no data.
    function checkBeacon(address beacon) internal view {
        if (beacon.code.length == 0) {
            revert ZeroBeaconCodeSize();
        }
        // slither-disable-next-line low-level-calls
        (bool success, bytes memory returnData) = beacon.staticcall(abi.encodeWithSignature("implementation()"));
        if (!success) {
            assembly ("memory-safe") {
                revert(add(returnData, 0x20), mload(returnData))
            }
        }
        LibICloneableFactoryV4.checkImplementationCode(abi.decode(returnData, (address)));
    }

    /// `ICloneableFactoryV5.beaconProxyDeterministicOpenSalt`, from `address(this)`.
    function beaconProxyDeterministicOpenSalt(address beacon, bytes memory data, bytes32 salt)
        internal
        returns (address)
    {
        checkBeacon(beacon);
        return LibICloneableFactoryV4.deployAndInitialize(
            beaconProxyCreationCode(beacon), beacon, effectiveBeaconProxyOpenSalt(salt, data), data, salt
        );
    }

    /// `predictBeaconProxyAddress` from `address(this)`, for `(salt, data)`.
    function predictBeaconProxyAddressOpenSalt(address beacon, bytes memory data, bytes32 salt)
        internal
        view
        returns (address)
    {
        return predictBeaconProxyAddress(address(this), beacon, effectiveBeaconProxyOpenSalt(salt, data));
    }
}
