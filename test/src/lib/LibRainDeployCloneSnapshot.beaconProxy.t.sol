// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/UpgradeableBeacon.sol";
import {
    DeployDeclaration,
    DeploySuite,
    RainDeploySuitesBase,
    SnapshotFile
} from "rain-deploy-0.1.27/src/abstract/RainDeploySuitesBase.sol";
import {RAIN_COPYRIGHT_TEXT, RAIN_SPDX_LICENSE_IDENTIFIER} from "rain-sol-codegen-0.1.39/src/lib/LibCodeGen.sol";
import {
    FrozenSnapshotMechanismDataAmbiguous,
    FrozenSnapshotUnreadable,
    LibRainDeploySnapshot
} from "rain-deploy-0.1.27/src/lib/LibRainDeploySnapshot.sol";
import {LibRainDeployClone} from "../../../src/lib/LibRainDeployClone.sol";
import {BEACON_PROXY_ARTIFACT_PATH, BeaconProxyDeploy} from "../../../src/lib/LibRainDeployBeaconProxy.sol";
import {
    BEACON_PROXY_MECHANISM,
    BEACON_PROXY_PER_NETWORK_MECHANISM,
    CLONE_MECHANISM,
    CLONE_PER_NETWORK_MECHANISM,
    LibRainDeployCloneMechanism
} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {
    FrozenSnapshotBeaconProxyMarkerAmbiguous,
    FrozenSnapshotBeaconProxyMechanismDataMissing,
    LibRainDeployCloneSnapshot
} from "../../../src/lib/LibRainDeployCloneSnapshot.sol";
import {LibRainDeploy} from "rain-deploy-0.1.27/src/lib/LibRainDeploy.sol";
import {MockBeaconProxyFactory} from "../../concrete/MockBeaconProxyFactory.sol";
import {MockCloneableV2} from "../../concrete/MockCloneableV2.sol";
import {exampleCloneImplementation} from "../../abstract/ExampleCloneDeploys.sol";
import {
    PER_NETWORK_CLONE_ARBITRUM_ONE_CHAIN_ID,
    PER_NETWORK_CLONE_POLYGON_CHAIN_ID,
    perNetworkClone,
    perNetworkCloneChainIds,
    perNetworkCloneLayers
} from "../../abstract/PerNetworkCloneDeploys.sol";
import {LibBeaconProxyTest} from "../../lib/LibBeaconProxyTest.sol";

