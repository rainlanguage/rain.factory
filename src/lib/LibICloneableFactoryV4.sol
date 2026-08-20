// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "../interface/ICloneableV2.sol";
import {ICloneableFactoryV3} from "../interface/ICloneableFactoryV3.sol";
import {
    ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN,
    ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN
} from "../interface/ICloneableFactoryV4.sol";

/// Thrown when an implementation has zero code size which is always a mistake:
/// an EIP-1167 proxy of a codeless implementation delegates every call —
/// `initialize` included — to nothing.
error ZeroImplementationCodeSize();

/// Thrown when the `CREATE2` deploy of the clone itself fails. With the tiny
/// fixed EIP-1167 initcode the only realistic cause is that the effective salt
/// is already taken: the exact clone asked for is already at the address, so
/// the caller can never mistake an already-initialized contract for their own
/// fresh deploy.
error CloneDeploymentFailed();

/// Thrown when initialization fails: `ICloneableV2.initialize` on the fresh
/// clone returned something other than `ICLONEABLE_V2_SUCCESS`.
error InitializationFailed();

/// @dev The EIP-1167 creation code up to the implementation address: the
/// 10-byte deploy preamble (which returns the trailing 45 bytes as runtime
/// code) followed by the first 10 bytes of the runtime.
bytes constant EIP1167_CREATION_CODE_PREFIX = hex"3d602d80600a3d3981f3363d3d373d3d3d363d73";

/// @dev The EIP-1167 bytes after the implementation address, shared by the
/// creation code and the runtime code.
bytes constant EIP1167_CREATION_CODE_SUFFIX = hex"5af43d82803e903d91602b57fd5bf3";

