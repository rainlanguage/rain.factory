// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {LibICloneableFactoryV5} from "../../../src/lib/LibICloneableFactoryV5.sol";
import {
    ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN,
    ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN
} from "../../../src/interface/deprecated/ICloneableFactoryV4.sol";

/// @title LibICloneableFactoryV5Test
/// Every expectation is recomputed inline from the pinned formula, never read
/// back from the library, so a change to the library's derivation diverges from
/// the oracle here and the test fails.
contract LibICloneableFactoryV5Test is Test {
    /// The domain tags the library derives against are exactly the two pinned
    /// string hashes. Recomputed from the literal strings so this is independent
    /// of the imported constants.
    function testDomainTagsPinned() external pure {
        assertEq(ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN, keccak256("rain.factory.clone.namespaced"));
        assertEq(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, keccak256("rain.factory.clone.opensalt"));
    }

    /// `effectiveSalt` is the namespaced formula byte for byte.
    function testEffectiveSaltMatchesFormula(address deployer, bytes32 salt) external pure {
        assertEq(
            LibICloneableFactoryV5.effectiveSalt(deployer, salt),
            keccak256(abi.encode(ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN, deployer, salt))
        );
    }

    /// `effectiveOpenSalt` is the open-salt formula byte for byte, across data
    /// lengths.
    function testEffectiveOpenSaltMatchesFormula(bytes32 salt, bytes memory data) external pure {
        assertEq(
            LibICloneableFactoryV5.effectiveOpenSalt(salt, data),
            keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data)))
        );
    }

    /// Empty `data` is a supported, distinct case: the derivation hashes
    /// `keccak256("")`, not the empty bytes inline.
    function testEffectiveOpenSaltEmptyData(bytes32 salt) external pure {
        assertEq(
            LibICloneableFactoryV5.effectiveOpenSalt(salt, ""),
            keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256("")))
        );
    }

    /// The two derivations use distinct fixed tags in word 0 — the whole of the
    /// disjointness-by-construction guarantee.
    function testDomainTagsDistinct() external pure {
        assertNotEq(ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN, ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN);
    }

    /// No namespaced `(deployer, salt)` input collides with any open-salt
    /// `(salt, data)` input. Fuzzed over both input spaces at once, including
    /// empty and non-empty data.
    function testDerivationsDisjoint(address deployer, bytes32 namespacedSalt, bytes32 openSalt, bytes memory data)
        external
        pure
    {
        assertNotEq(
            LibICloneableFactoryV5.effectiveSalt(deployer, namespacedSalt),
            LibICloneableFactoryV5.effectiveOpenSalt(openSalt, data)
        );
    }

    /// The namespaced preimage is 96 bytes whose FIRST word is the
    /// string-derived namespaced tag. Packed independently of both the library
    /// and the interface constant, so this also pins the constant to its
    /// documented string.
    function testEffectiveSaltPreimageShape(address deployer, bytes32 salt) external pure {
        bytes memory preimage =
            abi.encodePacked(keccak256("rain.factory.clone.namespaced"), bytes32(uint256(uint160(deployer))), salt);
        assertEq(preimage.length, 96);
        assertEq(LibICloneableFactoryV5.effectiveSalt(deployer, salt), keccak256(preimage));
    }

    /// The deployer is in the namespaced derivation: two deployers, two
    /// effective salts.
    function testEffectiveSaltDeployerSensitive(address alice, address bob, bytes32 salt) external pure {
        vm.assume(alice != bob);
        assertNotEq(LibICloneableFactoryV5.effectiveSalt(alice, salt), LibICloneableFactoryV5.effectiveSalt(bob, salt));
    }

    /// The caller salt is in the namespaced derivation: two salts, two
    /// effective salts.
    function testEffectiveSaltSaltSensitive(address deployer, bytes32 saltA, bytes32 saltB) external pure {
        vm.assume(saltA != saltB);
        assertNotEq(
            LibICloneableFactoryV5.effectiveSalt(deployer, saltA), LibICloneableFactoryV5.effectiveSalt(deployer, saltB)
        );
    }

    /// The open-salt preimage is 96 bytes whose FIRST word is the
    /// string-derived open-salt tag, whose second is the caller salt and whose
    /// third is `keccak256(data)` — `data` enters by hash, so the preimage is
    /// fixed length for any data length. Packed independently of both the
    /// library and the interface constant.
    function testEffectiveOpenSaltPreimageShape(bytes32 salt, bytes memory data) external pure {
        bytes memory preimage = abi.encodePacked(keccak256("rain.factory.clone.opensalt"), salt, keccak256(data));
        assertEq(preimage.length, 96);
        assertEq(LibICloneableFactoryV5.effectiveOpenSalt(salt, data), keccak256(preimage));
    }

    /// `data` is in the open-salt derivation: two data, two effective salts.
    function testEffectiveOpenSaltDataSensitive(bytes32 salt, bytes memory dataA, bytes memory dataB) external pure {
        vm.assume(keccak256(dataA) != keccak256(dataB));
        assertNotEq(
            LibICloneableFactoryV5.effectiveOpenSalt(salt, dataA), LibICloneableFactoryV5.effectiveOpenSalt(salt, dataB)
        );
    }

    /// The caller salt is in the open-salt derivation: two salts, two
    /// effective salts.
    function testEffectiveOpenSaltSaltSensitive(bytes32 saltA, bytes32 saltB, bytes memory data) external pure {
        vm.assume(saltA != saltB);
        assertNotEq(
            LibICloneableFactoryV5.effectiveOpenSalt(saltA, data), LibICloneableFactoryV5.effectiveOpenSalt(saltB, data)
        );
    }

    /// `effectiveSalt` at salt `0` and `max` is the formula.
    function testEffectiveSaltBoundarySalts(address deployer) external pure {
        assertEq(
            LibICloneableFactoryV5.effectiveSalt(deployer, bytes32(0)),
            keccak256(abi.encode(ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN, deployer, bytes32(0)))
        );
        assertEq(
            LibICloneableFactoryV5.effectiveSalt(deployer, bytes32(type(uint256).max)),
            keccak256(abi.encode(ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN, deployer, bytes32(type(uint256).max)))
        );
    }

    /// `effectiveSalt` at deployer `0` and `max` is the formula.
    function testEffectiveSaltBoundaryDeployers(bytes32 salt) external pure {
        assertEq(
            LibICloneableFactoryV5.effectiveSalt(address(0), salt),
            keccak256(abi.encode(ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN, address(0), salt))
        );
        assertEq(
            LibICloneableFactoryV5.effectiveSalt(address(type(uint160).max), salt),
            keccak256(abi.encode(ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN, address(type(uint160).max), salt))
        );
    }

    /// `effectiveOpenSalt` over 1, 32, 33 and 2048 bytes of `data` is the formula.
    function testEffectiveOpenSaltBoundaryDataLengths(bytes32 salt, bytes32 word, bytes1 tailByte) external pure {
        bytes memory oneByte = abi.encodePacked(tailByte);
        bytes memory oneWord = abi.encodePacked(word);
        bytes memory oneWordPlusOne = abi.encodePacked(word, tailByte);
        bytes memory manyWords = new bytes(0);
        for (uint256 i = 0; i < 64; i++) {
            manyWords = abi.encodePacked(manyWords, word);
        }

        assertEq(
            LibICloneableFactoryV5.effectiveOpenSalt(salt, oneByte),
            keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(oneByte)))
        );
        assertEq(
            LibICloneableFactoryV5.effectiveOpenSalt(salt, oneWord),
            keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(oneWord)))
        );
        assertEq(
            LibICloneableFactoryV5.effectiveOpenSalt(salt, oneWordPlusOne),
            keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(oneWordPlusOne)))
        );
        assertEq(
            LibICloneableFactoryV5.effectiveOpenSalt(salt, manyWords),
            keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(manyWords)))
        );
    }

    /// `effectiveOpenSalt` at salt `0` and `max` is the formula.
    function testEffectiveOpenSaltBoundarySalts(bytes memory data) external pure {
        assertEq(
            LibICloneableFactoryV5.effectiveOpenSalt(bytes32(0), data),
            keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, bytes32(0), keccak256(data)))
        );
        assertEq(
            LibICloneableFactoryV5.effectiveOpenSalt(bytes32(type(uint256).max), data),
            keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, bytes32(type(uint256).max), keccak256(data)))
        );
    }
}
