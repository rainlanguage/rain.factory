// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ICLONEABLE_FACTORY_V5_BEACON_PROXY_OPEN_SALT_DOMAIN} from "../interface/ICloneableFactoryV5.sol";
import {BEACON_PROXY_CREATION_CODE} from "../generated/BeaconProxy.sol";
import {LibICloneableFactoryV4} from "./LibICloneableFactoryV4.sol";

/// The beacon has no code. Without this check its empty `implementation()`
/// answer fails the decode with no data, before `BeaconProxy` checks it.
error ZeroBeaconCodeSize();

/// The OpenZeppelin `IBeacon` read, declared here as `src/` imports nothing
/// from outside this repo.
interface IBeaconImplementation {
    function implementation() external view returns (address);
}

/// @title LibICloneableFactoryV5
/// @notice The `ICloneableFactoryV5` beacon-proxy derivation as internal
/// library logic, on `LibICloneableFactoryV4`'s deploy-and-initialize tail.
library LibICloneableFactoryV5 {
    /// The `CREATE2` salt of the open-salt beacon proxy for `(salt, data)`.
    function effectiveBeaconProxyOpenSalt(bytes32 salt, bytes memory data) internal pure returns (bytes32) {
        bytes32 domain = ICLONEABLE_FACTORY_V5_BEACON_PROXY_OPEN_SALT_DOMAIN;
        bytes32 dataHash = keccak256(data);
        bytes32 effective;
        // The three-word preimage, in unallocated memory past the free pointer.
        assembly ("memory-safe") {
            let preimage := mload(0x40)
            mstore(preimage, domain)
            mstore(add(preimage, 0x20), salt)
            mstore(add(preimage, 0x40), dataHash)
            effective := keccak256(preimage, 0x60)
        }
        return effective;
    }

    /// `BEACON_PROXY_CREATION_CODE` with `(beacon, "")` constructor arguments:
    /// empty data, so the constructor calls nothing on the implementation.
    function beaconProxyCreationCode(address beacon) internal pure returns (bytes memory) {
        return bytes.concat(BEACON_PROXY_CREATION_CODE, abi.encode(beacon, bytes("")));
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
        // A malformed answer fails the decode outside the try, so the catch
        // only ever holds the beacon's own revert.
        try IBeaconImplementation(beacon).implementation() returns (address implementation) {
            LibICloneableFactoryV4.checkImplementationCode(implementation);
        } catch (bytes memory reason) {
            assembly ("memory-safe") {
                revert(add(reason, 0x20), mload(reason))
            }
        }
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
