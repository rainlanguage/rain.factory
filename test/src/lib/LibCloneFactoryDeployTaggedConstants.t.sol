// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibRainDeploy} from "rain-deploy-0.1.3/src/lib/LibRainDeploy.sol";
import {CloneFactory} from "../../../src/concrete/CloneFactory.sol";
import {TestCloneable} from "../concrete/TestCloneable.sol";
import {
    BYTECODE_HASH as CLONE_FACTORY_BYTECODE_HASH_0_1_3,
    DEPLOYED_ADDRESS as CLONE_FACTORY_DEPLOYED_ADDRESS_0_1_3,
    CREATION_CODE as CLONE_FACTORY_CREATION_CODE_0_1_3,
    RUNTIME_CODE as CLONE_FACTORY_RUNTIME_CODE_0_1_3
} from "../../../src/generated/0_1_3/CloneFactory.pointers.sol";
import {
    BYTECODE_HASH as CLONE_FACTORY_BYTECODE_HASH_0_1_4,
    DEPLOYED_ADDRESS as CLONE_FACTORY_DEPLOYED_ADDRESS_0_1_4,
    CREATION_CODE as CLONE_FACTORY_CREATION_CODE_0_1_4,
    RUNTIME_CODE as CLONE_FACTORY_RUNTIME_CODE_0_1_4
} from "../../../src/generated/0_1_4/CloneFactory.pointers.sol";
import {
    BYTECODE_HASH as CLONE_FACTORY_BYTECODE_HASH_0_1_5,
    DEPLOYED_ADDRESS as CLONE_FACTORY_DEPLOYED_ADDRESS_0_1_5,
    CREATION_CODE as CLONE_FACTORY_CREATION_CODE_0_1_5,
    RUNTIME_CODE as CLONE_FACTORY_RUNTIME_CODE_0_1_5
} from "../../../src/generated/0_1_5/CloneFactory.pointers.sol";
import {
    BYTECODE_HASH as CLONE_FACTORY_BYTECODE_HASH_0_1_6,
    DEPLOYED_ADDRESS as CLONE_FACTORY_DEPLOYED_ADDRESS_0_1_6,
    CREATION_CODE as CLONE_FACTORY_CREATION_CODE_0_1_6,
    RUNTIME_CODE as CLONE_FACTORY_RUNTIME_CODE_0_1_6
} from "../../../src/generated/0_1_6/CloneFactory.pointers.sol";

