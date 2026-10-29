// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {
    DeployDeclaration,
    DeploySuite,
    RainDeploySuitesBase,
    SnapshotFile
} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {RAIN_COPYRIGHT_TEXT, RAIN_SPDX_LICENSE_IDENTIFIER} from "rain-sol-codegen-0.1.39/src/lib/LibCodeGen.sol";
import {LibRainDeploySnapshot} from "rain-deploy-0.1.29/src/lib/LibRainDeploySnapshot.sol";
import {CloneNetworks} from "../../../src/lib/LibRainDeployClone.sol";
import {
    CLONE_PER_NETWORK_MECHANISM,
    LibRainDeployCloneMechanism
} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {
    EXAMPLE_CLONE_RECORD_CONTRACT,
    EXAMPLE_CLONE_RECORD_ROOT,
    EXAMPLE_CLONE_RELEASE_TAG,
    exampleCloneRelease
} from "../../abstract/ExampleCloneDeploys.sol";
import {
    PER_NETWORK_CLONE_ARBITRUM_ONE_CHAIN_ID,
    PER_NETWORK_CLONE_POLYGON_CHAIN_ID,
    PER_NETWORK_CLONE_RECORD_CONTRACT,
    PER_NETWORK_CLONE_RECORD_ROOT,
    PER_NETWORK_CLONE_RELEASE_TAG,
    perNetworkClone,
    perNetworkCloneChainIds,
    perNetworkCloneLayers,
    perNetworkCloneRelease
} from "../../abstract/PerNetworkCloneDeploys.sol";

