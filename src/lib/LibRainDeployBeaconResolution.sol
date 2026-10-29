// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.17.0/src/Vm.sol";
import {StdConstants} from "forge-std-1.17.0/src/StdConstants.sol";
import {
    DeployDeclaration,
    DeploySuite,
    DerivationSnapshotRevertFailed
} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {DerivedDeploy, NoDerivedDeployment} from "rain-deploy-0.1.29/src/abstract/RainDeployVerifyBase.sol";
import {LibRainDeploy, SupportedNetwork} from "rain-deploy-0.1.29/src/lib/LibRainDeploy.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.29/src/lib/LibRainDeployDeclaration.sol";
import {ChainBeacon, DeployBeacon, LibRainDeployBeacon} from "./LibRainDeployBeacon.sol";
import {LibRainDeployCloneMechanism} from "./LibRainDeployCloneMechanism.sol";
import {
    BeaconNamedTwice,
    BeaconProbe,
    BeaconSeatedImplementation,
    BeaconSeatedOwner,
    BeaconUnnamed,
    LibRainDeployCloneOnChainChecks
} from "./LibRainDeployCloneOnChainChecks.sol";
import {BeaconDeclaredTwice, BeaconOnUncheckedNetwork} from "./LibRainDeployBeaconDeclarationChecks.sol";

/// Thrown when a suite a beacon names, as its implementation or as itself, is not released.
/// @param suite The declared key.
error BeaconSuiteNotReleased(string suite);

/// A beacon with every suite it names resolved on its network.
/// @param chainId The beacon's network.
/// @param beacon The declaration, its `beacon` and `beaconCodeHash` derived when it names `beaconSuite`.
/// @param suite The beacon's suite when it names `beaconSuite`.
/// @param derived The beacon's suite's derivation when it names `beaconSuite`.
/// @param implementations Each state's implementation suite, indexed as `LibRainDeployBeacon.stateAt`.
/// @param implementationAddresses Each state's implementation address on the beacon's network.
/// @param implementationDerived Each state's implementation derivation.
struct ResolvedBeacon {
    uint256 chainId;
    DeployBeacon beacon;
    DeploySuite suite;
    DerivedDeploy derived;
    DeploySuite[] implementations;
    address[] implementationAddresses;
    DerivedDeploy[] implementationDerived;
}

