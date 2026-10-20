// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ICLONEABLE_FACTORY_V5_BEACON_PROXY_OPEN_SALT_DOMAIN} from "../interface/ICloneableFactoryV5.sol";
import {BEACON_PROXY_CREATION_CODE} from "../generated/BeaconProxy.sol";
import {LibICloneableFactoryV4} from "./LibICloneableFactoryV4.sol";

/// Thrown when a beacon has zero code size. `BeaconProxy`'s constructor
/// rejects such a beacon too, but `CREATE2` drops that revert's data.
error ZeroBeaconCodeSize();

/// @title LibICloneableFactoryV5
/// @notice The beacon-proxy derivation `ICloneableFactoryV5` adds, as internal
/// library logic beside `LibICloneableFactoryV4`, which carries the inherited
/// clone derivations and the shared deploy-and-initialize tail this reuses. A
/// concrete `ICloneableFactoryV5` delegates its V4 entry points to
/// `LibICloneableFactoryV4` and its V5 entry points here.
library LibICloneableFactoryV5 {
    /// The effective `CREATE2` salt for the beacon-proxy derivation: the
    /// caller-chosen `salt` and the hash of `data` behind the beacon-proxy
    /// domain tag, and nothing about the caller.
    /// @param salt The caller-chosen salt.
    /// @param data The initialization data passed to `ICloneableV2.initialize`.
    /// @return The effective salt `CREATE2` hashes.
    function effectiveBeaconProxyOpenSalt(bytes32 salt, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encode(ICLONEABLE_FACTORY_V5_BEACON_PROXY_OPEN_SALT_DOMAIN, salt, keccak256(data)));
    }

    /// The creation code of OpenZeppelin `BeaconProxy` constructed as
    /// `BeaconProxy(beacon, "")`: `BEACON_PROXY_CREATION_CODE` followed by its
    /// ABI-encoded constructor arguments. The data is empty so the constructor
    /// calls nothing on the implementation, leaving `initialize` to
    /// `LibICloneableFactoryV4.deployAndInitialize`.
    /// @param beacon The beacon the proxy resolves its implementation through.
    /// @return The creation code.
    function beaconProxyCreationCode(address beacon) internal pure returns (bytes memory) {
        return abi.encodePacked(BEACON_PROXY_CREATION_CODE, abi.encode(beacon, bytes("")));
    }

    /// The address `CREATE2` gives the beacon proxy for `beacon` from `factory`
    /// at `derivedSalt`.
    /// @param factory The factory that would deploy the proxy.
    /// @param beacon The beacon the proxy resolves its implementation through.
    /// @param derivedSalt The effective `CREATE2` salt.
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

    /// Reverts `ZeroBeaconCodeSize` if `beacon` has no code, bubbles a revert
    /// of `beacon.implementation()`, reverts with no data if it returns fewer
    /// than 32 bytes or a non-address, then applies
    /// `LibICloneableFactoryV4.checkImplementationCode` to the result.
    /// @param beacon The beacon to check.
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

    /// `ICloneableFactoryV5.beaconProxyDeterministicOpenSalt`, whole:
    /// `checkBeacon`, then the shared deploy-and-initialize tail at
    /// `effectiveBeaconProxyOpenSalt`, emitting `beacon` as `NewClone`'s
    /// `implementation`.
    /// @param beacon The beacon the proxy resolves its implementation through.
    /// @param data As per `ICloneableV2`, and part of the address derivation.
    /// @param salt The caller-chosen salt.
    /// @return The deployed and initialized proxy address.
    function beaconProxyDeterministicOpenSalt(address beacon, bytes memory data, bytes32 salt)
        internal
        returns (address)
    {
        checkBeacon(beacon);
        return LibICloneableFactoryV4.deployAndInitialize(
            beaconProxyCreationCode(beacon), beacon, effectiveBeaconProxyOpenSalt(salt, data), data, salt
        );
    }

    /// `ICloneableFactoryV5.predictBeaconProxyAddressOpenSalt`, whole.
    /// @param beacon The beacon the proxy resolves its implementation through.
    /// @param data The initialization data.
    /// @param salt The caller-chosen salt.
    /// @return The predicted proxy address.
    function predictBeaconProxyAddressOpenSalt(address beacon, bytes memory data, bytes32 salt)
        internal
        view
        returns (address)
    {
        return predictBeaconProxyAddress(address(this), beacon, effectiveBeaconProxyOpenSalt(salt, data));
    }
}
