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
import {LibRainDeployDeclaration} from "rain-deploy-0.1.29/src/lib/LibRainDeployDeclaration.sol";
import {
    FrozenSnapshotMechanismDataAmbiguous,
    FrozenSnapshotUnreadable,
    LibRainDeploySnapshot
} from "rain-deploy-0.1.29/src/lib/LibRainDeploySnapshot.sol";
import {
    LibRainDeployRegistryBeaconProxy,
    REGISTRY_BEACON_PROXY_ARTIFACT_PATH,
    RegistryBeaconProxyTarget
} from "../../../src/lib/LibRainDeployRegistryBeaconProxy.sol";
import {
    LibRainDeployCloneMechanism,
    REGISTRY_BEACON_PROXY_MECHANISM
} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {
    FrozenSnapshotBeaconProxyMarkerAmbiguous,
    FrozenSnapshotBeaconProxyMechanismDataMissing,
    LibRainDeployCloneSnapshot
} from "../../../src/lib/LibRainDeployCloneSnapshot.sol";
import {LibRegistryBeaconProxyTest} from "../../lib/LibRegistryBeaconProxyTest.sol";
import {MockCloneableV2} from "../../concrete/MockCloneableV2.sol";
import {perNetworkCloneLayers} from "../../abstract/PerNetworkCloneDeploys.sol";

