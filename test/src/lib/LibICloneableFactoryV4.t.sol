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
}
