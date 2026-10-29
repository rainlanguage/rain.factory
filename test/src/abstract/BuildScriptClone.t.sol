// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {LibRainDeploySnapshot} from "rain-deploy-0.1.29/src/lib/LibRainDeploySnapshot.sol";
import {
    LibCodeGen,
    RAIN_COPYRIGHT_TEXT,
    RAIN_SPDX_LICENSE_IDENTIFIER
} from "rain-sol-codegen-0.1.39/src/lib/LibCodeGen.sol";
import {CloneDeploy, CloneTarget, LibRainDeployClone} from "../../../src/lib/LibRainDeployClone.sol";
import {
    CLONE_MECHANISM,
    CLONE_PER_NETWORK_MECHANISM,
    ExtendedNetworkAddressMismatch,
    ExtendedNetworksUnexpected
} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {
    ChainDeploy,
    ExtendedNetworksRewritten,
    LibRainDeployExtendedNetworks
} from "../../../src/lib/LibRainDeployExtendedNetworks.sol";
import {CloneBuildScriptHarness} from "../../concrete/CloneBuildScriptHarness.sol";
import {PerNetworkCloneBuildScriptHarness} from "../../concrete/PerNetworkCloneBuildScriptHarness.sol";
import {
    SECOND_RELEASE_KEY,
    TwoReleasePerNetworkCloneBuildScriptHarness
} from "../../concrete/TwoReleasePerNetworkCloneBuildScriptHarness.sol";
import {
    PER_NETWORK_CLONE_POLYGON_CHAIN_ID,
    PER_NETWORK_CLONE_RECORD_CONTRACT,
    PER_NETWORK_CLONE_RECORD_ROOT,
    PER_NETWORK_CLONE_RELEASE_TAG,
    perNetworkCloneInitData,
    perNetworkCloneRelease
} from "../../abstract/PerNetworkCloneDeploys.sol";
import {
    EXAMPLE_CLONE_RECORD_CONTRACT,
    EXAMPLE_CLONE_RECORD_ROOT,
    EXAMPLE_CLONE_RELEASE_TAG
} from "../../abstract/ExampleCloneDeploys.sol";

