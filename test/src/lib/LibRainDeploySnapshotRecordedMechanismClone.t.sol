// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {
    DeployDeclaration,
    DeployDependency,
    DeployMechanismHandler,
    DeploySuite
} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeploy} from "rain-deploy-0.1.29/src/lib/LibRainDeploy.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.29/src/lib/LibRainDeployDeclaration.sol";
import {LibRainDeploySnapshot} from "rain-deploy-0.1.29/src/lib/LibRainDeploySnapshot.sol";
import {
    LibRainDeployZoltuMechanism,
    ZOLTU_MECHANISM_ID
} from "rain-deploy-0.1.29/src/lib/LibRainDeployZoltuMechanism.sol";
import {CLONE_ARTIFACT_PATH} from "../../../src/lib/LibRainDeployClone.sol";
import {
    CLONE_MECHANISM,
    CLONE_PER_NETWORK_MECHANISM,
    LibRainDeployCloneMechanism
} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {MockCloneable} from "../../concrete/MockCloneable.sol";
import {
    BYTECODE_HASH as ZOLTU_BYTECODE_HASH,
    DEPLOYED_ADDRESS as ZOLTU_DEPLOYED_ADDRESS
} from "../../fixture-mechanism-change/generated/0_0_1/MockCloneable.sol";
import {
    BYTECODE_HASH as CLONE_BYTECODE_HASH,
    DEPLOYED_ADDRESS as CLONE_DEPLOYED_ADDRESS,
    MECHANISM_DATA as CLONE_MECHANISM_DATA
} from "../../fixture-mechanism-change/generated/0_0_2/MockCloneable.sol";
import {
    BYTECODE_HASH as PER_NETWORK_BYTECODE_HASH,
    MECHANISM_DATA as PER_NETWORK_MECHANISM_DATA
} from "../../fixture-mechanism-change/generated/0_0_3/MockCloneable.sol";
import {LibMockCloneableReleased} from "../../fixture-mechanism-change/lib/LibMockCloneableReleased.sol";

