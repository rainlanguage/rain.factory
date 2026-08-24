// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibICloneableFactoryV4} from "src/lib/LibICloneableFactoryV4.sol";
import {
    ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN,
    ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN
} from "src/interface/ICloneableFactoryV4.sol";

/// @title LibICloneableFactoryV4Test
/// Every expectation is recomputed inline from the pinned formula, never read
/// back from the library, so a change to the library's derivation diverges from
/// the oracle here and the test fails.
contract LibICloneableFactoryV4Test is Test {
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
            LibICloneableFactoryV4.effectiveSalt(deployer, salt),
            keccak256(abi.encode(ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN, deployer, salt))
        );
    }

    /// `effectiveOpenSalt` is the open-salt formula byte for byte, across data
    /// lengths.
    function testEffectiveOpenSaltMatchesFormula(bytes32 salt, bytes memory data) external pure {
        assertEq(
            LibICloneableFactoryV4.effectiveOpenSalt(salt, data),
            keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data)))
        );
    }

    /// Empty `data` is a supported, distinct case: the derivation hashes
    /// `keccak256("")`, not the empty bytes inline.
    function testEffectiveOpenSaltEmptyData(bytes32 salt) external pure {
        assertEq(
            LibICloneableFactoryV4.effectiveOpenSalt(salt, ""),
            keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256("")))
        );
    }

    /// The two derivations use distinct fixed tags in word 0 — the whole of the
    /// disjointness-by-construction guarantee.
    function testDomainTagsDistinct() external pure {
        assertTrue(ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN != ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN);
    }

    /// No namespaced `(deployer, salt)` input collides with any open-salt
    /// `(salt, data)` input: the distinct word-0 tags make the preimages
    /// disjoint, so the images are too. Fuzzed over both input spaces at once,
    /// including empty and non-empty data.
    function testDerivationsDisjoint(address deployer, bytes32 namespacedSalt, bytes32 openSalt, bytes memory data)
        external
        pure
    {
        assertTrue(
            LibICloneableFactoryV4.effectiveSalt(deployer, namespacedSalt)
                != LibICloneableFactoryV4.effectiveOpenSalt(openSalt, data)
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
        assertEq(LibICloneableFactoryV4.effectiveSalt(deployer, salt), keccak256(preimage));
    }

    /// The deployer is in the namespaced derivation: two deployers, two
    /// effective salts.
    function testEffectiveSaltDeployerSensitive(address alice, address bob, bytes32 salt) external pure {
        vm.assume(alice != bob);
        assertTrue(LibICloneableFactoryV4.effectiveSalt(alice, salt) != LibICloneableFactoryV4.effectiveSalt(bob, salt));
    }

    /// The caller salt is in the namespaced derivation: two salts, two
    /// effective salts.
    function testEffectiveSaltSaltSensitive(address deployer, bytes32 saltA, bytes32 saltB) external pure {
        vm.assume(saltA != saltB);
        assertTrue(
            LibICloneableFactoryV4.effectiveSalt(deployer, saltA)
                != LibICloneableFactoryV4.effectiveSalt(deployer, saltB)
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
        assertEq(LibICloneableFactoryV4.effectiveOpenSalt(salt, data), keccak256(preimage));
    }

    /// `data` is in the open-salt derivation: two data, two effective salts.
    function testEffectiveOpenSaltDataSensitive(bytes32 salt, bytes memory dataA, bytes memory dataB) external pure {
        vm.assume(keccak256(dataA) != keccak256(dataB));
        assertTrue(
            LibICloneableFactoryV4.effectiveOpenSalt(salt, dataA)
                != LibICloneableFactoryV4.effectiveOpenSalt(salt, dataB)
        );
    }

    /// The caller salt is in the open-salt derivation: two salts, two
    /// effective salts.
    function testEffectiveOpenSaltSaltSensitive(bytes32 saltA, bytes32 saltB, bytes memory data) external pure {
        vm.assume(saltA != saltB);
        assertTrue(
            LibICloneableFactoryV4.effectiveOpenSalt(saltA, data)
                != LibICloneableFactoryV4.effectiveOpenSalt(saltB, data)
        );
    }

    /// Boundary salts are supported, distinct cases: `bytes32(0)` and
    /// `bytes32(type(uint256).max)` go through the derivation exactly as any
    /// other salt does, with no special-casing at either end. Pinned
    /// deliberately rather than left to the fuzzer, as
    /// `testEffectiveOpenSaltEmptyData` pins the empty-data boundary: a
    /// mutation special-casing the maximum salt survives the whole suite
    /// otherwise.
    function testEffectiveOpenSaltBoundarySalts(bytes memory data) external pure {
        assertEq(
            LibICloneableFactoryV4.effectiveOpenSalt(bytes32(0), data),
            keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, bytes32(0), keccak256(data)))
        );
        assertEq(
            LibICloneableFactoryV4.effectiveOpenSalt(bytes32(type(uint256).max), data),
            keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, bytes32(type(uint256).max), keccak256(data)))
        );
    }
}
