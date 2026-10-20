// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ICLONEABLE_FACTORY_V5_BEACON_PROXY_OPEN_SALT_DOMAIN} from "../interface/ICloneableFactoryV5.sol";
import {LibICloneableFactoryV4} from "./LibICloneableFactoryV4.sol";

/// Thrown when a beacon has zero code size: a beacon proxy of a codeless
/// beacon resolves every call — `initialize` included — to nothing.
error ZeroBeaconCodeSize();

/// @dev The beacon proxy creation code up to the beacon address in the
/// constructor: `PUSH20`.
bytes constant BEACON_PROXY_CREATION_CODE_PREFIX = hex"73";

/// @dev The beacon proxy creation code between the constructor's beacon and
/// the runtime's beacon. The constructor
/// `DUP1 PUSH32 <ERC-1967 beacon slot> SSTORE`,
/// `PUSH32 <BeaconUpgraded(address) topic> PUSH0 PUSH0 LOG2`, then returns the
/// 86-byte runtime at offset 0x65 with `PUSH1 0x56 DUP1 PUSH1 0x65 PUSH0
/// CODECOPY PUSH0 RETURN`. The runtime head stores the `implementation()`
/// selector at memory 0x1c and pushes the `STATICCALL` arguments up to the
/// beacon: `PUSH4 0x5c60da1b PUSH0 MSTORE PUSH1 0x20 PUSH0 PUSH1 0x04 PUSH1
/// 0x1c PUSH20`.
bytes constant BEACON_PROXY_CREATION_CODE_INFIX =
    hex"807fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50557f1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e5f5fa260568060655f395ff3635c60da1b5f5260205f6004601c73";

/// @dev The beacon proxy runtime after the beacon address, at runtime offset
/// 0x23:
///
/// ```
/// 23 GAS STATICCALL                       [s]
/// 25 DUP1 ISZERO PUSH1 0x43 JUMPI         [s]       beacon reverted: bubble
/// 2a PUSH0 MLOAD DUP1 PUSH1 0xa0 SHR      [hi w 1]
/// 30 PUSH1 0x20 RETURNDATASIZE LT OR      [bad w 1] short or not an address
/// 35 PUSH1 0x52 JUMPI                     [w 1]
/// 38 CALLDATASIZE PUSH0 PUSH0 CALLDATACOPY
/// 3c PUSH0 PUSH0 CALLDATASIZE PUSH0 DUP5 GAS DELEGATECALL  [s w 1]
/// 43 JUMPDEST RETURNDATASIZE PUSH0 PUSH0 RETURNDATACOPY    [s ...]
/// 48 PUSH1 0x4e JUMPI RETURNDATASIZE PUSH0 REVERT
/// 4e JUMPDEST RETURNDATASIZE PUSH0 RETURN
/// 52 JUMPDEST PUSH0 PUSH0 REVERT
/// ```
bytes constant BEACON_PROXY_RUNTIME_CODE_SUFFIX =
    hex"5afa80156043575f518060a01c60203d1017605257365f5f375f5f365f845af45b3d5f5f3e604e573d5ffd5b3d5ff35b5f5ffd";

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

    /// The 187-byte creation code of the minimal ERC-1967 beacon proxy for
    /// `beacon`: a 101-byte constructor and the 86-byte runtime, each embedding
    /// `beacon`.
    /// @param beacon The beacon the proxy resolves its implementation through.
    /// @return The creation code.
    function beaconProxyCreationCode(address beacon) internal pure returns (bytes memory) {
        return abi.encodePacked(
            BEACON_PROXY_CREATION_CODE_PREFIX,
            beacon,
            BEACON_PROXY_CREATION_CODE_INFIX,
            beacon,
            BEACON_PROXY_RUNTIME_CODE_SUFFIX
        );
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
