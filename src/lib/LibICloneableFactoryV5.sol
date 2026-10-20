// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ICLONEABLE_FACTORY_V5_BEACON_PROXY_OPEN_SALT_DOMAIN} from "../interface/ICloneableFactoryV5.sol";
import {BEACON_PROXY_CREATION_CODE} from "../generated/BeaconProxy.sol";
import {LibICloneableFactoryV4} from "./LibICloneableFactoryV4.sol";
import {IBeaconImplementation} from "../interface/IBeaconImplementation.sol";

/// The beacon has no code. Without this check its empty `implementation()`
/// answer fails the decode with no data, before `BeaconProxy` checks it.
error ZeroBeaconCodeSize();

/// Beacon code starts with `0xef` (EIP-7702 delegation): the EOA key, not the
/// beacon's code, would decide `implementation()`.
error DelegatedBeacon();

/// @title LibICloneableFactoryV5
/// @notice The `ICloneableFactoryV5` beacon-proxy derivation as internal
/// library logic, on `LibICloneableFactoryV4`'s deploy-and-initialize tail.
library LibICloneableFactoryV5 {
    /// The `CREATE2` salt of the open-salt beacon proxy for `(salt, data)`.
    /// @param salt The raw caller salt.
    /// @param data The `initialize` data.
    /// @return The derived `CREATE2` salt.
    function effectiveBeaconProxyOpenSalt(bytes32 salt, bytes memory data) internal pure returns (bytes32) {
        return
            LibICloneableFactoryV4.hashDomainSaltData(ICLONEABLE_FACTORY_V5_BEACON_PROXY_OPEN_SALT_DOMAIN, salt, data);
    }

    /// `BEACON_PROXY_CREATION_CODE` with `(beacon, "")` constructor arguments:
    /// empty data, so the constructor calls nothing on the implementation.
    /// @param beacon The proxy's beacon.
    /// @return The creation code.
    function beaconProxyCreationCode(address beacon) internal pure returns (bytes memory) {
        return bytes.concat(BEACON_PROXY_CREATION_CODE, abi.encode(beacon, bytes("")));
    }

    /// `CREATE2` address of the beacon proxy from `factory`, for an already
    /// derived salt.
    /// @param factory The deploying factory.
    /// @param beacon The proxy's beacon.
    /// @param derivedSalt The domain-tagged `CREATE2` salt, not the caller salt.
    /// @return The predicted proxy address.
    function predictBeaconProxyAddress(address factory, address beacon, bytes32 derivedSalt)
        internal
        pure
        returns (address)
    {
        return LibICloneableFactoryV4.predictCreate2Address(
            factory, derivedSalt, keccak256(beaconProxyCreationCode(beacon))
        );
    }

    /// Rejects a codeless or EIP-7702 delegated beacon, then
    /// `checkImplementationCode` on its `implementation()`. Bubbles a reverting
    /// `implementation()`; a short or non-address answer reverts with no data.
    /// @param beacon The beacon to check.
    function checkBeacon(address beacon) internal view {
        if (beacon.code.length == 0) {
            revert ZeroBeaconCodeSize();
        }
        uint256 firstByte;
        assembly ("memory-safe") {
            extcodecopy(beacon, 0, 0, 1)
            firstByte := byte(0, mload(0))
        }
        if (firstByte == 0xef) {
            revert DelegatedBeacon();
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
    /// @param beacon The proxy's beacon.
    /// @param data The `initialize` data.
    /// @param salt The raw caller salt.
    /// @return The deployed proxy address.
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
    /// @param beacon The proxy's beacon.
    /// @param data The `initialize` data.
    /// @param salt The raw caller salt.
    /// @return The predicted proxy address.
    function predictBeaconProxyAddressOpenSalt(address beacon, bytes memory data, bytes32 salt)
        internal
        view
        returns (address)
    {
        return predictBeaconProxyAddress(address(this), beacon, effectiveBeaconProxyOpenSalt(salt, data));
    }
}