/// @title LibRainDeploySnapshotRecordedMechanismCloneTest
/// @notice One contract's legacy untagged records, cut under Zoltu, then as a clone, then per network, each read
/// and released as the mechanism it was cut with.
contract LibRainDeploySnapshotRecordedMechanismCloneTest is Test {
    string constant RECORD_ROOT = "test/fixture-mechanism-change/generated";

    string constant LIB_DIR = "test/fixture-mechanism-change/lib";

    string constant FRESH_LIB_DIR = "fixture-lib/recorded-mechanism-clone-libs";

    string constant RECORD_CONTRACT = "MockCloneable";

    function declaration() internal view returns (DeployDeclaration memory) {
        DeployDeclaration memory d;
        LibRainDeployDeclaration.extend(d);
        LibRainDeployZoltuMechanism.extend(d);
        LibRainDeployCloneMechanism.extend(d);
        LibRainDeployCloneMechanism.setFactoryImportRoot(d, "../../../src/");
        return d;
    }

    function template() internal pure returns (DeploySuite memory) {
        return DeploySuite({
            suite: "mock-cloneable",
            creationCode: "",
            storedDeployedAddress: address(0),
            storedBytecodeHash: bytes32(0),
            storedRuntimeCode: "",
            artifactPath: CLONE_ARTIFACT_PATH,
            dependencies: new DeployDependency[](0),
            mechanismData: "",
            networks: new string[](0)
        });
    }

    function recordPath(string memory tag) internal pure returns (string memory) {
        return LibRainDeploySnapshot.pathForSnapshot(RECORD_ROOT, tag, RECORD_CONTRACT);
    }

    function mechanismOf(DeployDeclaration memory d, DeploySuite memory suite)
        internal
        pure
        returns (DeployMechanismHandler memory)
    {
        return LibRainDeployDeclaration.mechanismOf(d, suite);
    }

    /// Each record reads as the mechanism it was cut with, the untagged clone records through `legacyRecordId`.
    function testRecordedMechanismIdReadsEachReleaseOnItsOwn() external view {
        DeployDeclaration memory d = declaration();
        assertEq(LibRainDeploySnapshot.recordedMechanismId(d, vm, recordPath("0_0_1")), ZOLTU_MECHANISM_ID);
        assertEq(LibRainDeploySnapshot.recordedMechanismId(d, vm, recordPath("0_0_2")), CLONE_MECHANISM);
        assertEq(LibRainDeploySnapshot.recordedMechanismId(d, vm, recordPath("0_0_3")), CLONE_PER_NETWORK_MECHANISM);
    }

    /// The committed released lib is exactly what `writeReleasedSuitesLib` writes from the committed records.
    function testTheCommittedLibIsWhatTheGeneratorEmits() external {
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.createDir(FRESH_LIB_DIR, true);
        string memory written = LibRainDeploySnapshot.writeReleasedSuitesLib(
            vm, FRESH_LIB_DIR, RECORD_ROOT, RECORD_CONTRACT, template(), declaration()
        );
        string memory fresh = vm.readFile(written);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.removeDir(FRESH_LIB_DIR, true);

        assertEq(
            vm.readFile(
                LibRainDeploySnapshot.pathForLib(LIB_DIR, LibRainDeploySnapshot.releasedLibraryName(RECORD_CONTRACT))
            ),
            fresh
        );
    }

    /// Every entry of the committed lib resolves to its release's own mechanism and derives its recorded address.
    function testEveryEntryIsItsReleasesOwnMechanism() external view {
        DeployDeclaration memory d = declaration();
        DeploySuite[] memory suites = LibMockCloneableReleased.releasedSuites();
        assertEq(suites.length, 3);

        assertEq(suites[0].suite, "mock-cloneable@0_0_1");
        assertEq(mechanismOf(d, suites[0]).id, ZOLTU_MECHANISM_ID);
        assertEq(suites[0].mechanismData, LibRainDeployZoltuMechanism.mechanismData());
        assertEq(suites[0].storedDeployedAddress, ZOLTU_DEPLOYED_ADDRESS);
        assertEq(suites[0].storedDeployedAddress, LibRainDeploy.zoltuAddress(type(MockCloneable).creationCode));
        assertEq(suites[0].storedBytecodeHash, ZOLTU_BYTECODE_HASH);

        assertEq(suites[1].suite, "mock-cloneable@0_0_2");
        assertEq(mechanismOf(d, suites[1]).id, CLONE_MECHANISM);
        assertEq(suites[1].mechanismData, abi.encode(CLONE_MECHANISM, CLONE_MECHANISM_DATA));
        assertEq(suites[1].storedDeployedAddress, CLONE_DEPLOYED_ADDRESS);
        assertEq(suites[1].storedBytecodeHash, CLONE_BYTECODE_HASH);

        assertEq(suites[2].suite, "mock-cloneable@0_0_3");
        assertEq(mechanismOf(d, suites[2]).id, CLONE_PER_NETWORK_MECHANISM);
        assertEq(suites[2].mechanismData, abi.encode(CLONE_PER_NETWORK_MECHANISM, PER_NETWORK_MECHANISM_DATA));
        assertEq(suites[2].storedDeployedAddress, address(0));
        assertEq(suites[2].storedBytecodeHash, PER_NETWORK_BYTECODE_HASH);

        for (uint256 i = 0; i < suites.length; i++) {
            assertEq(suites[i].artifactPath, CLONE_ARTIFACT_PATH);
            assertEq(keccak256(suites[i].storedRuntimeCode), suites[i].storedBytecodeHash);
        }
        assertEq(mechanismOf(d, suites[0]).deployedAddress(d, suites[0], 1), suites[0].storedDeployedAddress);
        assertEq(mechanismOf(d, suites[1]).deployedAddress(d, suites[1], 1), suites[1].storedDeployedAddress);
    }
}
