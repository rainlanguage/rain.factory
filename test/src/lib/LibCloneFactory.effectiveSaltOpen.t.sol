// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN} from "src/interface/ICloneableFactoryV4.sol";
import {LibCloneFactory} from "src/lib/LibCloneFactory.sol";

/// @title LibCloneFactoryEffectiveSaltOpenTest
/// @notice Tests `LibCloneFactory.effectiveSaltOpen` against the derivation
/// `ICloneableFactoryV4` pins to exact bytes:
/// `keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data)))`.
/// The expected values are restated from the interface NatSpec, not read back
/// from the library.
contract LibCloneFactoryEffectiveSaltOpenTest is Test {
    /// The derivation is exactly the spec equation.
    function testEffectiveSaltOpenIsSpecEquation(bytes memory data, bytes32 salt) external pure {
        assertEq(
            LibCloneFactory.effectiveSaltOpen(data, salt),
            keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data)))
        );
    }

    /// The preimage is 96 bytes whose FIRST word is the string-derived
    /// open-salt tag, whose second is the caller salt and whose third is
    /// `keccak256(data)` — `data` enters by hash, so the preimage is fixed
    /// length for any data length. Packed independently of both the library
    /// and the interface constant.
    function testEffectiveSaltOpenPreimageShape(bytes memory data, bytes32 salt) external pure {
        bytes memory preimage = abi.encodePacked(keccak256("rain.factory.clone.opensalt"), salt, keccak256(data));
        assertEq(preimage.length, 96);
        assertEq(LibCloneFactory.effectiveSaltOpen(data, salt), keccak256(preimage));
    }

    /// `data` is in the derivation: two data, two effective salts.
    function testEffectiveSaltOpenDataSensitive(bytes memory dataA, bytes memory dataB, bytes32 salt) external pure {
        vm.assume(keccak256(dataA) != keccak256(dataB));
        assertTrue(LibCloneFactory.effectiveSaltOpen(dataA, salt) != LibCloneFactory.effectiveSaltOpen(dataB, salt));
    }

    /// The caller salt is in the derivation: two salts, two effective salts.
    function testEffectiveSaltOpenSaltSensitive(bytes memory data, bytes32 saltA, bytes32 saltB) external pure {
        vm.assume(saltA != saltB);
        assertTrue(LibCloneFactory.effectiveSaltOpen(data, saltA) != LibCloneFactory.effectiveSaltOpen(data, saltB));
    }
}
