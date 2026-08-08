// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibRainDeploy} from "rain-deploy-0.1.3/src/lib/LibRainDeploy.sol";
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

    /// The open-salt release's runtime code MUST expose both deterministic
    /// entry points. A snapshot that pins bytecode without
    /// `cloneDeterministicOpenSalt` in it would be a silently wrong pin — the
    /// address would be real and the function missing.
    function testCloneFactory_0_1_6_RuntimeExposesBothEntryPoints() external pure {
        bytes4 cloneDeterministicSelector = bytes4(keccak256("cloneDeterministic(address,bytes,bytes32)"));
        bytes4 cloneOpenSaltSelector = bytes4(keccak256("cloneDeterministicOpenSalt(address,bytes,bytes32)"));
        bytes4 predictSelector = bytes4(keccak256("predictDeterministicAddress(address,bytes32,address)"));
        bytes4 predictOpenSaltSelector = bytes4(keccak256("predictDeterministicAddressOpenSalt(address,bytes32)"));

        assertTrue(_containsSelector(CLONE_FACTORY_RUNTIME_CODE_0_1_6, cloneDeterministicSelector));
        assertTrue(_containsSelector(CLONE_FACTORY_RUNTIME_CODE_0_1_6, cloneOpenSaltSelector));
        assertTrue(_containsSelector(CLONE_FACTORY_RUNTIME_CODE_0_1_6, predictSelector));
        assertTrue(_containsSelector(CLONE_FACTORY_RUNTIME_CODE_0_1_6, predictOpenSaltSelector));
    }

    /// True if the 4 byte `selector` appears anywhere in `code`. Enough to see a
    /// selector in a dispatch table without decoding the dispatcher.
    function _containsSelector(bytes memory code, bytes4 selector) internal pure returns (bool) {
        for (uint256 i = 0; i + 4 <= code.length; i++) {
            if (
                code[i] == selector[0] && code[i + 1] == selector[1] && code[i + 2] == selector[2]
                    && code[i + 3] == selector[3]
            ) {
                return true;
            }
        }
        return false;
    }
}
