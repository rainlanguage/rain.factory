// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.17.0/src/Vm.sol";
import {LibCodeGen} from "rain-sol-codegen-0.1.39/src/lib/LibCodeGen.sol";
import {LibFs} from "rain-sol-codegen-0.1.39/src/lib/LibFs.sol";
import {DeployDeclaration, DeploySuite, SnapshotFile} from "rain-deploy-0.1.27/src/abstract/RainDeploySuitesBase.sol";
import {
    FrozenSnapshotMechanismDataAmbiguous,
    FrozenSnapshotMechanismDataMissing,
    FrozenSnapshotUnreadable,
    LibRainDeploySnapshot
} from "rain-deploy-0.1.27/src/lib/LibRainDeploySnapshot.sol";
import {CloneNetworks} from "./LibRainDeployClone.sol";
import {
    BEACON_PROXY_MECHANISM,
    BEACON_PROXY_PER_NETWORK_MECHANISM,
    CLONE_MECHANISM,
    CLONE_PER_NETWORK_MECHANISM,
    LibRainDeployCloneMechanism
} from "./LibRainDeployCloneMechanism.sol";

/// Thrown when the state snapshot taken around a clone snapshot's local deploy could not be
/// reverted.
/// @param suite The suite whose snapshot was being written.
/// @param snapshotId The state snapshot that could not be reverted.
error SnapshotStateRevertFailed(string suite, uint256 snapshotId);

/// Thrown when a file in the frozen record carries the `BEACON_PROXY` marker more than once.
/// @param path The record file.
error FrozenSnapshotBeaconProxyMarkerAmbiguous(string path);

/// Thrown when a file in the frozen record carries the `BEACON_PROXY` marker and declares no `MECHANISM_DATA`.
/// @param path The record file.
error FrozenSnapshotBeaconProxyMechanismDataMissing(string path);