/// @title LibRainDeployCloneSnapshotBeaconProxyTest
/// @notice The beacon proxy record marker: what the writer emits, how `recordedMechanism` reads it,
/// and the released lib entries it produces; and the chain id each per-network address is written under.
contract LibRainDeployCloneSnapshotBeaconProxyTest is Test, RainDeploySuitesBase {
    function declaration() internal view override returns (DeployDeclaration memory) {
        return perNetworkCloneLayers();
    }

    string constant ROOT = "fixture-lib/snapshot-beacon-proxy";

    string constant MARKER_LINE = "bool constant BEACON_PROXY = true;\n";

    string constant MECHANISM_DATA_LINE = "bytes constant MECHANISM_DATA = hex\"01\";\n";

    string constant MARKER_BLOCK = "\n/// @dev Marks a beacon proxy record: its factory call's `implementation` is the\n"
        "/// beacon.\nbool constant BEACON_PROXY = true;\n";

    /// @param path The record.
    /// @return The mechanism it was cut with.
    function externalRecordedMechanism(string memory path) external view returns (bytes32) {
        return LibRainDeployCloneSnapshot.recordedMechanismTag(
            vm, path, LibRainDeploySnapshot.recordLines(vm, path, vm.readFile(path))
        );
    }

    /// Writes `record` as the one file of a test's own directory.
    /// @param name The test's directory under `ROOT`.
    /// @param record The record's contents.
    /// @return The directory and the record file.
    function writeRecord(string memory name, string memory record) internal returns (string memory, string memory) {
        string memory dir = string.concat(ROOT, "/", name);
        string memory path = string.concat(dir, "/Record.sol");
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.createDir(dir, true);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.writeFile(path, record);
        return (dir, path);
    }

    /// @param a The address.
    /// @return `address constant DEPLOYED_ADDRESS = address(<a>);`, newline-terminated.
    function everyNetworkLine(address a) internal pure returns (string memory) {
        return string.concat("address constant DEPLOYED_ADDRESS = address(", vm.toString(a), ");\n");
    }

    /// @param chainId The chain id.
    /// @param a The address.
    /// @return `address constant DEPLOYED_ADDRESS_<chainId> = address(<a>);`, newline-terminated.
    function perNetworkLine(uint256 chainId, address a) internal pure returns (string memory) {
        return string.concat(
            "address constant DEPLOYED_ADDRESS_", vm.toString(chainId), " = address(", vm.toString(a), ");\n"
        );
    }

    /// @param name The test's directory under `ROOT`.
    /// @param record The record's contents.
    /// @param selector The refusal expected, naming the file.
    function checkRefused(string memory name, string memory record, bytes4 selector) internal {
        (string memory dir, string memory path) = writeRecord(name, record);
        vm.expectRevert(abi.encodeWithSelector(selector, path));
        this.externalRecordedMechanism(path);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.removeDir(dir, true);
    }

    /// @param name The test's directory under `ROOT`.
    /// @param record The record's contents.
    /// @param expected The mechanism expected.
    function checkRead(string memory name, string memory record, bytes32 expected) internal {
        (string memory dir, string memory path) = writeRecord(name, record);
        bytes32 read = this.externalRecordedMechanism(path);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.removeDir(dir, true);
        assertEq(read, expected);
    }

    /// The marker beside `MECHANISM_DATA` reads as a beacon proxy, one-address or per-network by
    /// the address declarations, wherever it sits among the lines.
    function testTheMarkerReadsAsABeaconProxy() external {
        checkRead(
            "one", string.concat(MECHANISM_DATA_LINE, MARKER_LINE, everyNetworkLine(address(1))), BEACON_PROXY_MECHANISM
        );
        checkRead(
            "one-marker-first",
            string.concat(MARKER_LINE, everyNetworkLine(address(1)), MECHANISM_DATA_LINE),
            BEACON_PROXY_MECHANISM
        );
        checkRead(
            "per-network",
            string.concat(
                perNetworkLine(137, address(2)), MARKER_LINE, MECHANISM_DATA_LINE, perNetworkLine(42161, address(3))
            ),
            BEACON_PROXY_PER_NETWORK_MECHANISM
        );
    }

    /// The same records without the marker read as clones.
    function testNoMarkerReadsAsAClone() external {
        checkRead("clone", string.concat(MECHANISM_DATA_LINE, everyNetworkLine(address(1))), CLONE_MECHANISM);
        checkRead(
            "clone-per-network",
            string.concat(perNetworkLine(137, address(2)), MECHANISM_DATA_LINE, perNetworkLine(42161, address(3))),
            CLONE_PER_NETWORK_MECHANISM
        );
    }

    /// A marker without `MECHANISM_DATA` is refused, one-address or per-network.
    function testTheMarkerWithoutMechanismDataIsRefused() external {
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

    /// Two markers are refused as ambiguous, with or without `MECHANISM_DATA`.
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
    }

    /// Two `MECHANISM_DATA` declarations beside two markers are refused as `MECHANISM_DATA` ambiguity, which is
    /// checked before the marker's.
    function testTwoMechanismDataBesideTwoMarkersIsMechanismDataAmbiguity() external {
        checkRefused(
            "two-data-two-markers",
            string.concat(
                MARKER_LINE, MECHANISM_DATA_LINE, MARKER_LINE, MECHANISM_DATA_LINE, everyNetworkLine(address(1))
            ),
            FrozenSnapshotMechanismDataAmbiguous.selector
        );
    }

    /// A line naming `BEACON_PROXY` that is not exactly the marker is refused as unreadable, whether
    /// solc would read it as the marker, as another value, or not at all.
    function testAStrayMentionOfTheMarkerIsUnreadable() external {
        string[7] memory strays = [
            "bool constant BEACON_PROXY = false;\n",
            "bool constant BEACON_PROXY=true;\n",
            "/// BEACON_PROXY\n",
            "bool constant BEACON_PROXY = true; \n",
            " bool constant BEACON_PROXY = true;\n",
            "// bool constant BEACON_PROXY = true;\n",
            "uint256 constant NOT_BEACON_PROXY = 1;\n"
        ];
        for (uint256 i = 0; i < strays.length; i++) {
            checkRefused(
                string.concat("stray-", vm.toString(i)),
                string.concat(MECHANISM_DATA_LINE, strays[i], everyNetworkLine(address(1))),
                FrozenSnapshotUnreadable.selector
            );
        }
    }

    /// The marker sharing the `MECHANISM_DATA` declaration's line is refused as unreadable, though solc
    /// would read both declarations.
    function testTheMarkerOnTheMechanismDataLineIsUnreadable() external {
        checkRefused(
            "marker-on-mechanism-data-line",
            string.concat(
                "bytes constant MECHANISM_DATA = hex\"01\"; bool constant BEACON_PROXY = true;\n",
                everyNetworkLine(address(1))
            ),
            FrozenSnapshotUnreadable.selector
        );
    }

    /// A beacon proxy candidate over a fresh factory and beacon, both declared as its dependencies.
    /// @param initDataPerNetwork Whether the init data is per network.
    /// @return The candidate's suite.
    function beaconProxySuite(bool initDataPerNetwork) internal returns (DeploySuite memory) {
        address beacon = address(new UpgradeableBeacon(address(new MockCloneableV2()), address(this)));
        DeploySuite memory suite =
        LibRainDeployCloneMechanism.beaconProxyCandidate(
            LibBeaconProxyTest.declared(
                "beacon-proxy",
                address(new MockBeaconProxyFactory()),
                beacon,
                hex"deadbeef",
                initDataPerNetwork,
                bytes32(uint256(7)),
                LibBeaconProxyTest.runtimeOf(vm, beacon)
            ),
            perNetworkCloneChainIds()
        )
        .snapshot;
        suite.networks = declaration().networks;
        return suite;
    }

    /// Writes `suite`'s record under `ROOT/<tag>`, and returns what it reads back as.
    /// @param tag The record's tag directory.
    /// @param suite The suite.
    /// @return The record's path.
    function writeBeaconProxyRecord(string memory tag, DeploySuite memory suite) internal returns (string memory) {
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.createDir(string.concat(ROOT, "/", tag), true);
        return writeSuiteSnapshot(
            declaration(),
            vm,
            SnapshotFile(ROOT, tag, "BeaconProxyRecord", RAIN_SPDX_LICENSE_IDENTIFIER, RAIN_COPYRIGHT_TEXT),
            suite
        );
    }

    /// @param haystack The text.
    /// @param needle What to count.
    /// @return How many times `needle` occurs in `haystack`.
    function occurrences(string memory haystack, string memory needle) internal pure returns (uint256) {
        return vm.split(haystack, needle).length - 1;
    }

    /// A one-address beacon proxy's record carries the marker once, a blank line below the declaration
    /// before it, under its doc comment and directly above its address constant, reads back as a
    /// beacon proxy, and is released as one, at its recorded address.
    function testTheWriterMarksAOneAddressBeaconProxyAndReleasesIt() external {
        DeploySuite memory suite = beaconProxySuite(false);
        string memory path = writeBeaconProxyRecord("0_0_1", suite);
        string memory record = vm.readFile(path);
        assertEq(occurrences(record, MARKER_LINE), 1);
        assertEq(occurrences(record, MARKER_BLOCK), 1);
        assertEq(
            occurrences(
                record, string.concat(MARKER_BLOCK, "\n/// @dev The deterministic deploy address of the beacon proxy")
            ),
            1
        );
        assertEq(occurrences(record, string.concat(";\n", MARKER_BLOCK)), 1);
        assertEq(this.externalRecordedMechanism(path), BEACON_PROXY_MECHANISM);
        assertTrue(
            vm.contains(
                record,
                "/// @dev The deterministic deploy address of the beacon proxy, through its\n/// factory's beacon-proxy open salt."
            )
        );
        assertTrue(
            vm.contains(
                record,
                "/// @dev The beacon proxy factory call this release was cut with: the\n/// tagged `abi.encode`d `CloneTarget`"
            )
        );
        assertFalse(vm.contains(record, "EIP-1167"));
        assertFalse(vm.contains(record, "clone factory"));

        string memory imported = LibRainDeploySnapshot.releasedImport(vm, path);
        assertTrue(vm.contains(imported, "DEPLOYED_ADDRESS as BeaconProxyRecord_0_0_1_DEPLOYED_ADDRESS"));
        assertTrue(vm.contains(imported, "MECHANISM_DATA as BeaconProxyRecord_0_0_1_MECHANISM_DATA"));

        string memory entry = LibRainDeploySnapshot.releasedSuiteEntry(vm, 0, path, suite, declaration());
        assertTrue(vm.contains(entry, "storedDeployedAddress: BeaconProxyRecord_0_0_1_DEPLOYED_ADDRESS,\n"));
        assertTrue(vm.contains(entry, "mechanismData: BeaconProxyRecord_0_0_1_MECHANISM_DATA,\n"));
        assertTrue(vm.contains(entry, string.concat("artifactPath: \"", BEACON_PROXY_ARTIFACT_PATH, "\"")));
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.removeDir(string.concat(ROOT, "/0_0_1"), true);
    }

    /// A per-network beacon proxy's record carries the marker once, a blank line below the declaration
    /// before it, under its doc comment and directly above its address constants, reads back as a
    /// per-network beacon proxy, and is released as one, with no stored address.
    function testTheWriterMarksAPerNetworkBeaconProxyAndReleasesIt() external {
        DeploySuite memory suite = beaconProxySuite(true);
        string memory path = writeBeaconProxyRecord("0_0_2", suite);
        string memory record = vm.readFile(path);
        assertEq(occurrences(record, MARKER_LINE), 1);
        assertEq(occurrences(record, MARKER_BLOCK), 1);
        assertEq(
            occurrences(
                record, string.concat(MARKER_BLOCK, "\n/// @dev The deterministic deploy address of the beacon proxy")
            ),
            1
        );
        assertEq(occurrences(record, string.concat(";\n", MARKER_BLOCK)), 1);
        assertEq(this.externalRecordedMechanism(path), BEACON_PROXY_PER_NETWORK_MECHANISM);
        assertTrue(
            vm.contains(record, "/// @dev The deterministic deploy address of the beacon proxy on chain id\n/// 42161,")
        );
        assertTrue(
            vm.contains(record, "/// @dev The deterministic deploy address of the beacon proxy on chain id\n/// 137,")
        );
        assertEq(occurrences(record, "through its factory's beacon-proxy open salt with that network's init data."), 2);
        assertTrue(
            vm.contains(
                record,
                "/// @dev The beacon proxy factory call this release was cut with: the\n/// tagged `abi.encode`d `CloneNetworks`"
            )
        );
        assertFalse(vm.contains(record, "EIP-1167"));
        assertFalse(vm.contains(record, "clone factory"));

        string memory imported = LibRainDeploySnapshot.releasedImport(vm, path);
        assertFalse(vm.contains(imported, "DEPLOYED_ADDRESS as"));
        assertTrue(vm.contains(imported, "MECHANISM_DATA as BeaconProxyRecord_0_0_2_MECHANISM_DATA"));

        string memory entry = LibRainDeploySnapshot.releasedSuiteEntry(vm, 0, path, suite, declaration());
        assertTrue(vm.contains(entry, "storedDeployedAddress: address(0),\n"));
        assertTrue(vm.contains(entry, "mechanismData: BeaconProxyRecord_0_0_2_MECHANISM_DATA,\n"));
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.removeDir(string.concat(ROOT, "/0_0_2"), true);
    }

    /// @param chainIds The payload's networks.
    /// @param networks The suite's `networks`.
    /// @return A per-network clone suite.
    function perNetworkCloneSuite(uint256[] memory chainIds, string[] memory networks)
        internal
        view
        returns (DeploySuite memory)
    {
        DeploySuite memory suite =
        LibRainDeployCloneMechanism.cloneCandidate(perNetworkClone("per-network-clone", bytes32(uint256(4))), chainIds)
        .snapshot;
        suite.networks = networks;
        return suite;
    }

    /// @param path The record file.
    /// @param record Its contents.
    /// @param name A `bytes` constant it declares.
    /// @return The constant's value.
    function recordedBytes(string memory path, string memory record, string memory name)
        internal
        pure
        returns (bytes memory)
    {
        string[] memory lines = LibRainDeploySnapshot.recordLines(vm, path, record);
        string memory prefix = string.concat("bytes constant ", name, " =");
        for (uint256 i = 0; i < lines.length; i++) {
            if (vm.indexOf(lines[i], prefix) == 0) {
                (bool readable, string memory value) =
                    LibRainDeploySnapshot.declarationValue(vm, lines, i, "    hex\"");
                assertTrue(readable, name);
                return vm.parseBytes(vm.replace(vm.replace(value, "hex\"", "0x"), "\";", ""));
            }
        }
        revert(string.concat(name, " undeclared"));
    }

    /// Writes `suite`'s record under `ROOT/<tag>` and checks each payload network's address and the runtime code.
    /// @param tag The record's tag directory.
    /// @param chainIds The payload's networks, in payload order.
    /// @param suite The suite.
    function checkPerNetworkRecord(string memory tag, uint256[] memory chainIds, DeploySuite memory suite) internal {
        string memory path = LibRainDeployCloneSnapshot.writeSuiteSnapshot(
            declaration(),
            vm,
            SnapshotFile(ROOT, tag, "PerNetworkCloneRecord", RAIN_SPDX_LICENSE_IDENTIFIER, RAIN_COPYRIGHT_TEXT),
            suite
        );
        string memory record = vm.readFile(path);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.removeDir(string.concat(ROOT, "/", tag), true);
        (uint256[] memory recordedChainIds, address[] memory addresses) =
            LibRainDeploySnapshot.recordedDeployedAddresses(vm, path, record);
        assertEq(recordedChainIds, chainIds);
        for (uint256 i = 0; i < chainIds.length; i++) {
            assertEq(addresses[i], LibRainDeployCloneMechanism.deployedAddress(declaration(), suite, chainIds[i]));
        }
        assertNotEq(addresses[0], addresses[1]);
        assertEq(
            recordedBytes(path, record, "RUNTIME_CODE"),
            LibRainDeployClone.cloneRuntimeCode(exampleCloneImplementation())
        );
    }

    /// @return Polygon's chain id, then Arbitrum One's.
    function polygonThenArbitrum() internal pure returns (uint256[] memory) {
        uint256[] memory chainIds = new uint256[](2);
        chainIds[0] = PER_NETWORK_CLONE_POLYGON_CHAIN_ID;
        chainIds[1] = PER_NETWORK_CLONE_ARBITRUM_ONE_CHAIN_ID;
        return chainIds;
    }

    /// A payload ordered unlike the suite's networks still records each network's own address.
    function testPerNetworkRecordPairsAddressesByChainIdNotPosition() external {
        string[] memory networks = new string[](2);
        networks[0] = LibRainDeploy.ARBITRUM_ONE;
        networks[1] = LibRainDeploy.POLYGON;
        checkPerNetworkRecord("0_0_3", polygonThenArbitrum(), perNetworkCloneSuite(polygonThenArbitrum(), networks));
    }

    /// A first suite network the payload lacks deploys nothing, so the code is read from a network that deployed.
    function testPerNetworkRecordWhoseFirstNetworkIsUnrecordedReadsCodeFromADeployedAddress() external {
        string[] memory networks = new string[](3);
        networks[0] = LibRainDeploy.BASE;
        networks[1] = LibRainDeploy.ARBITRUM_ONE;
        networks[2] = LibRainDeploy.POLYGON;
        checkPerNetworkRecord(
            "0_0_4", perNetworkCloneChainIds(), perNetworkCloneSuite(perNetworkCloneChainIds(), networks)
        );
    }

    /// A payload network the suite does not deploy to records the address derived for it.
    function testPerNetworkRecordDerivesTheAddressOfAPayloadNetworkTheSuiteDoesNotDeployTo() external {
        string[] memory networks = new string[](1);
        networks[0] = LibRainDeploy.ARBITRUM_ONE;
        checkPerNetworkRecord(
            "0_0_5", perNetworkCloneChainIds(), perNetworkCloneSuite(perNetworkCloneChainIds(), networks)
        );
    }
}
