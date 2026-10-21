// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "../interface/ICloneableV2.sol";
import {
    ICloneableFactoryV5,
    ICLONEABLE_FACTORY_V5_BEACON_PROXY_OPEN_SALT_DOMAIN
} from "../interface/ICloneableFactoryV5.sol";
import {
    ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN,
    ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN
} from "../interface/deprecated/ICloneableFactoryV4.sol";
import {ICloneableFactoryV3} from "../interface/deprecated/ICloneableFactoryV3.sol";
import {BEACON_PROXY_CREATION_CODE} from "../generated/BeaconProxy.sol";
import {IBeaconImplementation} from "../interface/IBeaconImplementation.sol";

error ZeroImplementationCodeSize();

/// Implementation code starts with `0xef` (EIP-7702 delegation).
error DelegatedImplementation();

error CloneAddressOccupied(address clone);

error CloneDeploymentFailed();

/// `initialize` returned anything but `ICLONEABLE_V2_SUCCESS`.
error InitializationFailed();

/// @dev EIP-1167 creation code before the implementation address.
bytes constant EIP1167_CREATION_CODE_PREFIX = hex"3d602d80600a3d3981f3363d3d373d3d3d363d73";

/// @dev EIP-1167 creation code after the implementation address.
bytes constant EIP1167_CREATION_CODE_SUFFIX = hex"5af43d82803e903d91602b57fd5bf3";

/// The beacon has no code. Without this check its empty `implementation()`
/// answer fails the decode with no data, before `BeaconProxy` checks it.
error ZeroBeaconCodeSize();

/// Beacon code starts with `0xef` (EIP-7702 delegation): the EOA key, not the
/// beacon's code, would decide `implementation()`.
error DelegatedBeacon();