/// @title LibRainDeployCloneSnapshotTest
/// @notice The clone and per-network clone record writers, and the released lib a per-network clone record yields.
contract LibRainDeployCloneSnapshotTest is Test, RainDeploySuitesBase {
    function declaration() internal view override returns (DeployDeclaration memory) {
        return perNetworkCloneLayers();
    }

    /// The roots the writer tests produce into, one per test so tests running in parallel never share one.
    string constant CLONE_RECORD_NO_RESIDUE_ROOT = "fixture-lib/snapshot-clone/clone-record-no-residue";
    string constant CLONE_RECORD_DEPLOY_NOT_CLAIMS_ROOT = "fixture-lib/snapshot-clone/clone-record-deploy-not-claims";
    string constant PER_NETWORK_RECORD_DEPLOY_NOT_CLAIMS_ROOT =
        "fixture-lib/snapshot-clone/per-network-record-deploy-not-claims";
    string constant RELEASED_PER_NETWORK_LIB_DIR = "fixture-lib/snapshot-clone/released-per-network";

    /// @param root The root to write under.
    /// @param tag The release tag.
    /// @param contractName The record's contract.
    /// @param suite The suite, its networks the declaration's.
    /// @return The path written.
    function writeRecord(string memory root, string memory tag, string memory contractName, DeploySuite memory suite)
        internal
        returns (string memory)
    {
        DeployDeclaration memory d = declaration();
        suite.networks = d.networks;
        return writeSuiteSnapshot(
            d, vm, SnapshotFile(root, tag, contractName, RAIN_SPDX_LICENSE_IDENTIFIER, RAIN_COPYRIGHT_TEXT), suite
        );
    }

    /// @return The candidate suite of `exampleCloneRelease()`.
    function exampleCloneReleaseSuite() internal view returns (DeploySuite memory) {
        return LibRainDeployCloneMechanism.cloneCandidate(exampleCloneRelease(), new uint256[](0)).snapshot;
    }

    /// The clone writer deploys locally only to read what it records, inside a state snapshot it
    /// reverts.
    function testCloneWriterLeavesNoDeployBehind() external {
        DeploySuite memory suite = exampleCloneReleaseSuite();
        assertEq(suite.storedDeployedAddress.code.length, 0);
        for (uint256 i = 0; i < suite.dependencies.length; i++) {
            assertEq(suite.dependencies[i].deployedAddress.code.length, 0);
        }

        writeRecord(CLONE_RECORD_NO_RESIDUE_ROOT, EXAMPLE_CLONE_RELEASE_TAG, EXAMPLE_CLONE_RECORD_CONTRACT, suite);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.removeDir(CLONE_RECORD_NO_RESIDUE_ROOT, true);

        assertEq(suite.storedDeployedAddress.code.length, 0);
        for (uint256 i = 0; i < suite.dependencies.length; i++) {
            assertEq(suite.dependencies[i].deployedAddress.code.length, 0);
        }
    }

    /// The clone writer records what the mechanism deployed, not what the suite claims about it.
    function testCloneWriterRecordsTheDeployNotTheSuiteClaims() external {
        DeploySuite memory suite = exampleCloneReleaseSuite();
        suite.storedDeployedAddress = address(uint160(suite.storedDeployedAddress) + 1);
        suite.storedRuntimeCode = hex"00";

        string memory written = writeRecord(
            CLONE_RECORD_DEPLOY_NOT_CLAIMS_ROOT, EXAMPLE_CLONE_RELEASE_TAG, EXAMPLE_CLONE_RECORD_CONTRACT, suite
        );
        string memory reproduced = vm.readFile(written);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.removeDir(CLONE_RECORD_DEPLOY_NOT_CLAIMS_ROOT, true);

        assertEq(
            reproduced,
            vm.readFile(
                LibRainDeploySnapshot.pathForSnapshot(
                    EXAMPLE_CLONE_RECORD_ROOT, EXAMPLE_CLONE_RELEASE_TAG, EXAMPLE_CLONE_RECORD_CONTRACT
                )
            )
        );
    }

    /// The per-network writer records each network's address from the LOCAL deploy, not from the
    /// addresses the suite's `CloneNetworks` claims.
    function testPerNetworkCloneWriterRecordsTheDeployNotTheSuiteClaims() external {
        DeploySuite memory suite =
        LibRainDeployCloneMechanism.cloneCandidate(perNetworkCloneRelease(), perNetworkCloneChainIds()).snapshot;
        CloneNetworks memory clones = LibRainDeployCloneMechanism.cloneNetworks(suite);
        assertEq(clones.networks.length, 2);
        assertEq(clones.networks[0].chainId, PER_NETWORK_CLONE_ARBITRUM_ONE_CHAIN_ID);
        assertEq(clones.networks[1].chainId, PER_NETWORK_CLONE_POLYGON_CHAIN_ID);
        assertTrue(clones.networks[0].deployedAddress != clones.networks[1].deployedAddress);
        (clones.networks[0].deployedAddress, clones.networks[1].deployedAddress) =
        (clones.networks[1].deployedAddress, clones.networks[0].deployedAddress);
        suite.mechanismData = abi.encode(CLONE_PER_NETWORK_MECHANISM, abi.encode(clones));
        suite.storedRuntimeCode = hex"00";

        string memory written = writeRecord(
            PER_NETWORK_RECORD_DEPLOY_NOT_CLAIMS_ROOT,
            PER_NETWORK_CLONE_RELEASE_TAG,
            PER_NETWORK_CLONE_RECORD_CONTRACT,
            suite
        );
        string memory reproduced = vm.readFile(written);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.removeDir(PER_NETWORK_RECORD_DEPLOY_NOT_CLAIMS_ROOT, true);

        assertEq(reproduced, vm.readFile(perNetworkRecordPaths()[0]));
    }

    /// The import a per-network clone release contributes to its released lib.
    string constant EXPECTED_PER_NETWORK_IMPORT = "import {\n"
        "    BYTECODE_HASH as PerNetworkClone_0_0_1_BYTECODE_HASH,\n"
        "    CREATION_CODE as PerNetworkClone_0_0_1_CREATION_CODE,\n"
        "    RUNTIME_CODE as PerNetworkClone_0_0_1_RUNTIME_CODE,\n"
        "    DEPENDENCIES as PerNetworkClone_0_0_1_DEPENDENCIES,\n"
        "    MECHANISM_DATA as PerNetworkClone_0_0_1_MECHANISM_DATA\n"
        "} from \"../generated/0_0_1/PerNetworkClone.sol\";\n\n";

    /// The entry a per-network clone release contributes.
    string constant EXPECTED_PER_NETWORK_ENTRY = "        suites[0] = DeploySuite({\n"
        "            suite: \"per-network-clone@0_0_1\",\n"
        "            creationCode: PerNetworkClone_0_0_1_CREATION_CODE,\n"
        "            storedDeployedAddress: address(0),\n"
        "            storedBytecodeHash: PerNetworkClone_0_0_1_BYTECODE_HASH,\n"
        "            storedRuntimeCode: PerNetworkClone_0_0_1_RUNTIME_CODE,\n"
        "            artifactPath: \"rain-factory/EIP1167Clone.sol:EIP1167Clone\",\n"
        "            dependencies: abi.decode(PerNetworkClone_0_0_1_DEPENDENCIES, (DeployDependency[])),\n"
        "            mechanismData: PerNetworkClone_0_0_1_MECHANISM_DATA,\n" "            networks: new string[](0)\n"
        "        });\n";

    /// The committed `per-network-clone` record's path, as `frozenSnapshotPaths` spells it.
    /// @return The one record file.
    function perNetworkRecordPaths() internal pure returns (string[] memory) {
        string[] memory paths = new string[](1);
        paths[0] = LibRainDeploySnapshot.pathForSnapshot(
            PER_NETWORK_CLONE_RECORD_ROOT, PER_NETWORK_CLONE_RELEASE_TAG, PER_NETWORK_CLONE_RECORD_CONTRACT
        );
        return paths;
    }

    /// The candidate the per-network released lib takes its metadata from.
    /// @return The `per-network-clone` candidate's suite.
    function perNetworkTemplate() internal view returns (DeploySuite memory) {
        return LibRainDeployCloneMechanism.cloneCandidate(
            perNetworkClone("per-network-clone", bytes32(uint256(4))), perNetworkCloneChainIds()
        )
        .snapshot;
    }

    /// The header every generated file carries under the org's licence and copyright, followed by the blank line
    /// every writer puts after it. Split so `reuse lint` does not read it as this file's own licence declaration.
    /// @return The prefix.
    function generatedFilePrefix() internal pure returns (string memory) {
        return string.concat(
            "// SPDX-License",
            "-Identifier: ",
            RAIN_SPDX_LICENSE_IDENTIFIER,
            "\n",
            "// SPDX-FileCopyrightText: ",
            RAIN_COPYRIGHT_TEXT,
            "\n",
            "pragma solidity ^0.8.25;\n\n",
            "// THIS FILE IS AUTOGENERATED BY THE BUILD SCRIPT. DO NOT EDIT BY HAND.\n\n"
        );
    }

    /// A per-network clone release is imported without `DEPLOYED_ADDRESS` — the record declares
    /// none, so importing it would not compile — and with its `MECHANISM_DATA`.
    function testReleasedImportOfAPerNetworkCloneRelease() external view {
        assertEq(LibRainDeploySnapshot.releasedImport(vm, perNetworkRecordPaths()[0]), EXPECTED_PER_NETWORK_IMPORT);
    }

    /// A per-network clone release's entry stores no address and carries the record's `MECHANISM_DATA`, the shape of
    /// `perNetworkCloneReleased()`.
    function testReleasedSuiteEntryOfAPerNetworkCloneRelease() external view {
        assertEq(
            LibRainDeploySnapshot.releasedSuiteEntry(
                vm, 0, perNetworkRecordPaths()[0], perNetworkTemplate(), declaration()
            ),
            EXPECTED_PER_NETWORK_ENTRY
        );
    }

    /// The released lib written from the committed per-network record over a per-network clone
    /// template is the prefix, the suites and mechanism imports, the per-network import and the per-network entry.
    function testWriteReleasedSuitesLibOfAPerNetworkCloneRecord() external {
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.createDir(RELEASED_PER_NETWORK_LIB_DIR, true);

        string memory written = LibRainDeploySnapshot.writeReleasedSuitesLib(
            vm,
            RELEASED_PER_NETWORK_LIB_DIR,
            PER_NETWORK_CLONE_RECORD_ROOT,
            PER_NETWORK_CLONE_RECORD_CONTRACT,
            perNetworkTemplate(),
            declaration()
        );
        string memory emitted = vm.readFile(written);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.removeDir(RELEASED_PER_NETWORK_LIB_DIR, true);

        assertEq(
            emitted,
            string.concat(
                generatedFilePrefix(),
                "import {DeployDependency, DeploySuite} from \"",
                LibRainDeploySnapshot.derivedSuitesImportPath(vm),
                "\";\n",
                "import {CLONE_PER_NETWORK_MECHANISM} from \"../lib/LibRainDeployCloneMechanism.sol\";\n\n",
                EXPECTED_PER_NETWORK_IMPORT,
                LibRainDeploySnapshot.releasedLibraryBlock(
                    vm,
                    "LibPerNetworkCloneReleased",
                    PER_NETWORK_CLONE_RECORD_CONTRACT,
                    perNetworkRecordPaths(),
                    perNetworkTemplate(),
                    declaration()
                )
            )
        );
        assertTrue(vm.contains(emitted, EXPECTED_PER_NETWORK_ENTRY));
        assertFalse(vm.contains(emitted, "DEPLOYED_ADDRESS"));
    }
}
