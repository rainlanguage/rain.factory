// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {StdConstants} from "forge-std-1.17.0/src/StdConstants.sol";
import {IERC5313} from "@openzeppelin-contracts-5.7.0/interfaces/IERC5313.sol";
import {IBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/IBeacon.sol";
import {DeployDeclaration, DeploySuite} from "rain-deploy-0.1.27/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeploy, SupportedNetwork} from "rain-deploy-0.1.27/src/lib/LibRainDeploy.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.27/src/lib/LibRainDeployDeclaration.sol";
import {ChainBeacon, DeployBeacon, LibRainDeployBeacon} from "./LibRainDeployBeacon.sol";
import {BEACON_PROXY_MECHANISM} from "./LibRainDeployCloneMechanism.sol";
import {
    BeaconNamedTwice,
    BeaconSeatedImplementation,
    BeaconSeatedOwner,
    BeaconSnapshotRevertFailed,
    BeaconUnnamed,
    LibRainDeployCloneOnChainChecks
} from "./LibRainDeployCloneOnChainChecks.sol";

/// @param chainId The beacon's chain id.
/// @param beaconIndex The beacon's index in the beacon config.
error BeaconOnUncheckedNetwork(uint256 chainId, uint256 beaconIndex);

/// @param chainId The beacon's network.
/// @param beaconIndex The index in the beacon config of the later declaration.
error BeaconDeclaredTwice(uint256 chainId, uint256 beaconIndex);

/// @title LibRainDeployBeaconDeclarationChecks
/// @notice The beacon proxy handler's `checkDeclaration`: every declared beacon resolved offline.
library LibRainDeployBeaconDeclarationChecks {
    function checkDeclaration(DeployDeclaration memory d) internal {
        (ChainBeacon[] memory chainBeacons,) =
            abi.decode(LibRainDeployDeclaration.mechanismById(d, BEACON_PROXY_MECHANISM, "").config, (ChainBeacon[], string));
        if (chainBeacons.length == 0) {
            return;
        }
        SupportedNetwork[] memory networks = LibRainDeploy.declaredNetworkConfigs(d.networks);
        for (uint256 beaconIndex = 0; beaconIndex < chainBeacons.length; beaconIndex++) {
            if (!LibRainDeploy.hasChainId(networks, chainBeacons[beaconIndex].chainId)) {
                revert BeaconOnUncheckedNetwork(chainBeacons[beaconIndex].chainId, beaconIndex);
            }
        }
        address[] memory resolved = new address[](chainBeacons.length);
        for (uint256 beaconIndex = 0; beaconIndex < chainBeacons.length; beaconIndex++) {
            uint256 chainId = chainBeacons[beaconIndex].chainId;
            resolved[beaconIndex] = resolveBeacon(d, chainBeacons[beaconIndex].beacon, chainId, beaconIndex);
            for (uint256 earlier = 0; earlier < beaconIndex; earlier++) {
                if (chainBeacons[earlier].chainId == chainId && resolved[earlier] == resolved[beaconIndex]) {
                    revert BeaconDeclaredTwice(chainId, beaconIndex);
                }
            }
        }
    }

    /// @return The beacon's address on `chainId`.
    function resolveBeacon(DeployDeclaration memory d, DeployBeacon memory declaration, uint256 chainId, uint256 beaconIndex)
        internal
        returns (address)
    {
        DeployBeacon memory beacon = DeployBeacon({
            beaconSuite: declaration.beaconSuite,
            beacon: declaration.beacon,
            beaconCodeHash: declaration.beaconCodeHash,
            initial: declaration.initial,
            transitions: declaration.transitions
        });
        bool named = bytes(beacon.beaconSuite).length != 0;
        DeploySuite memory suite;
        if (named) {
            if (beacon.beacon != address(0) || beacon.beaconCodeHash != bytes32(0)) {
                revert BeaconNamedTwice(chainId, beaconIndex);
            }
            suite = LibRainDeployCloneOnChainChecks.released(d, beacon.beaconSuite);
            beacon.beacon = LibRainDeployCloneOnChainChecks.handlerOf(d, suite).deployedAddress(d, suite, chainId);
        } else if (beacon.beacon == address(0) || beacon.beaconCodeHash == bytes32(0)) {
            revert BeaconUnnamed(chainId, beaconIndex);
        }
        LibRainDeployBeacon.checkTransitionMigrations(chainId, beacon);
        address initialImplementation = LibRainDeployCloneOnChainChecks.implementationAt(d, beacon, 0, chainId);
        for (uint256 state = 1; state <= beacon.transitions.length; state++) {
            LibRainDeployCloneOnChainChecks.implementationAt(d, beacon, state, chainId);
        }
        if (named) {
            checkSeatedState(d, suite, beacon, chainId, beaconIndex, initialImplementation);
        }
        return beacon.beacon;
    }

    /// Deploys the beacon's suite locally under `chainId` and refuses `BeaconSeatedOwner` or
    /// `BeaconSeatedImplementation` when the beacon answers `owner()` or `implementation()` other than the initial
    /// state. A read that reverts or answers nothing is left to `LibRainDeployBeacon.checkBeacon`.
    function checkSeatedState(
        DeployDeclaration memory d,
        DeploySuite memory suite,
        DeployBeacon memory beacon,
        uint256 chainId,
        uint256 beaconIndex,
        address initialImplementation
    ) internal {
        uint256 snapshotId = StdConstants.VM.snapshotState();
        StdConstants.VM.chainId(chainId);
        LibRainDeployCloneOnChainChecks.handlerOf(d, suite).deployLocallyOnChain(d, StdConstants.VM, suite);
        // slither-disable-next-line low-level-calls
        (bool ownerAnswered, bytes memory owner) = beacon.beacon.staticcall(abi.encodeCall(IERC5313.owner, ()));
        // slither-disable-next-line low-level-calls
        (bool implementationAnswered, bytes memory implementation) =
            beacon.beacon.staticcall(abi.encodeCall(IBeacon.implementation, ()));
        // Restores the chain id with the state.
        if (!StdConstants.VM.revertToState(snapshotId)) {
            revert BeaconSnapshotRevertFailed(suite.suite, snapshotId);
        }
        if (seatsOther(ownerAnswered, owner, beacon.initial.owner)) {
            revert BeaconSeatedOwner(chainId, beaconIndex, owner);
        }
        if (seatsOther(implementationAnswered, implementation, initialImplementation)) {
            revert BeaconSeatedImplementation(chainId, beaconIndex, implementation);
        }
    }

    function seatsOther(bool answered, bytes memory answer, address expected) internal pure returns (bool) {
        return answered && answer.length != 0 && keccak256(answer) != keccak256(abi.encode(expected));
    }
}