/// @title LibICloneableFactoryV5
/// @notice `ICloneableFactoryV5` as internal library logic.
library LibICloneableFactoryV5 {
    function effectiveSalt(address deployer, bytes32 salt) internal pure returns (bytes32) {
        return keccak256(abi.encode(ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN, deployer, salt));
    }

    function effectiveOpenSalt(bytes32 salt, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data)));
    }

    function cloneCreationCode(address implementation) internal pure returns (bytes memory) {
        return abi.encodePacked(EIP1167_CREATION_CODE_PREFIX, implementation, EIP1167_CREATION_CODE_SUFFIX);
    }

    function predictCloneAddress(address factory, address implementation, bytes32 derivedSalt)
        internal
        pure
        returns (address)
    {
        return predictCreate2Address(factory, derivedSalt, keccak256(cloneCreationCode(implementation)));
    }

    /// EIP-1014 address for `factory`, `derivedSalt` and `initCodeHash`.
    /// @param factory The deploying factory.
    /// @param derivedSalt The `CREATE2` salt.
    /// @param initCodeHash `keccak256` of the creation code.
    /// @return The predicted address.
    function predictCreate2Address(address factory, bytes32 derivedSalt, bytes32 initCodeHash)
        internal
        pure
        returns (address)
    {
        return address(uint160(uint256(keccak256(abi.encodePacked(hex"ff", factory, derivedSalt, initCodeHash)))));
    }

    /// Whether `account`'s code starts with `0xef`: an EIP-7702 delegation
    /// designator, as EIP-3541 bars deployed code from that byte.
    /// @param account The account to read.
    /// @return True when the first code byte is `0xef`.
    function isDelegated(address account) internal view returns (bool) {
        uint256 firstByte;
        assembly ("memory-safe") {
            extcodecopy(account, 0, 0, 1)
            firstByte := byte(0, mload(0))
        }
        return firstByte == 0xef;
    }

    function checkImplementationCode(address implementation) internal view {
        if (implementation.code.length == 0) {
            revert ZeroImplementationCodeSize();
        }
        if (isDelegated(implementation)) {
            revert DelegatedImplementation();
        }
    }

    /// `checkImplementationCode`, `deployChild` of the EIP-1167 creation code,
    /// `NewClone` with the raw caller `salt`, then `initializeChild`.
    function cloneAndInitialize(address implementation, bytes32 derivedSalt, bytes memory data, bytes32 salt)
        internal
        returns (address)
    {
        checkImplementationCode(implementation);
        address child = deployChild(cloneCreationCode(implementation), derivedSalt);
        emit ICloneableFactoryV3.NewClone(msg.sender, implementation, child, salt, data);
        initializeChild(child, data);
        return child;
    }

    /// `CREATE2` of `creationCode` from `address(this)`, reverting if the
    /// address already has code. `creationCode` MUST NOT call its delegation
    /// target while constructing.
    /// @param creationCode The child's creation code.
    /// @param derivedSalt The `CREATE2` salt.
    /// @return The deployed child address.
    function deployChild(bytes memory creationCode, bytes32 derivedSalt) internal returns (address) {
        address predicted = predictCreate2Address(address(this), derivedSalt, keccak256(creationCode));
        if (predicted.code.length != 0) {
            revert CloneAddressOccupied(predicted);
        }
        address child;
        assembly ("memory-safe") {
            child := create2(0, add(creationCode, 0x20), mload(creationCode), derivedSalt)
        }
        if (child == address(0)) {
            revert CloneDeploymentFailed();
        }
        return child;
    }

    /// Calls `initialize(data)` on `child`, bubbling a revert that has data;
    /// anything but `ICLONEABLE_V2_SUCCESS` is `InitializationFailed`.
    /// @param child The deployed child.
    /// @param data The `initialize` data.
    function initializeChild(address child, bytes memory data) internal {
        // slither-disable-next-line low-level-calls
        (bool success, bytes memory returnData) = child.call(abi.encodeCall(ICloneableV2.initialize, (data)));
        if (!success && returnData.length > 0) {
            assembly ("memory-safe") {
                revert(add(returnData, 0x20), mload(returnData))
            }
        }
        if (returnData.length != 32 || abi.decode(returnData, (bytes32)) != ICLONEABLE_V2_SUCCESS) {
            revert InitializationFailed();
        }
    }

    function cloneDeterministic(address implementation, bytes memory data, bytes32 salt) internal returns (address) {
        return cloneAndInitialize(implementation, effectiveSalt(msg.sender, salt), data, salt);
    }

    function predictDeterministicAddress(address implementation, bytes32 salt, address deployer)
        internal
        view
        returns (address)
    {
        return predictCloneAddress(address(this), implementation, effectiveSalt(deployer, salt));
    }

    function cloneDeterministicOpenSalt(address implementation, bytes memory data, bytes32 salt)
        internal
        returns (address)
    {
        return cloneAndInitialize(implementation, effectiveOpenSalt(salt, data), data, salt);
    }

    function predictDeterministicAddressOpenSalt(address implementation, bytes memory data, bytes32 salt)
        internal
        view
        returns (address)
    {
        return predictCloneAddress(address(this), implementation, effectiveOpenSalt(salt, data));
    }

    /// The `CREATE2` salt of the open-salt beacon proxy for `(salt, data)`.
    /// @param salt The raw caller salt.
    /// @param data The `initialize` data.
    /// @return The derived `CREATE2` salt.
    function effectiveBeaconProxyOpenSalt(bytes32 salt, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encode(ICLONEABLE_FACTORY_V5_BEACON_PROXY_OPEN_SALT_DOMAIN, salt, keccak256(data)));
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
        return predictCreate2Address(factory, derivedSalt, keccak256(beaconProxyCreationCode(beacon)));
    }

    /// Rejects a codeless or EIP-7702 delegated beacon, then
    /// `checkImplementationCode` on its `implementation()`. Bubbles a reverting
    /// `implementation()`; a short or non-address answer reverts with no data.
    /// @param beacon The beacon to check.
    function checkBeacon(address beacon) internal view {
        if (beacon.code.length == 0) {
            revert ZeroBeaconCodeSize();
        }
        if (isDelegated(beacon)) {
            revert DelegatedBeacon();
        }
        // slither-disable-next-line low-level-calls
        (bool success, bytes memory returnData) =
            beacon.staticcall(abi.encodeCall(IBeaconImplementation.implementation, ()));
        if (!success) {
            assembly ("memory-safe") {
                revert(add(returnData, 0x20), mload(returnData))
            }
        }
        checkImplementationCode(abi.decode(returnData, (address)));
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
        address proxy = deployChild(beaconProxyCreationCode(beacon), effectiveBeaconProxyOpenSalt(salt, data));
        emit ICloneableFactoryV5.NewBeaconProxy(msg.sender, beacon, proxy, salt, data);
        initializeChild(proxy, data);
        return proxy;
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