/// @title LibICloneableFactoryV4
/// @notice The whole of an `ICloneableFactoryV4` factory as internal library
/// logic, so a concrete factory is nothing but one delegation per entry point.
/// This is the library half of the library/deploy split
/// (rainlanguage/rain.factory#46): the derivations, guards and the
/// clone-initialize-verify flow live here, unit tested; the deploy half's
/// concrete `CloneFactory` adds no behaviour of its own.
///
/// The library opens with the executable form of the two
/// effective-`CREATE2`-salt derivations that `ICloneableFactoryV4` pins to
/// exact bytes, so a factory, an indexer or a consumer predicting a clone
/// address computes them from one place instead of re-deriving the formulas
/// inline. Each function reproduces its interface formula byte for byte and
/// reads its domain tag from the interface, so the tags have a single source of
/// truth and the derivation cannot drift from the spec. The entry points below
/// them consume the derivations from here and nowhere else. See
/// `ICloneableFactoryV4` for what each salt commits to and why the two images
/// are disjoint — its NatSpec, with the atomic clone-and-initialize and the
/// `NewClone` event carrying the RAW caller salt, is the spec for everything
/// here.
///
/// `msg.sender` is read INSIDE this library — `cloneDeterministic` namespaces
/// by it and `NewClone` reports it — and the internal functions execute in the
/// factory's own call context, so a delegating concrete cannot get either
/// wrong: there is no sender parameter to misroute `tx.origin` into. Likewise
/// the predictions read `address(this)`, the factory the library is inlined
/// into.
library LibICloneableFactoryV4 {
    /// The effective `CREATE2` salt for the namespaced derivation
    /// (`cloneDeterministic` / `predictDeterministicAddress`): the caller-chosen
    /// `salt` behind the namespaced domain tag and `deployer`, so the salt — and
    /// therefore the clone address — is namespaced to the account that deploys.
    /// @param deployer The account whose namespace the salt belongs to (the
    /// `msg.sender` of `cloneDeterministic`, or the `deployer` argument of
    /// `predictDeterministicAddress`).
    /// @param salt The caller-chosen salt, before namespacing.
    /// @return The effective salt `CREATE2` hashes.
    function effectiveSalt(address deployer, bytes32 salt) internal pure returns (bytes32) {
        return keccak256(abi.encode(ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN, deployer, salt));
    }

    /// The effective `CREATE2` salt for the open-salt derivation
    /// (`cloneDeterministicOpenSalt` / `predictDeterministicAddressOpenSalt`):
    /// the caller-chosen `salt` and the hash of the initialization `data` behind
    /// the open-salt domain tag, and nothing about the caller, so the clone
    /// address commits to `salt` and `data` and every account reaches the same
    /// one. `data` MAY be empty.
    /// @param salt The caller-chosen salt.
    /// @param data The initialization data passed to `ICloneableV2.initialize`.
    /// @return The effective salt `CREATE2` hashes.
    function effectiveOpenSalt(bytes32 salt, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data)));
    }

    /// The canonical 55-byte EIP-1167 creation code for `implementation`.
    /// Constructed from the standard's bytes directly so this library — and
    /// with it the published factory — depends on no external cloning code;
    /// the tests pin it byte for byte against OZ `Clones` as a foreign
    /// implementation of the same standard.
    /// @param implementation The contract the deployed proxy will delegate to.
    /// @return The creation code.
    function cloneCreationCode(address implementation) internal pure returns (bytes memory) {
        return abi.encodePacked(EIP1167_CREATION_CODE_PREFIX, implementation, EIP1167_CREATION_CODE_SUFFIX);
    }

    /// The address `CREATE2` gives the EIP-1167 clone of `implementation` from
    /// `factory` at `derivedSalt`:
    /// `address(keccak256(0xff ++ factory ++ derivedSalt ++ keccak256(creationCode)))`.
    /// A pure function of its inputs, computable by anyone offchain.
    /// @param factory The factory that would deploy the clone.
    /// @param implementation The contract to clone.
    /// @param derivedSalt The effective `CREATE2` salt, from `effectiveSalt` or
    /// `effectiveOpenSalt`.
    /// @return The predicted clone address.
    function predictCloneAddress(address factory, address implementation, bytes32 derivedSalt)
        internal
        pure
        returns (address)
    {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(hex"ff", factory, derivedSalt, keccak256(cloneCreationCode(implementation)))
                    )
                )
            )
        );
    }

    /// Reverts with `ZeroImplementationCodeSize` if `implementation` has no
    /// code. Always a mistake: the clone would delegate every call to nothing.
    /// @param implementation The contract to clone.
    function checkImplementationCode(address implementation) internal view {
        if (implementation.code.length == 0) {
            revert ZeroImplementationCodeSize();
        }
    }

    /// The shared tail of both clone entry points: guard the implementation,
    /// `CREATE2` the EIP-1167 clone at `derivedSalt`, emit `NewClone` with
    /// the RAW caller salt, then run the mandatory `ICloneableV2.initialize`
    /// check — atomically, with nothing else called on the proxy first, and
    /// the clone only considered created if `initialize` returns
    /// `ICLONEABLE_V2_SUCCESS`, per the shared spec on
    /// `ICloneableFactoryV3.cloneDeterministic`.
    /// @param implementation The contract to clone.
    /// @param derivedSalt The effective `CREATE2` salt, from `effectiveSalt` or
    /// `effectiveOpenSalt`.
    /// @param data The initialization data, forwarded verbatim to
    /// `ICloneableV2.initialize`.
    /// @param salt The caller-chosen salt, emitted raw in `NewClone`.
    /// @return The deployed and initialized child contract address.
    function cloneAndInitialize(address implementation, bytes32 derivedSalt, bytes memory data, bytes32 salt)
        internal
        returns (address)
    {
        checkImplementationCode(implementation);
        bytes memory creationCode = cloneCreationCode(implementation);
        address child;
        assembly ("memory-safe") {
            child := create2(0, add(creationCode, 0x20), mload(creationCode), derivedSalt)
        }
        if (child == address(0)) {
            revert CloneDeploymentFailed();
        }
        emit ICloneableFactoryV3.NewClone(msg.sender, implementation, child, salt, data);
        // Checking the return value of initialize is mandatory as per
        // ICloneableFactoryV3 and ICloneableFactoryV4.
        if (ICloneableV2(child).initialize(data) != ICLONEABLE_V2_SUCCESS) {
            revert InitializationFailed();
        }
        return child;
    }

    /// `ICloneableFactoryV3.cloneDeterministic`, whole: `effectiveSalt` over
    /// `msg.sender` — read here, not passed, so a delegating concrete cannot
    /// namespace by anything else — then the shared clone-initialize-verify
    /// flow.
    /// @param implementation The contract to clone.
    /// @param data As per `ICloneableV2`.
    /// @param salt The caller-chosen salt.
    /// @return The deployed and initialized child contract address.
    function cloneDeterministic(address implementation, bytes memory data, bytes32 salt) internal returns (address) {
        return cloneAndInitialize(implementation, effectiveSalt(msg.sender, salt), data, salt);
    }

    /// `ICloneableFactoryV3.predictDeterministicAddress`, whole: the address
    /// `cloneDeterministic(implementation, _, salt)` deploys to when called by
    /// `deployer` on the factory this library is inlined into.
    /// @param implementation The contract to clone.
    /// @param salt The caller-chosen salt.
    /// @param deployer The account that will call `cloneDeterministic`.
    /// @return The predicted clone address.
    function predictDeterministicAddress(address implementation, bytes32 salt, address deployer)
        internal
        view
        returns (address)
    {
        return predictCloneAddress(address(this), implementation, effectiveSalt(deployer, salt));
    }

    /// `ICloneableFactoryV4.cloneDeterministicOpenSalt`, whole:
    /// `effectiveOpenSalt` — no caller-derived value hashed in — then the
    /// shared clone-initialize-verify flow.
    /// @param implementation The contract to clone.
    /// @param data As per `ICloneableV2`, and part of the address derivation.
    /// MAY be empty.
    /// @param salt The caller-chosen salt.
    /// @return The deployed and initialized child contract address.
    function cloneDeterministicOpenSalt(address implementation, bytes memory data, bytes32 salt)
        internal
        returns (address)
    {
        return cloneAndInitialize(implementation, effectiveOpenSalt(salt, data), data, salt);
    }

    /// `ICloneableFactoryV4.predictDeterministicAddressOpenSalt`, whole: the
    /// address `cloneDeterministicOpenSalt(implementation, data, salt)`
    /// deploys to from the factory this library is inlined into, whoever calls
    /// it.
    /// @param implementation The contract to clone.
    /// @param data The initialization data that will be passed to
    /// `ICloneableV2.initialize`.
    /// @param salt The caller-chosen salt.
    /// @return The predicted clone address.
    function predictDeterministicAddressOpenSalt(address implementation, bytes memory data, bytes32 salt)
        internal
        view
        returns (address)
    {
        return predictCloneAddress(address(this), implementation, effectiveOpenSalt(salt, data));
    }
}