/// @title LibCloneFactoryDeployTaggedConstantsTest
/// @notice Each frozen per-tag `CloneFactory` snapshot must be self-consistent
/// and reproducible: its recorded `BYTECODE_HASH` is the keccak of its recorded
/// `RUNTIME_CODE`, and Zoltu-deploying its recorded `CREATION_CODE` lands at the
/// recorded `DEPLOYED_ADDRESS` with the recorded codehash. A new release adds a
/// tag import + a test pair here.
contract LibCloneFactoryDeployTaggedConstantsTest is Test {
    /// `keccak256(RUNTIME_CODE) == BYTECODE_HASH` for the tag — the pin is
    /// internally consistent.
    function testCloneFactory_0_1_3_RuntimeHashesToBytecodeHash() external pure {
        assertEq(keccak256(CLONE_FACTORY_RUNTIME_CODE_0_1_3), CLONE_FACTORY_BYTECODE_HASH_0_1_3);
    }

    /// Deploying the frozen `CREATION_CODE` via the Zoltu factory lands at the
    /// recorded `DEPLOYED_ADDRESS` with the recorded codehash — the snapshot
    /// reproduces its own deployment.
    function testCloneFactory_0_1_3_CreationDeploysToPinnedAddress() external {
        LibRainDeploy.etchZoltuFactory(vm);
        address deployed = LibRainDeploy.deployZoltu(CLONE_FACTORY_CREATION_CODE_0_1_3);
        assertEq(deployed, CLONE_FACTORY_DEPLOYED_ADDRESS_0_1_3);
        assertEq(deployed.codehash, CLONE_FACTORY_BYTECODE_HASH_0_1_3);
        assertEq(keccak256(deployed.code), CLONE_FACTORY_BYTECODE_HASH_0_1_3);
    }

    /// `keccak256(RUNTIME_CODE) == BYTECODE_HASH` for the tag — the pin is
    /// internally consistent.
    function testCloneFactory_0_1_4_RuntimeHashesToBytecodeHash() external pure {
        assertEq(keccak256(CLONE_FACTORY_RUNTIME_CODE_0_1_4), CLONE_FACTORY_BYTECODE_HASH_0_1_4);
    }

    /// Deploying the frozen `CREATION_CODE` via the Zoltu factory lands at the
    /// recorded `DEPLOYED_ADDRESS` with the recorded codehash — the snapshot
    /// reproduces its own deployment.
    function testCloneFactory_0_1_4_CreationDeploysToPinnedAddress() external {
        LibRainDeploy.etchZoltuFactory(vm);
        address deployed = LibRainDeploy.deployZoltu(CLONE_FACTORY_CREATION_CODE_0_1_4);
        assertEq(deployed, CLONE_FACTORY_DEPLOYED_ADDRESS_0_1_4);
        assertEq(deployed.codehash, CLONE_FACTORY_BYTECODE_HASH_0_1_4);
        assertEq(keccak256(deployed.code), CLONE_FACTORY_BYTECODE_HASH_0_1_4);
    }

    /// `keccak256(RUNTIME_CODE) == BYTECODE_HASH` for the tag — the pin is
    /// internally consistent.
    function testCloneFactory_0_1_5_RuntimeHashesToBytecodeHash() external pure {
        assertEq(keccak256(CLONE_FACTORY_RUNTIME_CODE_0_1_5), CLONE_FACTORY_BYTECODE_HASH_0_1_5);
    }

    /// Deploying the frozen `CREATION_CODE` via the Zoltu factory lands at the
    /// recorded `DEPLOYED_ADDRESS` with the recorded codehash — the snapshot
    /// reproduces its own deployment.
    function testCloneFactory_0_1_5_CreationDeploysToPinnedAddress() external {
        LibRainDeploy.etchZoltuFactory(vm);
        address deployed = LibRainDeploy.deployZoltu(CLONE_FACTORY_CREATION_CODE_0_1_5);
        assertEq(deployed, CLONE_FACTORY_DEPLOYED_ADDRESS_0_1_5);
        assertEq(deployed.codehash, CLONE_FACTORY_BYTECODE_HASH_0_1_5);
        assertEq(keccak256(deployed.code), CLONE_FACTORY_BYTECODE_HASH_0_1_5);
    }

    /// `keccak256(RUNTIME_CODE) == BYTECODE_HASH` for the tag — the pin is
    /// internally consistent.
    function testCloneFactory_0_1_6_RuntimeHashesToBytecodeHash() external pure {
        assertEq(keccak256(CLONE_FACTORY_RUNTIME_CODE_0_1_6), CLONE_FACTORY_BYTECODE_HASH_0_1_6);
    }

    /// Deploying the frozen `CREATION_CODE` via the Zoltu factory lands at the
    /// recorded `DEPLOYED_ADDRESS` with the recorded codehash — the snapshot
    /// reproduces its own deployment.
    function testCloneFactory_0_1_6_CreationDeploysToPinnedAddress() external {
        LibRainDeploy.etchZoltuFactory(vm);
        address deployed = LibRainDeploy.deployZoltu(CLONE_FACTORY_CREATION_CODE_0_1_6);
        assertEq(deployed, CLONE_FACTORY_DEPLOYED_ADDRESS_0_1_6);
        assertEq(deployed.codehash, CLONE_FACTORY_BYTECODE_HASH_0_1_6);
        assertEq(keccak256(deployed.code), CLONE_FACTORY_BYTECODE_HASH_0_1_6);
    }

    /// The open-salt release's frozen bytecode must actually SERVE all four
    /// deterministic entry points, so the pin cannot record an address for
    /// bytecode that is missing one. Proved by deploying the frozen
    /// `CREATION_CODE` and calling every entry point on the result through the
    /// `ICloneableFactoryV4` ABI: an entry point the dispatcher does not expose
    /// falls through to the (absent) fallback and reverts here. A byte scan of
    /// the runtime code would NOT prove this — a selector can sit in constant
    /// data without being dispatchable.
    function testCloneFactory_0_1_6_DeployedBytecodeServesBothEntryPoints() external {
        LibRainDeploy.etchZoltuFactory(vm);
        CloneFactory factory = CloneFactory(LibRainDeploy.deployZoltu(CLONE_FACTORY_CREATION_CODE_0_1_6));
        TestCloneable implementation = new TestCloneable();

        bytes32 salt = keccak256("rain.factory.tagged.constants.entry.points");
        bytes memory data = hex"f100dedb0a75";

        address predictedNamespaced = factory.predictDeterministicAddress(address(implementation), salt, address(this));
        address predictedOpen = factory.predictDeterministicAddressOpenSalt(address(implementation), salt);
        assertTrue(predictedNamespaced != predictedOpen);

        address childNamespaced = factory.cloneDeterministic(address(implementation), data, salt);
        address childOpen = factory.cloneDeterministicOpenSalt(address(implementation), data, salt);

        assertEq(childNamespaced, predictedNamespaced);
        assertEq(childOpen, predictedOpen);
        assertEq(TestCloneable(childNamespaced).sData(), data);
        assertEq(TestCloneable(childOpen).sData(), data);
    }
}