/// @title LibRainDeployCloneSnapshotRegistryBeaconProxyTest
contract LibRainDeployCloneSnapshotRegistryBeaconProxyTest is Test, RainDeploySuitesBase {
    function declaration() internal view override returns (DeployDeclaration memory) {
        return perNetworkCloneLayers();
    }

    string constant ROOT = "fixture-lib/snapshot-registry-beacon-proxy";

    string constant MARKER_LINE = "bool constant REGISTRY_BEACON_PROXY = true;\n";

    string constant BEACON_MARKER_LINE = "bool constant BEACON_PROXY = true;\n";

    string constant MECHANISM_DATA_LINE = "bytes constant MECHANISM_DATA = hex\"01\";\n";

    string constant MARKER_BLOCK = "\n/// @dev Marks a registry beacon proxy record: its factory call resolves its\n"
        "/// beacon from a config registry.\nbool constant REGISTRY_BEACON_PROXY = true;\n";

    function externalRecordedMechanism(string memory path) external view returns (bytes32) {
        return LibRainDeployCloneSnapshot.recordedMechanismTag(
            vm, path, LibRainDeploySnapshot.recordLines(vm, path, vm.readFile(path))
        );
    }

    function externalRecordedMechanismId(string memory path) external view returns (bytes32) {
        return LibRainDeploySnapshot.recordedMechanismId(declaration(), vm, path);
    }

    function writeRecord(string memory name, string memory record) internal returns (string memory, string memory) {
        string memory dir = string.concat(ROOT, "/", name);
        string memory path = string.concat(dir, "/Record.sol");
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.createDir(dir, true);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.writeFile(path, record);
        return (dir, path);
    }

    function everyNetworkLine(address a) internal pure returns (string memory) {
        return string.concat("address constant DEPLOYED_ADDRESS = address(", vm.toString(a), ");\n");
    }

    function perNetworkLine(uint256 chainId, address a) internal pure returns (string memory) {
        return string.concat(
            "address constant DEPLOYED_ADDRESS_", vm.toString(chainId), " = address(", vm.toString(a), ");\n"
        );
    }

    function checkRefused(string memory name, string memory record, bytes4 selector) internal {
        (string memory dir, string memory path) = writeRecord(name, record);
        vm.expectRevert(abi.encodeWithSelector(selector, path));
        this.externalRecordedMechanism(path);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.removeDir(dir, true);
    }

    function checkRead(string memory name, string memory record, bytes32 expected) internal {
        (string memory dir, string memory path) = writeRecord(name, record);
        bytes32 read = this.externalRecordedMechanism(path);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.removeDir(dir, true);
        assertEq(read, expected);
    }

    function testTheRegistryMarkerReadsAsARegistryBeaconProxy() external {
        checkRead(
            "one",
            string.concat(MECHANISM_DATA_LINE, MARKER_LINE, everyNetworkLine(address(1))),
            REGISTRY_BEACON_PROXY_MECHANISM
        );
        checkRead(
            "one-marker-first",
            string.concat(MARKER_LINE, everyNetworkLine(address(1)), MECHANISM_DATA_LINE),
            REGISTRY_BEACON_PROXY_MECHANISM
        );
        checkRead(
            "unterminated-marker",
            string.concat(
                MECHANISM_DATA_LINE, everyNetworkLine(address(1)), "bool constant REGISTRY_BEACON_PROXY = true;"
            ),
            REGISTRY_BEACON_PROXY_MECHANISM
        );
    }

    function testTheRegistryMarkerWithoutMechanismDataIsRefused() external {
        checkRefused(
            "marker-no-data",
            string.concat(MARKER_LINE, everyNetworkLine(address(1))),
            FrozenSnapshotBeaconProxyMechanismDataMissing.selector
        );
        checkRefused(
            "marker-no-data-per-network",
            string.concat(perNetworkLine(137, address(2)), MARKER_LINE),
            FrozenSnapshotBeaconProxyMechanismDataMissing.selector
        );
    }

    function testTwoMarkersAreAmbiguous() external {
        checkRefused(
            "two-markers",
            string.concat(MARKER_LINE, MECHANISM_DATA_LINE, MARKER_LINE, everyNetworkLine(address(1))),
            FrozenSnapshotBeaconProxyMarkerAmbiguous.selector
        );
        checkRefused(
            "two-markers-no-data",
            string.concat(MARKER_LINE, MARKER_LINE, everyNetworkLine(address(1))),
            FrozenSnapshotBeaconProxyMarkerAmbiguous.selector
        );
        checkRefused(
            "registry-then-beacon",
            string.concat(MARKER_LINE, MECHANISM_DATA_LINE, BEACON_MARKER_LINE, everyNetworkLine(address(1))),
            FrozenSnapshotBeaconProxyMarkerAmbiguous.selector
        );
        checkRefused(
            "beacon-then-registry",
            string.concat(BEACON_MARKER_LINE, MECHANISM_DATA_LINE, MARKER_LINE, everyNetworkLine(address(1))),
            FrozenSnapshotBeaconProxyMarkerAmbiguous.selector
        );
        checkRefused(
            "registry-and-beacon-no-data",
            string.concat(MARKER_LINE, BEACON_MARKER_LINE, everyNetworkLine(address(1))),
            FrozenSnapshotBeaconProxyMarkerAmbiguous.selector
        );
    }

    function testTwoMechanismDataBesideTwoMarkersIsMechanismDataAmbiguity() external {
        checkRefused(
            "two-data-two-markers",
            string.concat(
                MARKER_LINE, MECHANISM_DATA_LINE, MARKER_LINE, MECHANISM_DATA_LINE, everyNetworkLine(address(1))
            ),
            FrozenSnapshotMechanismDataAmbiguous.selector
        );
    }

    function testAPerNetworkRegistryRecordIsUnreadable() external {
        checkRefused(
            "per-network",
            string.concat(
                perNetworkLine(137, address(2)), MARKER_LINE, MECHANISM_DATA_LINE, perNetworkLine(42161, address(3))
            ),
            FrozenSnapshotUnreadable.selector
        );
        checkRefused(
            "per-network-one",
            string.concat(MECHANISM_DATA_LINE, MARKER_LINE, perNetworkLine(137, address(2))),
            FrozenSnapshotUnreadable.selector
        );
    }

    function testAStrayMentionOfTheRegistryMarkerIsUnreadable() external {
        string[8] memory strays = [
            "bool constant REGISTRY_BEACON_PROXY = false;\n",
            "bool constant REGISTRY_BEACON_PROXY=true;\n",
            "/// REGISTRY_BEACON_PROXY\n",
            "bool constant REGISTRY_BEACON_PROXY = true; \n",
            " bool constant REGISTRY_BEACON_PROXY = true;\n",
            "// bool constant REGISTRY_BEACON_PROXY = true;\n",
            "uint256 constant NOT_REGISTRY_BEACON_PROXY = 1;\n",
            "bool constant REGISTRY_BEACON_PROXY_V2 = true;\n"
        ];
        for (uint256 i = 0; i < strays.length; i++) {
            checkRefused(
                string.concat("stray-", vm.toString(i)),
                string.concat(MECHANISM_DATA_LINE, strays[i], everyNetworkLine(address(1))),
                FrozenSnapshotUnreadable.selector
            );
        }
    }

    function testTheRegistryMarkerOnTheMechanismDataLineIsUnreadable() external {
        checkRefused(
            "marker-on-mechanism-data-line",
            string.concat(
                "bytes constant MECHANISM_DATA = hex\"01\"; bool constant REGISTRY_BEACON_PROXY = true;\n",
                everyNetworkLine(address(1))
            ),
            FrozenSnapshotUnreadable.selector
        );
    }

    function registryBeaconProxySuite() internal returns (DeploySuite memory) {
        RegistryBeaconProxyTarget memory target = LibRegistryBeaconProxyTest.live(
            vm, address(new MockCloneableV2()), address(this), hex"deadbeef", bytes32(uint256(7))
        );
        DeploySuite memory suite =
        LibRainDeployCloneMechanism.registryBeaconProxyCandidate(
            LibRegistryBeaconProxyTest.declared(
                "registry-beacon-proxy", target, LibRegistryBeaconProxyTest.runtimeOf(vm, target)
            )
        )
        .snapshot;
        suite.networks = declaration().networks;
        return suite;
    }

    function occurrences(string memory haystack, string memory needle) internal pure returns (uint256) {
        return vm.split(haystack, needle).length - 1;
    }

    function recordedBytes(string memory path, string memory record, string memory name)
        internal
        pure
        returns (bytes memory)
    {
        string[] memory lines = LibRainDeploySnapshot.recordLines(vm, path, record);
        string memory prefix = string.concat("bytes constant ", name, " =");
        for (uint256 i = 0; i < lines.length; i++) {
            if (vm.indexOf(lines[i], prefix) == 0) {
                (bool readable, string memory value) = LibRainDeploySnapshot.declarationValue(vm, lines, i, "    hex\"");
                assertTrue(readable, name);
                return vm.parseBytes(vm.replace(vm.replace(value, "hex\"", "0x"), "\";", ""));
            }
        }
        revert(string.concat(name, " undeclared"));
    }

    function testTheWriterMarksARegistryBeaconProxyAndReleasesIt() external {
        DeploySuite memory suite = registryBeaconProxySuite();
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.createDir(string.concat(ROOT, "/0_0_1"), true);
        string memory path = writeSuiteSnapshot(
            declaration(),
            vm,
            SnapshotFile(ROOT, "0_0_1", "RegistryBeaconProxyRecord", RAIN_SPDX_LICENSE_IDENTIFIER, RAIN_COPYRIGHT_TEXT),
            suite
        );
        string memory record = vm.readFile(path);
        assertEq(suite.storedDeployedAddress.code.length, 0);

        assertEq(occurrences(record, MARKER_LINE), 1);
        assertEq(occurrences(record, MARKER_BLOCK), 1);
        assertEq(
            occurrences(
                record,
                string.concat(MARKER_BLOCK, "\n/// @dev The deterministic deploy address of the registry beacon proxy")
            ),
            1
        );
        assertEq(occurrences(record, string.concat(";\n", MARKER_BLOCK)), 1);
        assertEq(occurrences(record, BEACON_MARKER_LINE), 0);
        assertFalse(vm.contains(record, "Marks a beacon proxy record"));

        assertTrue(
            vm.contains(
                record,
                "/// @dev The deterministic deploy address of the registry beacon proxy, through\n"
                "/// its factory's registry-beacon-proxy open salt.\n"
            )
        );
        assertTrue(
            vm.contains(
                record,
                "/// @dev The registry beacon proxy factory call this release was cut with: the\n"
                "/// tagged `abi.encode`d `RegistryBeaconProxyTarget` a released suite carries\n"
                "/// as its `mechanismData`.\n"
            )
        );
        assertFalse(vm.contains(record, "EIP-1167"));
        assertFalse(vm.contains(record, "clone factory"));
        assertFalse(vm.contains(record, "`CloneTarget`"));
        assertFalse(vm.contains(record, "`CloneNetworks`"));
        assertFalse(vm.contains(record, "factory's beacon-proxy open salt"));

        (uint256[] memory chainIds, address[] memory addresses) =
            LibRainDeploySnapshot.recordedDeployedAddresses(vm, path, record);
        assertEq(chainIds.length, 0);
        assertEq(addresses.length, 1);
        assertEq(addresses[0], suite.storedDeployedAddress);
        assertEq(
            addresses[0],
            LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(
                LibRainDeployCloneMechanism.registryBeaconProxyTarget(suite)
            )
        );
        assertEq(recordedBytes(path, record, "RUNTIME_CODE"), suite.storedRuntimeCode);
        assertEq(recordedBytes(path, record, "CREATION_CODE"), suite.creationCode);
        assertEq(recordedBytes(path, record, "MECHANISM_DATA"), suite.mechanismData);
        assertEq(
            LibRainDeployCloneMechanism.mechanismTag(recordedBytes(path, record, "MECHANISM_DATA")),
            REGISTRY_BEACON_PROXY_MECHANISM
        );

        assertEq(this.externalRecordedMechanism(path), REGISTRY_BEACON_PROXY_MECHANISM);
        assertEq(this.externalRecordedMechanismId(path), REGISTRY_BEACON_PROXY_MECHANISM);

        string memory imported = LibRainDeploySnapshot.releasedImport(vm, path);
        assertTrue(vm.contains(imported, "DEPLOYED_ADDRESS as RegistryBeaconProxyRecord_0_0_1_DEPLOYED_ADDRESS"));
        assertTrue(vm.contains(imported, "MECHANISM_DATA as RegistryBeaconProxyRecord_0_0_1_MECHANISM_DATA"));

        string memory entry = LibRainDeploySnapshot.releasedSuiteEntry(vm, 0, path, suite, declaration());
        assertTrue(vm.contains(entry, "storedDeployedAddress: RegistryBeaconProxyRecord_0_0_1_DEPLOYED_ADDRESS,\n"));
        assertTrue(vm.contains(entry, "mechanismData: RegistryBeaconProxyRecord_0_0_1_MECHANISM_DATA,\n"));
        assertTrue(vm.contains(entry, string.concat("artifactPath: \"", REGISTRY_BEACON_PROXY_ARTIFACT_PATH, "\"")));
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.removeDir(string.concat(ROOT, "/0_0_1"), true);
    }

    function testTheRegistryBeaconProxyReleasedImportNamesItsOwnTag() external view {
        DeployDeclaration memory d = declaration();
        assertEq(
            LibRainDeployDeclaration.mechanismById(d, REGISTRY_BEACON_PROXY_MECHANISM, "").releasedImport(d, ""),
            "import {REGISTRY_BEACON_PROXY_MECHANISM} from \"../lib/LibRainDeployCloneMechanism.sol\";\n"
        );
        assertEq(
            LibRainDeployCloneSnapshot.releasedMechanismDataExpression(REGISTRY_BEACON_PROXY_MECHANISM, "P"),
            "abi.encode(REGISTRY_BEACON_PROXY_MECHANISM, P_MECHANISM_DATA)"
        );
    }
}
