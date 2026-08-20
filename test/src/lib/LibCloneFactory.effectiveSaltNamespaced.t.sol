// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {
    ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN,
    ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN
} from "src/interface/ICloneableFactoryV4.sol";
import {LibCloneFactory} from "src/lib/LibCloneFactory.sol";

/// @title LibCloneFactoryEffectiveSaltNamespacedTest
/// @notice Tests `LibCloneFactory.effectiveSaltNamespaced` against the
/// derivation `ICloneableFactoryV4` pins to exact bytes:
/// `keccak256(abi.encode(ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN, msg.sender, salt))`.
/// The expected values are restated from the interface NatSpec, not read back
/// from the library, so any drift in the library's arithmetic fails here.
contract LibCloneFactoryEffectiveSaltNamespacedTest is Test {
    /// The derivation is exactly the spec equation.
    function testEffectiveSaltNamespacedIsSpecEquation(address deployer, bytes32 salt) external pure {
        assertEq(
            LibCloneFactory.effectiveSaltNamespaced(deployer, salt),
            keccak256(abi.encode(ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN, deployer, salt))
        );
    }

    /// The preimage is 96 bytes whose FIRST word is the string-derived
    /// namespaced tag. Packed independently of both the library and the
    /// interface constant, so this also pins the constant to its documented
    /// string.
    function testEffectiveSaltNamespacedPreimageShape(address deployer, bytes32 salt) external pure {
        bytes memory preimage =
            abi.encodePacked(keccak256("rain.factory.clone.namespaced"), bytes32(uint256(uint160(deployer))), salt);
        assertEq(preimage.length, 96);
        assertEq(LibCloneFactory.effectiveSaltNamespaced(deployer, salt), keccak256(preimage));
    }

    /// The deployer is in the derivation: two deployers, two salts.
    function testEffectiveSaltNamespacedDeployerSensitive(address alice, address bob, bytes32 salt) external pure {
        vm.assume(alice != bob);
        assertTrue(
            LibCloneFactory.effectiveSaltNamespaced(alice, salt) != LibCloneFactory.effectiveSaltNamespaced(bob, salt)
        );
    }

    /// The caller salt is in the derivation: two salts, two effective salts.
    function testEffectiveSaltNamespacedSaltSensitive(address deployer, bytes32 saltA, bytes32 saltB) external pure {
        vm.assume(saltA != saltB);
        assertTrue(
            LibCloneFactory.effectiveSaltNamespaced(deployer, saltA)
                != LibCloneFactory.effectiveSaltNamespaced(deployer, saltB)
        );
    }

    /// The two domain tags are distinct words, each pinned to its documented
    /// string. This is the anchor of the image disjointness: everything else
    /// about the two preimages is caller-chosen, the first word is not.
    function testDomainTagsDistinct() external pure {
        assertEq(ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN, keccak256("rain.factory.clone.namespaced"));
        assertEq(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, keccak256("rain.factory.clone.opensalt"));
        assertTrue(ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN != ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN);
    }

    /// The namespaced image is disjoint from the open-salt image under freely
    /// varying inputs on both sides: the first preimage word differs by
    /// construction, so equality of the hashes would be a keccak256 collision.
    function testEffectiveSaltNamespacedDisjointFromOpen(
        address deployer,
        bytes32 namespacedSalt,
        bytes memory data,
        bytes32 openSalt
    ) external pure {
        assertTrue(
            LibCloneFactory.effectiveSaltNamespaced(deployer, namespacedSalt)
                != LibCloneFactory.effectiveSaltOpen(data, openSalt)
        );
    }
}
