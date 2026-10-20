// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "../interface/ICloneableV2.sol";
import {ICloneableFactoryV3} from "../interface/deprecated/ICloneableFactoryV3.sol";
import {
    ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN,
    ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN
} from "../interface/deprecated/ICloneableFactoryV4.sol";

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

/// @title LibICloneableFactoryV4
/// @notice `ICloneableFactoryV4` as internal library logic.
library LibICloneableFactoryV4 {
    function effectiveSalt(address deployer, bytes32 salt) internal pure returns (bytes32) {
        return keccak256(abi.encode(ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN, deployer, salt));
    }

    function effectiveOpenSalt(bytes32 salt, bytes memory data) internal pure returns (bytes32) {
        return hashDomainSaltData(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, data);
    }

    /// `keccak256(abi.encode(domain, salt, keccak256(data)))`, the open-salt
    /// preimage shape every domain tag shares.
    function hashDomainSaltData(bytes32 domain, bytes32 salt, bytes memory data) internal pure returns (bytes32) {
        bytes32 dataHash = keccak256(data);
        bytes32 hashed;
        // The three-word preimage, in unallocated memory past the free pointer.
        assembly ("memory-safe") {
            let preimage := mload(0x40)
            mstore(preimage, domain)
            mstore(add(preimage, 0x20), salt)
            mstore(add(preimage, 0x40), dataHash)
            hashed := keccak256(preimage, 0x60)
        }
        return hashed;
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
    function predictCreate2Address(address factory, bytes32 derivedSalt, bytes32 initCodeHash)
        internal
        pure
        returns (address)
    {
        return address(uint160(uint256(keccak256(abi.encodePacked(hex"ff", factory, derivedSalt, initCodeHash)))));
    }

    function checkImplementationCode(address implementation) internal view {
        if (implementation.code.length == 0) {
            revert ZeroImplementationCodeSize();
        }
        uint256 firstByte;
        assembly ("memory-safe") {
            extcodecopy(implementation, 0, 0, 1)
            firstByte := byte(0, mload(0))
        }
        if (firstByte == 0xef) {
            revert DelegatedImplementation();
        }
    }

    /// `checkImplementationCode`, then `deployAndInitialize` with the EIP-1167
    /// creation code.
    function cloneAndInitialize(address implementation, bytes32 derivedSalt, bytes memory data, bytes32 salt)
        internal
        returns (address)
    {
        checkImplementationCode(implementation);
        return deployAndInitialize(cloneCreationCode(implementation), implementation, derivedSalt, data, salt);
    }

    /// Emits `NewClone` with the raw caller `salt`, not `derivedSalt`, and the
    /// unchecked `implementation` (the beacon, for V5): callers check it first.
    /// `creationCode` MUST NOT call its delegation target while constructing.
    function deployAndInitialize(
        bytes memory creationCode,
        address implementation,
        bytes32 derivedSalt,
        bytes memory data,
        bytes32 salt
    ) internal returns (address) {
        address child = predictCreate2Address(address(this), derivedSalt, keccak256(creationCode));
        if (child.code.length != 0) {
            revert CloneAddressOccupied(child);
        }
        // A successful `CREATE2` deploys at exactly `child`.
        bool deployed;
        assembly ("memory-safe") {
            deployed := iszero(iszero(create2(0, add(creationCode, 0x20), mload(creationCode), derivedSalt)))
        }
        if (!deployed) {
            revert CloneDeploymentFailed();
        }
        emit ICloneableFactoryV3.NewClone(msg.sender, implementation, child, salt, data);
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
        return child;
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
}
