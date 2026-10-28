// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.17.0/src/Vm.sol";
import {LibCodeGen} from "rain-sol-codegen-0.1.39/src/lib/LibCodeGen.sol";
import {LibFs} from "rain-sol-codegen-0.1.39/src/lib/LibFs.sol";
import {DeploySuite, SnapshotFile} from "rain-deploy-0.1.27/src/abstract/RainDeploySuitesBase.sol";
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
        bytes memory mechanismData;
        if (LibRainDeployCloneMechanism.isPerNetwork(suite)) {
            (addressConstants, mechanismData) = perNetworkAddressConstants(vm, deployed, suite);
            mechanismDataComment = beaconProxy
                ? "/// @dev The beacon proxy factory call this release was cut with: the\n"
                "/// `abi.encode`d `CloneNetworks` a released suite carries as its\n" "/// `mechanismData`."
                : "/// @dev The clone factory call this release was cut with: the\n"
                "/// `abi.encode`d `CloneNetworks` a released suite carries as its\n" "/// `mechanismData`.";
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
            mechanismData = LibRainDeployCloneMechanism.payload(suite);
            mechanismDataComment = beaconProxy
                ? "/// @dev The beacon proxy factory call this release was cut with: the\n"
                "/// `abi.encode`d `CloneTarget` a released suite carries as its\n" "/// `mechanismData`."
                : "/// @dev The clone factory call this release was cut with: the\n"
                "/// `abi.encode`d `CloneTarget` a released suite carries as its\n" "/// `mechanismData`.";
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
            LibCodeGen.bytesConstantString(vm, mechanismDataComment, "MECHANISM_DATA", mechanismData)
        );
    }

    /// @param vm The Vm instance for string operations.
    /// @param deployed Where a per-network suite was deployed, in its address order.
    /// @param suite The suite.
    /// @return Its `DEPLOYED_ADDRESS_<chainId>` constants, and its `CloneNetworks` at `deployed`, `abi.encode`d.
    function perNetworkAddressConstants(Vm vm, address[] memory deployed, DeploySuite memory suite)
        internal
        pure
        returns (string memory, bytes memory)
    {
        CloneNetworks memory clones = LibRainDeployCloneMechanism.cloneNetworks(suite);
        string memory addressConstants = "";
        bool beaconProxy = LibRainDeployCloneMechanism.isBeaconProxy(suite);
        for (uint256 i = 0; i < clones.networks.length; i++) {
            clones.networks[i].deployedAddress = deployed[i];
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
        return (addressConstants, abi.encode(clones));
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

    /// The tag a frozen record's release carries, read from its declarations; zero for a record with no
    /// `MECHANISM_DATA`.
    /// @param vm The Vm instance for file and string operations.
    /// @param path A record file.
    /// @return The tag.
    function recordedMechanismTag(Vm vm, string memory path) internal view returns (bytes32) {
        string[] memory lines = LibRainDeploySnapshot.recordLines(vm, path, vm.readFile(path));
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

    /// @param vm The Vm instance for string operations.
    /// @param tag A record's tag, nonzero.
    /// @param prefix The prefix the record's constants are aliased under.
    /// @return The Solidity expression a released-suites lib gives the release's `mechanismData`.
    function releasedMechanismDataExpression(Vm vm, bytes32 tag, string memory prefix)
        internal
        pure
        returns (string memory)
    {
        return string.concat("abi.encode(bytes32(", vm.toString(tag), "), ", prefix, "_MECHANISM_DATA)");
    }

    /// A clone or beacon proxy names no compiled source to verify, so nothing is logged.
    function logVerification(Vm, string[] memory, DeploySuite memory, address[] memory) internal pure {}

    /// Deploys `suite` locally under a reverted state snapshot and writes its record.
    /// @return The path written.
    function writeSuiteSnapshot(Vm vm, SnapshotFile memory file, DeploySuite memory suite)
        internal
        returns (string memory)
    {
        uint256 snapshotId = vm.snapshotState();
        address[] memory deployed = LibRainDeployCloneMechanism.deployLocally(vm, suite);
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
}