/// @title BuildScriptCloneTest
/// @notice A clone deploy repo's build over the clone layer: what `cutRelease()` freezes and releases a clone as,
/// and the extended networks records the build writes, declares and refuses. Every fixture has its own root under
/// `fixture-lib`, which nothing compiles and forge may write.
contract BuildScriptCloneTest is Test {
    string constant CLONE_CUT_FIXTURE_ROOT = "fixture-lib/buildscript-clone-cut";

    string constant CLONE_CUT_LIB_DIR = "fixture-lib/buildscript-clone-cut-lib";

    string constant PER_NETWORK_CLONE_CUT_FIXTURE_ROOT = "fixture-lib/buildscript-per-network-clone-cut";

    string constant PER_NETWORK_CLONE_CUT_LIB_DIR = "fixture-lib/buildscript-per-network-clone-cut-lib";

    string constant EXTENDED_NETWORKS_FIXTURE_ROOT = "fixture-lib/buildscript-extended-networks";

    /// Clears a fixture an earlier failure left behind: a cheatcode write is not undone by a revert.
    /// @param root The fixture root to clear.
    function resetFixture(string memory root) internal {
        if (vm.exists(root)) {
            //forge-lint: disable-next-line(unsafe-cheatcode)
            vm.removeDir(root, true);
        }
    }

    /// The released-suites lib entry of a tagged record's `mechanismData`: the record's constant verbatim.
    /// @param prefix The record's constant prefix.
    /// @return The entry.
    function mechanismDataEntry(string memory prefix) internal pure returns (string memory) {
        return string.concat("mechanismData: ", prefix, "_MECHANISM_DATA,");
    }

    /// PROPERTY: `cutRelease()` freezes the regenerated clone snapshot as the committed clone record and releases it
    /// as a clone at one address, under the template suite and the tag.
    function testCutReleaseFreezesACloneRecordAndReleasesItAsAClone() external {
        resetFixture(CLONE_CUT_FIXTURE_ROOT);
        resetFixture(CLONE_CUT_LIB_DIR);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.createDir(CLONE_CUT_LIB_DIR, true);
        CloneBuildScriptHarness harness = new CloneBuildScriptHarness(CLONE_CUT_FIXTURE_ROOT, CLONE_CUT_LIB_DIR);
        harness.cutRelease();

        // Read while the fixture is still there, asserted once it is gone.
        string memory frozen = vm.readFile(harness.frozenPath());
        string memory rolling = vm.readFile(harness.rollingPath());
        string memory lib = vm.readFile(harness.releasedLibPath());

        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.removeDir(CLONE_CUT_FIXTURE_ROOT, true);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.removeDir(CLONE_CUT_LIB_DIR, true);

        assertEq(frozen, rolling);
        assertEq(
            frozen,
            vm.readFile(
                LibRainDeploySnapshot.pathForSnapshot(
                    EXAMPLE_CLONE_RECORD_ROOT, EXAMPLE_CLONE_RELEASE_TAG, EXAMPLE_CLONE_RECORD_CONTRACT
                )
            )
        );

        string memory prefix = string.concat(EXAMPLE_CLONE_RECORD_CONTRACT, "_", LibRainDeploySnapshot.deployTag(vm));
        assertTrue(
            vm.contains(lib, string.concat("suite: \"example-clone@", LibRainDeploySnapshot.deployTag(vm), "\"")),
            "the release is keyed by the template suite and the tag"
        );
        assertTrue(vm.contains(lib, mechanismDataEntry(prefix)), "the release is declared a clone");
        assertFalse(vm.contains(lib, "abi.encode("), "by the tagged record, not a lib-side tag");
        assertTrue(
            vm.contains(lib, string.concat("storedDeployedAddress: ", prefix, "_DEPLOYED_ADDRESS")),
            "at one address on every network"
        );
        assertFalse(vm.contains(lib, vm.toString(CLONE_PER_NETWORK_MECHANISM)), "and not per network");
        assertFalse(vm.contains(lib, "LibRainDeployZoltuMechanism"), "and not a Zoltu release");
        assertTrue(
            vm.contains(lib, string.concat("MECHANISM_DATA as ", prefix, "_MECHANISM_DATA")),
            "the record's mechanism data is imported"
        );
    }

    /// PROPERTY: `cutRelease()` freezes the regenerated per-network clone snapshot as the committed per-network
    /// record and releases it per network, with no single address.
    function testCutReleaseFreezesAPerNetworkCloneRecordAndReleasesItPerNetwork() external {
        resetFixture(PER_NETWORK_CLONE_CUT_FIXTURE_ROOT);
        resetFixture(PER_NETWORK_CLONE_CUT_LIB_DIR);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.createDir(PER_NETWORK_CLONE_CUT_LIB_DIR, true);
        PerNetworkCloneBuildScriptHarness harness =
            new PerNetworkCloneBuildScriptHarness(PER_NETWORK_CLONE_CUT_FIXTURE_ROOT, PER_NETWORK_CLONE_CUT_LIB_DIR);
        harness.cutRelease();

        // Read while the fixture is still there, asserted once it is gone.
        string memory frozen = vm.readFile(harness.frozenPath());
        string memory rolling = vm.readFile(harness.rollingPath());
        string memory lib = vm.readFile(harness.releasedLibPath());

        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.removeDir(PER_NETWORK_CLONE_CUT_FIXTURE_ROOT, true);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.removeDir(PER_NETWORK_CLONE_CUT_LIB_DIR, true);

        assertEq(frozen, rolling);
        assertEq(
            frozen,
            vm.readFile(
                LibRainDeploySnapshot.pathForSnapshot(
                    PER_NETWORK_CLONE_RECORD_ROOT, PER_NETWORK_CLONE_RELEASE_TAG, PER_NETWORK_CLONE_RECORD_CONTRACT
                )
            )
        );

        string memory prefix =
            string.concat(PER_NETWORK_CLONE_RECORD_CONTRACT, "_", LibRainDeploySnapshot.deployTag(vm));
        assertTrue(
            vm.contains(lib, string.concat("suite: \"per-network-clone@", LibRainDeploySnapshot.deployTag(vm), "\"")),
            "the release is keyed by the template suite and the tag"
        );
        assertTrue(vm.contains(lib, mechanismDataEntry(prefix)), "the release is declared per network");
        assertFalse(vm.contains(lib, "abi.encode("), "by the tagged record, not a lib-side tag");
        assertFalse(vm.contains(lib, vm.toString(CLONE_MECHANISM)), "and not as one clone everywhere");
        assertFalse(vm.contains(lib, "LibRainDeployZoltuMechanism"), "nor as a Zoltu release");
        assertTrue(vm.contains(lib, "storedDeployedAddress: address(0)"), "it stores no single address");
        assertFalse(vm.contains(lib, "DEPLOYED_ADDRESS"), "and imports none the record does not declare");
        assertTrue(
            vm.contains(lib, string.concat("MECHANISM_DATA as ", prefix, "_MECHANISM_DATA")),
            "the record's mechanism data is imported"
        );
    }

    /// PROPERTY: the build writes each release's declared extended networks to its record under the declared
    /// licence, writes nothing for a release declaring none, and refuses a declaration that drops a recorded network.
    function testRegenerateExtendedNetworksWritesTheRecord() external {
        resetFixture(EXTENDED_NETWORKS_FIXTURE_ROOT);
        PerNetworkCloneBuildScriptHarness harness =
            new PerNetworkCloneBuildScriptHarness(EXTENDED_NETWORKS_FIXTURE_ROOT, EXTENDED_NETWORKS_FIXTURE_ROOT);
        (,, string memory path) = LibRainDeployExtendedNetworks.extendedNetworksPath(
            EXTENDED_NETWORKS_FIXTURE_ROOT, "per-network-clone@0_0_1"
        );

        harness.externalRegenerateExtendedNetworks();
        assertFalse(vm.exists(path), "a release declaring nothing has no record");

        ChainDeploy[] memory networks = new ChainDeploy[](2);
        networks[0] = extendedNetwork(8453, hex"00aa");
        networks[1] = extendedNetwork(1, hex"");
        ChainDeploy[] memory first = new ChainDeploy[](1);
        first[0] = networks[0];
        harness.setExtendedNetworks(first);
        harness.externalRegenerateExtendedNetworks();
        string memory rainRecord = vm.readFile(path);

        harness.setExtendedNetworksLicence("MIT", "Copyright (c) Someone");
        harness.setExtendedNetworks(networks);
        harness.externalRegenerateExtendedNetworks();
        string memory mitRecord = vm.readFile(path);

        harness.setExtendedNetworks(new ChainDeploy[](0));
        vm.expectRevert(abi.encodeWithSelector(ExtendedNetworksRewritten.selector, "per-network-clone@0_0_1", 0));
        harness.externalRegenerateExtendedNetworks();

        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.removeDir(EXTENDED_NETWORKS_FIXTURE_ROOT, true);

        assertEq(
            rainRecord,
            string.concat(
                LibCodeGen.filePrefix(RAIN_SPDX_LICENSE_IDENTIFIER, RAIN_COPYRIGHT_TEXT),
                LibRainDeployExtendedNetworks.extendedNetworksBody(vm, first)
            )
        );
        assertEq(
            mitRecord,
            string.concat(
                LibCodeGen.filePrefix("MIT", "Copyright (c) Someone"),
                LibRainDeployExtendedNetworks.extendedNetworksBody(vm, networks)
            )
        );
    }

    /// PROPERTY: `run()` writes each release's declared extended networks to its record.
    function testRunWritesTheExtendedNetworksRecord() external {
        string memory root = string.concat(EXTENDED_NETWORKS_FIXTURE_ROOT, "-run");
        resetFixture(root);
        PerNetworkCloneBuildScriptHarness harness = new PerNetworkCloneBuildScriptHarness(root, root);
        harness.seedConfig();
        ChainDeploy[] memory networks = new ChainDeploy[](1);
        networks[0] = extendedNetwork(8453, hex"00aa");
        harness.setExtendedNetworks(networks);
        harness.run();

        (,, string memory path) = LibRainDeployExtendedNetworks.extendedNetworksPath(root, "per-network-clone@0_0_1");
        string memory written = vm.readFile(path);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.removeDir(root, true);

        assertEq(
            written,
            string.concat(
                LibCodeGen.filePrefix(RAIN_SPDX_LICENSE_IDENTIFIER, RAIN_COPYRIGHT_TEXT),
                LibRainDeployExtendedNetworks.extendedNetworksBody(vm, networks)
            )
        );
    }

    /// PROPERTY: `run()` declares the extended networks record of each release that declares extended networks,
    /// and only those, and writes the one it declares.
    function testRunDeclaresTheExtendedNetworksRecordsItWrites() external {
        string memory root = string.concat(EXTENDED_NETWORKS_FIXTURE_ROOT, "-run-declared");
        resetFixture(root);
        TwoReleasePerNetworkCloneBuildScriptHarness harness =
            new TwoReleasePerNetworkCloneBuildScriptHarness(root, root);
        harness.seedConfig();
        ChainDeploy[] memory second = new ChainDeploy[](1);
        second[0] = extendedNetwork(1, hex"00bb");
        harness.setSecondExtendedNetworks(second);

        string[] memory undeclared = new PerNetworkCloneBuildScriptHarness(root, root).externalGeneratedPaths();
        string[] memory paths = harness.externalGeneratedPaths();
        harness.run();
        (,, string memory firstPath) =
            LibRainDeployExtendedNetworks.extendedNetworksPath(root, "per-network-clone@0_0_1");
        (,, string memory secondPath) = LibRainDeployExtendedNetworks.extendedNetworksPath(root, SECOND_RELEASE_KEY);
        bool firstWritten = vm.exists(firstPath);
        bool secondWritten = vm.exists(secondPath);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.removeDir(root, true);

        assertEq(paths.length, undeclared.length + 1);
        for (uint256 i = 0; i < undeclared.length; i++) {
            assertEq(paths[i], undeclared[i]);
        }
        assertEq(paths[paths.length - 1], secondPath);
        assertTrue(secondWritten);
        assertFalse(firstWritten);
    }

    /// PROPERTY: the build writes each release's record from that release's own declaration, under that release's
    /// key.
    function testRegenerateExtendedNetworksWritesEachReleasesOwnRecord() external {
        string memory root = string.concat(EXTENDED_NETWORKS_FIXTURE_ROOT, "-two-releases");
        resetFixture(root);
        TwoReleasePerNetworkCloneBuildScriptHarness harness =
            new TwoReleasePerNetworkCloneBuildScriptHarness(root, root);
        ChainDeploy[] memory first = new ChainDeploy[](1);
        first[0] = extendedNetwork(8453, hex"00aa");
        ChainDeploy[] memory second = new ChainDeploy[](1);
        second[0] = extendedNetwork(1, hex"00bb");
        harness.setExtendedNetworks(first);
        harness.setSecondExtendedNetworks(second);

        harness.externalRegenerateExtendedNetworks();
        (,, string memory firstPath) =
            LibRainDeployExtendedNetworks.extendedNetworksPath(root, "per-network-clone@0_0_1");
        (,, string memory secondPath) = LibRainDeployExtendedNetworks.extendedNetworksPath(root, SECOND_RELEASE_KEY);
        string memory firstRecord = vm.readFile(firstPath);
        string memory secondRecord = vm.readFile(secondPath);
        bytes memory firstRead =
            abi.encode(LibRainDeployExtendedNetworks.recordedExtendedNetworks(vm, root, "per-network-clone@0_0_1"));
        bytes memory secondRead =
            abi.encode(LibRainDeployExtendedNetworks.recordedExtendedNetworks(vm, root, SECOND_RELEASE_KEY));

        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.removeDir(root, true);

        assertEq(firstRead, abi.encode(first));
        assertEq(secondRead, abi.encode(second));
        string memory prefix = LibCodeGen.filePrefix(RAIN_SPDX_LICENSE_IDENTIFIER, RAIN_COPYRIGHT_TEXT);
        assertEq(firstRecord, string.concat(prefix, LibRainDeployExtendedNetworks.extendedNetworksBody(vm, first)));
        assertEq(secondRecord, string.concat(prefix, LibRainDeployExtendedNetworks.extendedNetworksBody(vm, second)));
    }

    /// A network beyond the per-network release's record, at the address its init data derives under the release.
    /// @param chainId The network's chain id.
    /// @param data The init data.
    /// @return The network.
    function extendedNetwork(uint256 chainId, bytes memory data) internal pure returns (ChainDeploy memory) {
        CloneDeploy memory release = perNetworkCloneRelease();
        return ChainDeploy({
            chainId: chainId,
            data: data,
            deployedAddress: LibRainDeployClone.cloneDeployedAddress(
                CloneTarget({
                    factory: release.factory, implementation: release.implementation, data: data, salt: release.salt
                })
            )
        });
    }

    /// Runs the build over a fresh per-network harness declaring `networks`, expecting `err`, and checks that
    /// nothing was written under its extended networks root.
    /// @param label The fixture root's suffix, one per test.
    /// @param networks The networks declared.
    /// @param err The revert expected.
    function checkExtendedNetworksRefused(string memory label, ChainDeploy[] memory networks, bytes memory err)
        internal
    {
        string memory root = string.concat(EXTENDED_NETWORKS_FIXTURE_ROOT, "-", label);
        resetFixture(root);
        PerNetworkCloneBuildScriptHarness harness = new PerNetworkCloneBuildScriptHarness(root, root);
        harness.setExtendedNetworks(networks);
        vm.expectRevert(err);
        harness.externalRegenerateExtendedNetworks();
        assertFalse(vm.exists(string.concat(root, "/extended")), "a refused declaration wrote a record");
    }

    /// PROPERTY: the build refuses, before writing, an extended network at an address its init data does not derive.
    function testRegenerateExtendedNetworksRefusesAMisderivedAddress() external {
        ChainDeploy[] memory networks = new ChainDeploy[](1);
        networks[0] = extendedNetwork(8453, hex"00aa");
        address derived = networks[0].deployedAddress;
        networks[0].deployedAddress = address(0x1111111111111111111111111111111111111111);
        checkExtendedNetworksRefused(
            "misderived",
            networks,
            abi.encodeWithSelector(
                ExtendedNetworkAddressMismatch.selector,
                "per-network-clone@0_0_1",
                8453,
                derived,
                address(0x1111111111111111111111111111111111111111)
            )
        );
    }

    /// PROPERTY: the build refuses, before writing, an extended network the release records.
    function testRegenerateExtendedNetworksRefusesARecordedNetwork() external {
        ChainDeploy[] memory networks = new ChainDeploy[](1);
        networks[0] = extendedNetwork(
            PER_NETWORK_CLONE_POLYGON_CHAIN_ID, perNetworkCloneInitData(PER_NETWORK_CLONE_POLYGON_CHAIN_ID)
        );
        checkExtendedNetworksRefused(
            "recorded",
            networks,
            abi.encodeWithSelector(
                LibRainDeployClone.DuplicateCloneNetwork.selector, PER_NETWORK_CLONE_POLYGON_CHAIN_ID
            )
        );
    }

    /// PROPERTY: the build refuses, before writing, an extended network declared twice, which would write a record
    /// declaring one constant twice.
    function testRegenerateExtendedNetworksRefusesANetworkTwice() external {
        ChainDeploy[] memory networks = new ChainDeploy[](2);
        networks[0] = extendedNetwork(8453, hex"00aa");
        networks[1] = extendedNetwork(8453, hex"00bb");
        checkExtendedNetworksRefused(
            "twice", networks, abi.encodeWithSelector(LibRainDeployClone.DuplicateCloneNetwork.selector, 8453)
        );
    }

    /// PROPERTY: the build refuses, before writing, an extended network declared for a release that is not per
    /// network.
    function testRegenerateExtendedNetworksRefusesANonPerNetworkRelease() external {
        string memory root = string.concat(EXTENDED_NETWORKS_FIXTURE_ROOT, "-not-per-network");
        resetFixture(root);
        CloneBuildScriptHarness harness = new CloneBuildScriptHarness(root, root);
        ChainDeploy[] memory networks = new ChainDeploy[](1);
        networks[0] = extendedNetwork(8453, hex"00aa");
        harness.setExtendedNetworks(networks);
        vm.expectRevert(abi.encodeWithSelector(ExtendedNetworksUnexpected.selector, "example-clone@0_0_1"));
        harness.externalRegenerateExtendedNetworks();
        assertFalse(vm.exists(string.concat(root, "/extended")), "a refused declaration wrote a record");
    }
}