/// @title LibRainDeployBeaconResolution
/// @notice Resolves the declared beacons, and every released suite they name, on the networks checked.
library LibRainDeployBeaconResolution {
    /// The `CLONE_MECHANISM` handler's `checkNetworks`: resolves the declared beacons on `networks`, stores them in the
    /// layer config's `resolvedBeacons` and returns their chain ids.
    /// @param d The declaration, extended, mutated.
    /// @param networks The networks checked.
    /// @return Each resolved beacon's chain id, in declaration order.
    function checkNetworks(DeployDeclaration memory d, SupportedNetwork[] memory networks)
        internal
        returns (uint256[] memory)
    {
        ResolvedBeacon[] memory resolved = resolveBeacons(d, networks);
        LibRainDeployCloneMechanism.setResolvedBeacons(d, resolved);
        uint256[] memory chainIds = new uint256[](resolved.length);
        for (uint256 i = 0; i < resolved.length; i++) {
            chainIds[i] = resolved[i].chainId;
        }
        return chainIds;
    }

    /// When a beacon is declared, `BeaconOnUncheckedNetwork` for any beacon off `d.networks` before resolving any; then,
    /// for each beacon on `networks`, `resolveBeacon`'s refusals and `BeaconDeclaredTwice` for one at an address an
    /// earlier one on its network resolved to.
    /// @param d The declaration, extended.
    /// @param networks The networks whose beacons to resolve.
    /// @return Each declared beacon on one of `networks`, resolved on it, in declaration order.
    function resolveBeacons(DeployDeclaration memory d, SupportedNetwork[] memory networks)
        internal
        returns (ResolvedBeacon[] memory)
    {
        ChainBeacon[] memory chainBeacons = LibRainDeployCloneMechanism.layerConfig(d).beacons;
        if (chainBeacons.length == 0) {
            return new ResolvedBeacon[](0);
        }
        return resolveBeaconsOn(d, chainBeacons, LibRainDeploy.declaredNetworkConfigs(d.networks), networks);
    }

    /// `resolveBeacons`'s refusals and resolution, over declarations already read.
    /// @param d The declaration, extended.
    /// @param chainBeacons The declared beacons.
    /// @param supported `d.networks`' catalogue entries.
    /// @param networks The networks whose beacons to resolve.
    /// @return Each of `chainBeacons` on one of `networks`, resolved on it, in declaration order.
    function resolveBeaconsOn(
        DeployDeclaration memory d,
        ChainBeacon[] memory chainBeacons,
        SupportedNetwork[] memory supported,
        SupportedNetwork[] memory networks
    ) internal returns (ResolvedBeacon[] memory) {
        uint256 onNetworks = 0;
        for (uint256 beaconIndex = 0; beaconIndex < chainBeacons.length; beaconIndex++) {
            uint256 chainId = chainBeacons[beaconIndex].chainId;
            if (!LibRainDeploy.hasChainId(supported, chainId)) {
                revert BeaconOnUncheckedNetwork(chainId, beaconIndex);
            }
            if (LibRainDeploy.hasChainId(networks, chainId)) {
                onNetworks++;
            }
        }
        DeploySuite[] memory released = new DeploySuite[](d.released.length);
        DerivedDeploy[] memory derived = new DerivedDeploy[](d.released.length);
        ResolvedBeacon[] memory resolved = new ResolvedBeacon[](onNetworks);
        uint256 resolvedIndex = 0;
        for (uint256 beaconIndex = 0; beaconIndex < chainBeacons.length; beaconIndex++) {
            uint256 chainId = chainBeacons[beaconIndex].chainId;
            if (LibRainDeploy.hasChainId(networks, chainId)) {
                ResolvedBeacon memory beacon =
                    resolveBeacon(d, chainBeacons[beaconIndex].beacon, chainId, beaconIndex, released, derived);
                for (uint256 earlier = 0; earlier < resolvedIndex; earlier++) {
                    if (resolved[earlier].chainId == chainId && resolved[earlier].beacon.beacon == beacon.beacon.beacon)
                    {
                        revert BeaconDeclaredTwice(chainId, beaconIndex);
                    }
                }
                resolved[resolvedIndex++] = beacon;
            }
        }
        return resolved;
    }

    /// Refuses `BeaconNamedTwice` and `BeaconUnnamed`, `BeaconSuiteNotReleased` through `resolveReleased`,
    /// `LibRainDeployBeacon.checkTransitionMigrations`'s refusals, those of each named suite's address and derivation
    /// on `chainId`, and `checkSeatedState`'s for a beacon named by `beaconSuite`.
    /// @param d The declaration, extended.
    /// @param declaration The beacon, left unwritten so one declaration can be resolved on several networks.
    /// @param chainId The beacon's network.
    /// @param beaconIndex The beacon's index in the declared beacons, for the refusal.
    /// @param released Each released suite once resolved, as `resolveReleased` takes it.
    /// @param derived Each released suite's derivation, as `resolveReleased` takes it.
    /// @return The beacon, resolved on `chainId`.
    function resolveBeacon(
        DeployDeclaration memory d,
        DeployBeacon memory declaration,
        uint256 chainId,
        uint256 beaconIndex,
        DeploySuite[] memory released,
        DerivedDeploy[] memory derived
    ) internal returns (ResolvedBeacon memory) {
        DeployBeacon memory beacon = DeployBeacon({
            beaconSuite: declaration.beaconSuite,
            beacon: declaration.beacon,
            beaconCodeHash: declaration.beaconCodeHash,
            initial: declaration.initial,
            transitions: declaration.transitions
        });
        // Fields read only when `beaconSuite` assigns them.
        // slither-disable-next-line uninitialized-local
        ResolvedBeacon memory resolved;
        if (bytes(beacon.beaconSuite).length != 0) {
            if (beacon.beacon != address(0) || beacon.beaconCodeHash != bytes32(0)) {
                revert BeaconNamedTwice(chainId, beaconIndex);
            }
            uint256 releasedIndex = resolveReleased(d, beacon.beaconSuite, released, derived);
            resolved.suite = released[releasedIndex];
            resolved.derived = derived[releasedIndex];
            beacon.beacon = LibRainDeployDeclaration.mechanismOf(d, released[releasedIndex])
                .deployedAddress(d, released[releasedIndex], chainId);
            beacon.beaconCodeHash = derived[releasedIndex].bytecodeHash;
        } else if (beacon.beacon == address(0) || beacon.beaconCodeHash == bytes32(0)) {
            revert BeaconUnnamed(chainId, beaconIndex);
        }
        LibRainDeployBeacon.checkTransitionMigrations(chainId, beacon);
        resolved.chainId = chainId;
        resolved.beacon = beacon;
        uint256 states = beacon.transitions.length + 1;
        resolved.implementations = new DeploySuite[](states);
        resolved.implementationAddresses = new address[](states);
        resolved.implementationDerived = new DerivedDeploy[](states);
        for (uint256 state = 0; state < states; state++) {
            uint256 releasedIndex =
                resolveReleased(d, LibRainDeployBeacon.stateAt(beacon, state).implementation, released, derived);
            resolved.implementations[state] = released[releasedIndex];
            resolved.implementationAddresses[state] = LibRainDeployDeclaration.mechanismOf(d, released[releasedIndex])
                .deployedAddress(d, released[releasedIndex], chainId);
            resolved.implementationDerived[state] = derived[releasedIndex];
        }
        if (bytes(beacon.beaconSuite).length != 0) {
            checkSeatedState(d, resolved, beaconIndex);
        }
        return resolved;
    }

    /// Refuses `BeaconSuiteNotReleased` when `key` is not in `d.released`; derives a released suite the first time it
    /// is resolved and reuses that derivation after.
    /// @param d The declaration, extended.
    /// @param key The key a beacon names.
    /// @param released Each released suite, filled when first resolved by its form on every declared network.
    /// @param derived Each released suite's derivation, filled when first resolved.
    /// @return The index of `key` in `d.released`.
    function resolveReleased(
        DeployDeclaration memory d,
        string memory key,
        DeploySuite[] memory released,
        DerivedDeploy[] memory derived
    ) internal returns (uint256) {
        uint256 releasedIndex = LibRainDeployDeclaration.suiteIndex(d.released, key);
        if (releasedIndex == d.released.length) {
            revert BeaconSuiteNotReleased(key);
        }
        if (bytes(derived[releasedIndex].suite).length == 0) {
            released[releasedIndex] = LibRainDeployCloneOnChainChecks.released(d, key);
            derived[releasedIndex] = deriveDeployment(d, released[releasedIndex]);
        }
        return releasedIndex;
    }

    /// Derives a suite through its own mechanism under a reverted snapshot, as core `deriveDeployment` does.
    /// @param d The declaration, extended.
    /// @param suite The suite.
    /// @return The addresses and code hash the suite's mechanism produces.
    function deriveDeployment(DeployDeclaration memory d, DeploySuite memory suite)
        internal
        returns (DerivedDeploy memory)
    {
        Vm vm = StdConstants.VM;
        uint256 snapshotId = vm.snapshotState();
        address[] memory deployedAddresses = LibRainDeployDeclaration.mechanismOf(d, suite).deployLocally(d, vm, suite);
        uint256 deployed = 0;
        while (deployed < deployedAddresses.length && deployedAddresses[deployed] == address(0)) {
            deployed++;
        }
        if (deployed == deployedAddresses.length) {
            revert NoDerivedDeployment(suite.suite);
        }
        DerivedDeploy memory derivedDeploy = DerivedDeploy({
            suite: suite.suite, deployedAddresses: deployedAddresses, bytecodeHash: deployedAddresses[deployed].codehash
        });
        if (!vm.revertToState(snapshotId)) {
            revert DerivationSnapshotRevertFailed(suite.suite, snapshotId);
        }
        return derivedDeploy;
    }

    /// Deploys the beacon's suite locally under its chain id and refuses `BeaconSeatedOwner` or
    /// `BeaconSeatedImplementation` when the beacon answers `owner()` or `implementation()` other than the initial
    /// state. A read that reverts or answers nothing is left to `LibRainDeployBeacon.checkBeacon`.
    /// @param d The declaration, extended.
    /// @param resolved The beacon, resolved and named by `beaconSuite`.
    /// @param beaconIndex The beacon's index in the declared beacons, for the refusal.
    function checkSeatedState(DeployDeclaration memory d, ResolvedBeacon memory resolved, uint256 beaconIndex)
        internal
    {
        BeaconProbe memory probe =
            LibRainDeployCloneOnChainChecks.probeBeacon(d, resolved.suite, resolved.beacon.beacon, resolved.chainId);
        if (LibRainDeployCloneOnChainChecks.seatsOther(probe.ownerAnswered, probe.owner, resolved.beacon.initial.owner))
        {
            revert BeaconSeatedOwner(resolved.chainId, beaconIndex, probe.owner);
        }
        if (LibRainDeployCloneOnChainChecks.seatsOther(
                probe.implementationAnswered, probe.implementation, resolved.implementationAddresses[0]
            )) {
            revert BeaconSeatedImplementation(resolved.chainId, beaconIndex, probe.implementation);
        }
    }
}