/// @title LibRainDeployCloneSnapshot
/// @notice The record a clone or beacon proxy release is frozen as, and how a released-suites lib reads it back.
/// The record carries the untagged payload as `MECHANISM_DATA`, the `BEACON_PROXY` marker for a beacon proxy and
/// `DEPLOYED_ADDRESS_<chainId>` for one per network; those three say which tag the released suite carries.
library LibRainDeployCloneSnapshot {
    /// This package's soldeer name: the remapping prefix a consumer reaches it by.
    string constant PACKAGE_NAME = "rain-factory";

    string constant SOURCE_ROOT = "src";

    /// Where the mechanism constants are declared, below `SOURCE_ROOT`.
    string constant CLONE_MECHANISM_SOURCE_SUBPATH = "lib/LibRainDeployCloneMechanism.sol";

    /// The name of the beacon proxy marker. A line holding it anywhere but as the writer's declaration of it is not
    /// the writer's.
    string constant BEACON_PROXY_NAME = "BEACON_PROXY";

    string constant BEACON_PROXY_DECLARATION = "bool constant BEACON_PROXY = true;";

    /// The marker a beacon proxy record carries, as the writer emits it.
    string constant BEACON_PROXY_MARKER = "\n/// @dev Marks a beacon proxy record: its factory call's `implementation` is the\n"
        "/// beacon.\nbool constant BEACON_PROXY = true;\n";

    /// The record body of a clone or beacon proxy suite deployed locally at `deployed`.
    /// @param vm The Vm instance for string operations.
    /// @param deployed Where it was deployed, in its address order.
    /// @param suite The suite.
    /// @return The record's constants.
    function cloneSnapshotConstants(Vm vm, address[] memory deployed, DeploySuite memory suite)
        internal
        view
        returns (string memory)
    {
        bool beaconProxy = LibRainDeployCloneMechanism.isBeaconProxy(suite);
        string memory addressConstants;
        string memory mechanismDataComment;
        if (LibRainDeployCloneMechanism.isPerNetwork(suite)) {
            addressConstants = perNetworkAddressConstants(vm, deployed, suite);
            mechanismDataComment = beaconProxy
                ? "/// @dev The beacon proxy factory call this release was cut with: the\n"
                "/// tagged `abi.encode`d `CloneNetworks` a released suite carries as its\n" "/// `mechanismData`."
                : "/// @dev The clone factory call this release was cut with: the\n"
                "/// tagged `abi.encode`d `CloneNetworks` a released suite carries as its\n" "/// `mechanismData`.";
        } else {
            addressConstants = LibCodeGen.addressConstantString(
                vm,
                beaconProxy
                    ? "/// @dev The deterministic deploy address of the beacon proxy, through its\n"
                    "/// factory's beacon-proxy open salt."
                    : "/// @dev The deterministic deploy address of the EIP-1167 clone, through its\n"
                    "/// factory's open salt.",
                "DEPLOYED_ADDRESS",
                deployed[0]
            );
            mechanismDataComment = beaconProxy
                ? "/// @dev The beacon proxy factory call this release was cut with: the\n"
                "/// tagged `abi.encode`d `CloneTarget` a released suite carries as its\n" "/// `mechanismData`."
                : "/// @dev The clone factory call this release was cut with: the\n"
                "/// tagged `abi.encode`d `CloneTarget` a released suite carries as its\n" "/// `mechanismData`.";
        }
        return string.concat(
            beaconProxy ? BEACON_PROXY_MARKER : "",
            addressConstants,
            LibCodeGen.bytesConstantString(
                vm, "/// @dev The creation bytecode of the contract.", "CREATION_CODE", suite.creationCode
            ),
            LibCodeGen.bytesConstantString(
                vm, "/// @dev The runtime bytecode of the contract.", "RUNTIME_CODE", deployed[0].code
            ),
            LibCodeGen.bytesConstantString(
                vm,
                "/// @dev What MUST already be on a network before this release can be\n"
                "/// broadcast there: an address, and the runtime code that belongs at it.\n"
                "/// `abi.encode`d as a `DeployDependency[]` because Solidity has no\n"
                "/// file-scope constant of dynamic array type.",
                "DEPENDENCIES",
                abi.encode(suite.dependencies)
            ),
            LibCodeGen.bytesConstantString(vm, mechanismDataComment, "MECHANISM_DATA", suite.mechanismData)
        );
    }

    /// @param vm The Vm instance for string operations.
    /// @param deployed Where a per-network suite was deployed, in its address order.
    /// @param suite The suite.
    /// @return Its `DEPLOYED_ADDRESS_<chainId>` constants.
    function perNetworkAddressConstants(Vm vm, address[] memory deployed, DeploySuite memory suite)
        internal
        pure
        returns (string memory)
    {
        CloneNetworks memory clones = LibRainDeployCloneMechanism.cloneNetworks(suite);
        string memory addressConstants = "";
        bool beaconProxy = LibRainDeployCloneMechanism.isBeaconProxy(suite);
        for (uint256 i = 0; i < clones.networks.length; i++) {
            string memory chainId = vm.toString(clones.networks[i].chainId);
            addressConstants = string.concat(
                addressConstants,
                LibCodeGen.addressConstantString(
                    vm,
                    string.concat(
                        beaconProxy
                            ? "/// @dev The deterministic deploy address of the beacon proxy on chain id\n/// "
                            : "/// @dev The deterministic deploy address of the EIP-1167 clone on chain id\n/// ",
                        chainId,
                        beaconProxy
                            ? ", through its factory's beacon-proxy open salt with that network's init data."
                            : ", through its factory's open salt with that network's init data."
                    ),
                    string.concat("DEPLOYED_ADDRESS_", chainId),
                    deployed[i]
                )
            );
        }
        return addressConstants;
    }

    /// Writes the record of a clone or beacon proxy suite deployed locally at `deployed` into `snapshotDir`.
    /// @param vm The Vm instance for file operations.
    /// @param snapshotDir The checked directory to write into.
    /// @param contractName The contract the snapshot describes.
    /// @param spdxLicenseIdentifier The SPDX licence identifier the written snapshot declares.
    /// @param copyrightText The copyright text the written snapshot declares.
    /// @param suite The suite.
    /// @param deployed Where it was deployed, in its address order.
    function writeCloneSnapshotFile(
        Vm vm,
        string memory snapshotDir,
        string memory contractName,
        string memory spdxLicenseIdentifier,
        string memory copyrightText,
        DeploySuite memory suite,
        address[] memory deployed
    ) internal {
        LibFs.buildFileForContract(
            vm,
            deployed[0],
            snapshotDir,
            contractName,
            spdxLicenseIdentifier,
            copyrightText,
            cloneSnapshotConstants(vm, deployed, suite)
        );
    }

    /// The tag a frozen record's markers say its release carries; zero for a record with no `MECHANISM_DATA`.
    /// @param vm The Vm instance for string operations.
    /// @param path The record file the lines were read from.
    /// @param lines Its `recordLines`.
    /// @return The tag.
    function recordedMechanismTag(Vm vm, string memory path, string[] memory lines)
        internal
        pure
        returns (bytes32)
    {
        (uint256[] memory chainIds,) = LibRainDeploySnapshot.recordedDeployedAddresses(vm, path, lines);
        uint256 mechanismData = 0;
        uint256 markers = 0;
        bytes32 markerHash = keccak256(bytes(BEACON_PROXY_DECLARATION));
        for (uint256 i = 0; i < lines.length; i++) {
            if (keccak256(bytes(lines[i])) == markerHash) {
                markers++;
            } else if (vm.contains(lines[i], BEACON_PROXY_NAME)) {
                revert FrozenSnapshotUnreadable(path);
            } else if (vm.indexOf(lines[i], LibRainDeploySnapshot.MECHANISM_DATA_DECLARATION) == 0) {
                mechanismData++;
            } else if (vm.contains(lines[i], LibRainDeploySnapshot.MECHANISM_DATA_NAME)) {
                revert FrozenSnapshotUnreadable(path);
            }
        }
        if (mechanismData > 1) {
            revert FrozenSnapshotMechanismDataAmbiguous(path);
        }
        if (markers > 1) {
            revert FrozenSnapshotBeaconProxyMarkerAmbiguous(path);
        }
        if (mechanismData == 0) {
            if (markers != 0) {
                revert FrozenSnapshotBeaconProxyMechanismDataMissing(path);
            }
            if (chainIds.length != 0) {
                revert FrozenSnapshotMechanismDataMissing(path);
            }
            return bytes32(0);
        }
        if (markers != 0) {
            return chainIds.length == 0 ? BEACON_PROXY_MECHANISM : BEACON_PROXY_PER_NETWORK_MECHANISM;
        }
        return chainIds.length == 0 ? CLONE_MECHANISM : CLONE_PER_NETWORK_MECHANISM;
    }

    /// @param tag A record's tag, nonzero.
    /// @param prefix The prefix the record's constants are aliased under.
    /// @return The Solidity expression a released-suites lib gives the release's `mechanismData`, its tag named.
    function releasedMechanismDataExpression(Vm, bytes32 tag, string memory prefix)
        internal
        pure
        returns (string memory)
    {
        return string.concat("abi.encode(", mechanismConstantName(tag), ", ", prefix, "_MECHANISM_DATA)");
    }

    /// @param tag A mechanism tag.
    /// @return The name `LibRainDeployCloneMechanism.sol` declares it under.
    function mechanismConstantName(bytes32 tag) internal pure returns (string memory) {
        return tag == CLONE_MECHANISM
            ? "CLONE_MECHANISM"
            : tag == CLONE_PER_NETWORK_MECHANISM
                ? "CLONE_PER_NETWORK_MECHANISM"
                : tag == BEACON_PROXY_MECHANISM ? "BEACON_PROXY_MECHANISM" : "BEACON_PROXY_PER_NETWORK_MECHANISM";
    }

    /// The root a lib in THIS repo's lib dir reaches `SOURCE_ROOT` by.
    function factoryImportRootInThisRepo() internal pure returns (string memory) {
        return "../";
    }

    /// The root a generated lib reaches this package's `SOURCE_ROOT` by: `rain-factory-<version>/src/` when `toml`
    /// pins a rain-factory dependency, else `factoryImportRootInThisRepo`, the tree being this repo.
    /// @param vm The Vm instance for TOML operations.
    /// @param toml The manifest contents to read the pin from.
    /// @return The root.
    function factoryImportRootForToml(Vm vm, string memory toml) internal view returns (string memory) {
        string memory key = string.concat(".dependencies.", PACKAGE_NAME);
        if (!vm.keyExistsToml(toml, key)) {
            return factoryImportRootInThisRepo();
        }
        string memory versionKey = string.concat(key, ".version");
        string memory version =
            vm.keyExistsToml(toml, versionKey) ? vm.parseTomlString(toml, versionKey) : vm.parseTomlString(toml, key);
        return string.concat(PACKAGE_NAME, "-", version, "/", SOURCE_ROOT, "/");
    }

    /// Whether a record's `MECHANISM_DATA` is untagged: its leading word is `abi.encode(bytes)`'s offset.
    /// @param vm The Vm instance for string operations.
    /// @param path The record file the lines were read from.
    /// @param lines Its `recordLines`, declaring `MECHANISM_DATA`.
    /// @return Whether it is a legacy record.
    function isLegacyRecord(Vm vm, string memory path, string[] memory lines) internal pure returns (bool) {
        return LibRainDeploySnapshot.leadingMechanismDataWord(vm, path, lines) == bytes32(uint256(0x20));
    }

    /// The tag a legacy clone or beacon proxy record's markers say its release carries; zero for a record with no
    /// `MECHANISM_DATA` or a tagged one.
    /// @param vm The Vm instance for file and string operations.
    /// @param path A record file.
    /// @return The tag.
    function legacyRecordTag(Vm vm, string memory path) internal view returns (bytes32) {
        string[] memory lines = LibRainDeploySnapshot.recordLines(vm, path, vm.readFile(path));
        (bool mechanismData,) = LibRainDeploySnapshot.recordedMechanismShape(vm, path, lines);
        if (!mechanismData || !isLegacyRecord(vm, path, lines)) {
            return bytes32(0);
        }
        return recordedMechanismTag(vm, path, lines);
    }

    /// @return `CLONE_MECHANISM` for a legacy clone record, else zero.
    function legacyCloneRecordId(DeployDeclaration memory, Vm vm, string memory path)
        internal
        view
        returns (bytes32)
    {
        return legacyRecordTag(vm, path) == CLONE_MECHANISM ? CLONE_MECHANISM : bytes32(0);
    }

    /// @return `CLONE_PER_NETWORK_MECHANISM` for a legacy per-network clone record, else zero.
    function legacyClonePerNetworkRecordId(DeployDeclaration memory, Vm vm, string memory path)
        internal
        view
        returns (bytes32)
    {
        return legacyRecordTag(vm, path) == CLONE_PER_NETWORK_MECHANISM ? CLONE_PER_NETWORK_MECHANISM : bytes32(0);
    }

    /// @return `BEACON_PROXY_MECHANISM` for a legacy beacon proxy record, else zero.
    function legacyBeaconProxyRecordId(DeployDeclaration memory, Vm vm, string memory path)
        internal
        view
        returns (bytes32)
    {
        return legacyRecordTag(vm, path) == BEACON_PROXY_MECHANISM ? BEACON_PROXY_MECHANISM : bytes32(0);
    }

    /// @return `BEACON_PROXY_PER_NETWORK_MECHANISM` for a legacy per-network beacon proxy record, else zero.
    function legacyBeaconProxyPerNetworkRecordId(DeployDeclaration memory, Vm vm, string memory path)
        internal
        view
        returns (bytes32)
    {
        return legacyRecordTag(vm, path) == BEACON_PROXY_PER_NETWORK_MECHANISM
            ? BEACON_PROXY_PER_NETWORK_MECHANISM
            : bytes32(0);
    }


    /// Deploys `suite` locally under a reverted state snapshot and writes its record.
    /// @return The path written.
    function writeSuiteSnapshot(DeployDeclaration memory d, Vm vm, SnapshotFile memory file, DeploySuite memory suite)
        internal
        returns (string memory)
    {
        uint256 snapshotId = vm.snapshotState();
        address[] memory deployed = LibRainDeployCloneMechanism.deployLocally(d, vm, suite);
        writeCloneSnapshotFile(
            vm,
            LibRainDeploySnapshot.dirForSnapshot(file.root, file.dir),
            file.contractName,
            file.spdxLicenseIdentifier,
            file.copyrightText,
            suite,
            deployed
        );
        if (!vm.revertToState(snapshotId)) {
            revert SnapshotStateRevertFailed(suite.suite, snapshotId);
        }
        return LibRainDeploySnapshot.pathForSnapshot(file.root, file.dir, file.contractName);
    }

    /// Refuses `FrozenSnapshotMechanismDataMissing` for a record with no `MECHANISM_DATA`.
    /// @return The expression of the released suite's `mechanismData`: the record's `MECHANISM_DATA` tagged by its
    /// markers for a legacy record, verbatim for a tagged one.
    function releasedMechanismData(DeployDeclaration memory, Vm vm, string memory path, string memory prefix)
        internal
        view
        returns (string memory)
    {
        string[] memory lines = LibRainDeploySnapshot.recordLines(vm, path, vm.readFile(path));
        (bool mechanismData,) = LibRainDeploySnapshot.recordedMechanismShape(vm, path, lines);
        if (!mechanismData) {
            revert FrozenSnapshotMechanismDataMissing(path);
        }
        if (isLegacyRecord(vm, path, lines)) {
            return releasedMechanismDataExpression(vm, recordedMechanismTag(vm, path, lines), prefix);
        }
        return string.concat(prefix, "_MECHANISM_DATA");
    }

    /// The import `releasedMechanismDataExpression` needs for `tag`. The root core passes reaches rain-deploy, not
    /// this package, so this package's root is read from the handler's `CloneLayerConfig.factoryImportRoot`.
    /// @param d The declaration carrying the handler.
    /// @param tag A mechanism tag.
    /// @return The import line.
    function releasedImportForTag(DeployDeclaration memory d, bytes32 tag) internal pure returns (string memory) {
        return string.concat(
            "import {",
            mechanismConstantName(tag),
            "} from \"",
            LibRainDeployCloneMechanism.layerConfig(d, tag, "").factoryImportRoot,
            CLONE_MECHANISM_SOURCE_SUBPATH,
            "\";\n"
        );
    }

    /// @return `releasedImportForTag` of `CLONE_MECHANISM`.
    function releasedCloneImport(DeployDeclaration memory d, string memory) internal pure returns (string memory) {
        return releasedImportForTag(d, CLONE_MECHANISM);
    }

    /// @return `releasedImportForTag` of `CLONE_PER_NETWORK_MECHANISM`.
    function releasedClonePerNetworkImport(DeployDeclaration memory d, string memory)
        internal
        pure
        returns (string memory)
    {
        return releasedImportForTag(d, CLONE_PER_NETWORK_MECHANISM);
    }

    /// @return `releasedImportForTag` of `BEACON_PROXY_MECHANISM`.
    function releasedBeaconProxyImport(DeployDeclaration memory d, string memory) internal pure returns (string memory) {
        return releasedImportForTag(d, BEACON_PROXY_MECHANISM);
    }

    /// @return `releasedImportForTag` of `BEACON_PROXY_PER_NETWORK_MECHANISM`.
    function releasedBeaconProxyPerNetworkImport(DeployDeclaration memory d, string memory)
        internal
        pure
        returns (string memory)
    {
        return releasedImportForTag(d, BEACON_PROXY_PER_NETWORK_MECHANISM);
    }
}
