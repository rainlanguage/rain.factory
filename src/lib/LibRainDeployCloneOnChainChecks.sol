// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.17.0/src/Vm.sol";
import {StdConstants} from "forge-std-1.17.0/src/StdConstants.sol";
import {IERC5313} from "@openzeppelin-contracts-5.7.0/interfaces/IERC5313.sol";
import {IBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/IBeacon.sol";
import {
    DeployDeclaration,
    DeployMechanismHandler,
    DeploySuite
} from "rain-deploy-0.1.27/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.27/src/lib/LibRainDeployDeclaration.sol";
import {ChainBeacon, DeployBeacon, LibRainDeployBeacon} from "./LibRainDeployBeacon.sol";
import {
    BEACON_PROXY_MECHANISM,
    BEACON_PROXY_PER_NETWORK_MECHANISM,
    LibRainDeployCloneMechanism
} from "./LibRainDeployCloneMechanism.sol";

/// @param suite The beacon proxy suite.
/// @param network The network.
/// @param beacon The proxy's beacon.
error BeaconProxyBeaconUndeclared(string suite, string network, address beacon);

/// @param suite The suite named.
error BeaconSuiteNotReleased(string suite);

/// @param chainId The beacon's network.
/// @param beaconIndex The beacon's index in the beacon config.
error BeaconNamedTwice(uint256 chainId, uint256 beaconIndex);

/// @param chainId The beacon's network.
/// @param beaconIndex The beacon's index in the beacon config.
error BeaconUnnamed(uint256 chainId, uint256 beaconIndex);

/// @param chainId The beacon's network.
/// @param beaconIndex The beacon's index in the beacon config.
/// @param seated The `owner()` answer, raw.
error BeaconSeatedOwner(uint256 chainId, uint256 beaconIndex, bytes seated);

/// @param chainId The beacon's network.
/// @param beaconIndex The beacon's index in the beacon config.
/// @param seated The `implementation()` answer, raw.
error BeaconSeatedImplementation(uint256 chainId, uint256 beaconIndex, bytes seated);

/// @param suite The suite deployed.
/// @param snapshotId The snapshot that failed to restore.
error BeaconSnapshotRevertFailed(string suite, uint256 snapshotId);

/// @param chainId The beacon's network.
/// @param beaconIndex The beacon's index in the beacon config.
/// @param state The state index, as `LibRainDeployBeacon.stateAt` takes it.
error BeaconOwnedByDeployKey(uint256 chainId, uint256 beaconIndex, uint256 state);

/// @title LibRainDeployCloneOnChainChecks
/// @notice The clone and beacon proxy handlers' `checkOnChain` and `checkBroadcastSeat`.
library LibRainDeployCloneOnChainChecks {
    function isBeaconId(bytes32 id) internal pure returns (bool) {
        return id == BEACON_PROXY_MECHANISM || id == BEACON_PROXY_PER_NETWORK_MECHANISM;
    }

    function suiteId(DeploySuite memory suite) internal pure returns (bytes32) {
        (bytes32 id,) = abi.decode(suite.mechanismData, (bytes32, bytes));
        return id;
    }

    function beacons(DeployDeclaration memory d, DeploySuite memory suite) internal pure returns (ChainBeacon[] memory) {
        (ChainBeacon[] memory declared,) =
            abi.decode(LibRainDeployDeclaration.mechanismById(d, suiteId(suite), suite.suite).config, (ChainBeacon[], string));
        return declared;
    }

    function released(DeployDeclaration memory d, string memory name) internal pure returns (DeploySuite memory) {
        for (uint256 i = 0; i < d.released.length; i++) {
            if (keccak256(bytes(d.released[i].suite)) == keccak256(bytes(name))) {
                return d.released[i];
            }
        }
        revert BeaconSuiteNotReleased(name);
    }

    function handlerOf(DeployDeclaration memory d, DeploySuite memory suite)
        internal
        pure
        returns (DeployMechanismHandler memory)
    {
        return LibRainDeployDeclaration.mechanismById(d, suiteId(suite), suite.suite);
    }

    function implementationAt(DeployDeclaration memory d, DeployBeacon memory beacon, uint256 state, uint256 chainId)
        internal
        view
        returns (address)
    {
        DeploySuite memory implementation = released(d, LibRainDeployBeacon.stateAt(beacon, state).implementation);
        return handlerOf(d, implementation).deployedAddress(d, implementation, chainId);
    }

    function seatsOther(bool answered, bytes memory answer, address expected) internal pure returns (bool) {
        return answered && answer.length != 0 && keccak256(answer) != keccak256(abi.encode(expected));
    }

    /// The beacon at `beaconIndex`, with `beacon` and `beaconCodeHash` resolved from its `beaconSuite` deployed
    /// locally under `chainId`, refusing a seated owner or implementation other than its initial state's.
    function resolveBeacon(DeployDeclaration memory d, DeployBeacon memory declaration, uint256 chainId, uint256 beaconIndex)
        internal
        returns (DeployBeacon memory)
    {
        DeployBeacon memory beacon = DeployBeacon({
            beaconSuite: declaration.beaconSuite,
            beacon: declaration.beacon,
            beaconCodeHash: declaration.beaconCodeHash,
            initial: declaration.initial,
            transitions: declaration.transitions
        });
        if (bytes(beacon.beaconSuite).length != 0) {
            if (beacon.beacon != address(0) || beacon.beaconCodeHash != bytes32(0)) {
                revert BeaconNamedTwice(chainId, beaconIndex);
            }
            DeploySuite memory suite = released(d, beacon.beaconSuite);
            DeployMechanismHandler memory h = handlerOf(d, suite);
            beacon.beacon = h.deployedAddress(d, suite, chainId);
            Vm vm = StdConstants.VM;
            uint256 snapshotId = vm.snapshotState();
            vm.chainId(chainId);
            h.deployLocallyOnChain(d, vm, suite);
            beacon.beaconCodeHash = beacon.beacon.codehash;
            // slither-disable-next-line low-level-calls
            (bool ownerAnswered, bytes memory owner) = beacon.beacon.staticcall(abi.encodeCall(IERC5313.owner, ()));
            // slither-disable-next-line low-level-calls
            (bool implementationAnswered, bytes memory implementation) =
                beacon.beacon.staticcall(abi.encodeCall(IBeacon.implementation, ()));
            if (!vm.revertToState(snapshotId)) {
                revert BeaconSnapshotRevertFailed(suite.suite, snapshotId);
            }
            if (seatsOther(ownerAnswered, owner, beacon.initial.owner)) {
                revert BeaconSeatedOwner(chainId, beaconIndex, owner);
            }
            if (seatsOther(implementationAnswered, implementation, implementationAt(d, beacon, 0, chainId))) {
                revert BeaconSeatedImplementation(chainId, beaconIndex, implementation);
            }
        } else if (beacon.beacon == address(0) || beacon.beaconCodeHash == bytes32(0)) {
            revert BeaconUnnamed(chainId, beaconIndex);
        }
        LibRainDeployBeacon.checkTransitionMigrations(chainId, beacon);
        return beacon;
    }

    /// Beacon proxy suites only: refuses `BeaconProxyBeaconUndeclared` when no beacon in the handler's config is the
    /// proxy's beacon on `chainId`, then checks that beacon on the selected fork at its applied state.
    function checkOnChain(
        DeployDeclaration memory d,
        DeploySuite memory suite,
        string memory network,
        uint256 chainId,
        address
    ) internal {
        if (!isBeaconId(suiteId(suite))) {
            return;
        }
        address proxyBeacon = LibRainDeployCloneMechanism.beacon(suite, chainId);
        ChainBeacon[] memory chainBeacons = beacons(d, suite);
        for (uint256 beaconIndex = 0; beaconIndex < chainBeacons.length; beaconIndex++) {
            if (chainBeacons[beaconIndex].chainId != chainId) {
                continue;
            }
            DeployBeacon memory beacon = resolveBeacon(d, chainBeacons[beaconIndex].beacon, chainId, beaconIndex);
            if (beacon.beacon != proxyBeacon) {
                continue;
            }
            uint256 state = LibRainDeployBeacon.appliedState(network, beacon);
            LibRainDeployBeacon.checkBeacon(
                network,
                beacon,
                implementationAt(d, beacon, state, chainId),
                LibRainDeployBeacon.stateAt(beacon, state).owner
            );
            return;
        }
        revert BeaconProxyBeaconUndeclared(suite.suite, network, proxyBeacon);
    }

    function checkDeclaration(DeployDeclaration memory) internal {}

    function checkNetwork(DeployDeclaration memory, string memory, uint256) internal {}

    /// Beacon proxy suites only: refuses `BeaconOwnedByDeployKey` when any state of any beacon in the handler's
    /// config is owned by `deployer`.
    function checkBroadcastSeat(DeployDeclaration memory d, DeploySuite memory suite, uint256, address deployer)
        internal
    {
        if (!isBeaconId(suiteId(suite))) {
            return;
        }
        ChainBeacon[] memory chainBeacons = beacons(d, suite);
        for (uint256 beaconIndex = 0; beaconIndex < chainBeacons.length; beaconIndex++) {
            for (uint256 state = 0; state <= chainBeacons[beaconIndex].beacon.transitions.length; state++) {
                if (LibRainDeployBeacon.stateAt(chainBeacons[beaconIndex].beacon, state).owner == deployer) {
                    revert BeaconOwnedByDeployKey(chainBeacons[beaconIndex].chainId, beaconIndex, state);
                }
            }
        }
    }
}
