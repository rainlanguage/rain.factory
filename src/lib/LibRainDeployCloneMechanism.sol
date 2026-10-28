// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm, VmSafe} from "forge-std-1.17.0/src/Vm.sol";
import {console2} from "forge-std-1.17.0/src/console2.sol";
import {ICloneableFactoryV6} from "../interface/deprecated/ICloneableFactoryV6.sol";

import {
    DeployCandidate,
    DeployDeclaration,
    DeployMechanismHandler,
    DeploySuite
} from "rain-deploy-0.1.27/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeploy} from "rain-deploy-0.1.27/src/lib/LibRainDeploy.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.27/src/lib/LibRainDeployDeclaration.sol";
import {ChainDeploy, LibRainDeployExtendedNetworks} from "./LibRainDeployExtendedNetworks.sol";
import {ChainBeacon} from "./LibRainDeployBeacon.sol";
import {LibRainDeploySnapshot}from "rain-deploy-0.1.27/src/lib/LibRainDeploySnapshot.sol";
import {
    CLONE_ARTIFACT_PATH,
    CLONE_UNANCHORABLE_REASON,
    CloneDeploy,
    CloneNetworks,
    CloneTarget,
    LibRainDeployClone
} from "./LibRainDeployClone.sol";
import {
    BEACON_PROXY_ARTIFACT_PATH,
    BEACON_PROXY_UNANCHORABLE_REASON,
    BeaconProxyDeploy,
    LibRainDeployBeaconProxy
} from "./LibRainDeployBeaconProxy.sol";
import {LibRainDeployCloneSnapshot} from "./LibRainDeployCloneSnapshot.sol";
import {LibRainDeployCloneOnChainChecks} from "./LibRainDeployCloneOnChainChecks.sol";

/// @dev Tags an EIP-1167 clone suite's `mechanismData`: `abi.encode(CLONE_MECHANISM, abi.encode(CloneTarget))`.
bytes32 constant CLONE_MECHANISM = keccak256("rain.factory.deploy.mechanism.clone");

/// @dev Tags a per-network clone suite's `mechanismData`: `abi.encode(CLONE_PER_NETWORK_MECHANISM,
/// abi.encode(CloneNetworks))`.
bytes32 constant CLONE_PER_NETWORK_MECHANISM = keccak256("rain.factory.deploy.mechanism.clone-per-network");

/// @dev Tags a beacon proxy suite's `mechanismData`: `abi.encode(BEACON_PROXY_MECHANISM, abi.encode(CloneTarget))`,
/// the target's `implementation` holding the beacon.
bytes32 constant BEACON_PROXY_MECHANISM = keccak256("rain.factory.deploy.mechanism.beacon-proxy");

/// @dev Tags a per-network beacon proxy suite's `mechanismData`: `abi.encode(BEACON_PROXY_PER_NETWORK_MECHANISM,
/// abi.encode(CloneNetworks))`.
bytes32 constant BEACON_PROXY_PER_NETWORK_MECHANISM =
    keccak256("rain.factory.deploy.mechanism.beacon-proxy-per-network");

/// Thrown when a clone suite's declared factory, run locally, puts the clone somewhere other than
/// the address the factory formula derives.
/// @param suite The suite being derived.
/// @param formulaAddress The address `targetAddress` computed: `LibRainDeployClone.cloneDeployedAddress` for a clone,
/// `LibRainDeployBeaconProxy.beaconProxyDeployedAddress` for a beacon proxy.
/// @param factoryAddress The address the declared factory actually deployed to.
error CloneDerivationMismatch(string suite, address formulaAddress, address factoryAddress);

/// Thrown when extended networks are declared for a suite that is not per network.
/// @param suite The suite.
error ExtendedNetworksUnexpected(string suite);

/// Thrown when a clone suite's `creationCode` is not the EIP-1167 creation code for the implementation its
/// `mechanismData` names, or a beacon proxy suite's is not the `BeaconProxy` creation code over its beacon.
/// @param suite The suite being derived.
error CloneCreationCodeMismatch(string suite);

/// Thrown when a per-network clone or beacon proxy suite carries a `storedDeployedAddress`.
/// @param suite The suite carrying the address.
/// @param storedDeployedAddress The address it carries.
error UnexpectedStoredDeployedAddress(string suite, address storedDeployedAddress);

/// Thrown when a clone or beacon proxy declaration sets `initDataPerNetwork` and also declares `data` for every
/// network.
/// @param suite The declaration's suite key.
error CloneDataAmbiguous(string suite);

/// Thrown when an extended network's address is not the one its init data derives under the release.
/// @param suite The release's suite key.
/// @param chainId The extended network's chain id.
/// @param derivedAddress The address its init data derives.
/// @param extendedAddress The address it declares.
error ExtendedNetworkAddressMismatch(string suite, uint256 chainId, address derivedAddress, address extendedAddress);

/// Thrown when a per-network release is checked on, or about to be broadcast to, a network it neither records nor
/// declares as extended, whether or not anything is live at the address its candidate's current init data derives
/// there.
/// At broadcast that address is what the candidate's data derives now, not necessarily where the release is live: a
/// release already broadcast there is declared with the init data it was broadcast with, from its `NewClone` event.
/// @param suite The release's suite key.
/// @param network The network.
/// @param deployedAddress The address checked or to be broadcast there.
error ExtendedNetworkUnfrozen(string suite, string network, address deployedAddress);

/// Thrown when a storage slot of any account but the clone and the accounts created under it is read while the clone
/// is deployed locally: the factory call and the clone's `initialize`. A full-slot write is not refused; a write to
/// part of a slot reads the slot first and is refused like a read.
/// A beacon proxy is not deployed locally, so this never applies to one.
/// @param suite The suite being deployed.
/// @param account The account whose storage was read.
/// @param slot The slot read.
error CloneInitializeReadsStorage(string suite, address account, bytes32 slot);

/// Emitted when a broadcast Zoltu entry under `CLONE_ARTIFACT_PATH` or `BEACON_PROXY_ARTIFACT_PATH` leaves its source
/// to verify by hand.
/// @param sender The deploy's `msg.sender`, not the broadcasting key.
/// @param entryAddress Where the entry is deployed on every network.
/// @param networks The networks it was broadcast to.
event UnverifiableSource(address sender, address entryAddress, string[] networks);

/// @title LibRainDeployCloneMechanism
/// @notice The clone and beacon proxy mechanisms over a suite whose `mechanismData` carries one of their tags.
library LibRainDeployCloneMechanism {
    function handler(bytes32 id, bytes memory config) internal pure returns (DeployMechanismHandler memory) {
        return DeployMechanismHandler({
            id: id,
            config: config,
            deployedAddress: deployedAddress,
            recordedAddress: recordedAddress,
            deployStepData: deployStepData,
            deployStep: deployStep,
            deployLocally: deployLocally,
            deployLocallyOnChain: deployLocallyOnChain,
            addUnrecordedNetworks: addUnrecordedNetworks,
            addRecordedNetworks: addRecordedNetworks,
            checkNetworkFrozen: checkNetworkFrozen,
            checkOnChain: LibRainDeployCloneOnChainChecks.checkOnChain,
            checkBroadcastSeat: LibRainDeployCloneOnChainChecks.checkBroadcastSeat,
            logVerification: logVerification,
            writeSuiteSnapshot: LibRainDeployCloneSnapshot.writeSuiteSnapshot,
            releasedMechanismData: LibRainDeployCloneSnapshot.releasedMechanismData,
            releasedImport: LibRainDeployCloneSnapshot.releasedImport
        });
    }

    /// @param beacons The beacons beacon proxy suites resolve through.
    /// @param root The root extended networks records are read under.
    /// @return The layer config every clone handler carries.
    function config(ChainBeacon[] memory beacons, string memory root) internal pure returns (bytes memory) {
        return abi.encode(beacons, root);
    }

    /// Appends the four clone mechanism handlers to `d`, extended networks read under `LibRainDeploySnapshot.LIB_FS_ROOT`.
    /// @param d The declaration, mutated.
    /// @param beacons The beacons beacon proxy suites resolve through.
    function extend(DeployDeclaration memory d, ChainBeacon[] memory beacons) internal pure {
        extend(d, beacons, LibRainDeploySnapshot.LIB_FS_ROOT);
    }

    /// Appends the four clone mechanism handlers to `d`, config `abi.encode(beacons, root)`.
    /// @param d The declaration, mutated.
    /// @param beacons The beacons beacon proxy suites resolve through.
    /// @param root The root extended networks records are read under.
    function extend(DeployDeclaration memory d, ChainBeacon[] memory beacons, string memory root) internal pure {
        bytes memory layer = config(beacons, root);
        LibRainDeployDeclaration.addMechanism(d, handler(CLONE_MECHANISM, layer));
        LibRainDeployDeclaration.addMechanism(d, handler(CLONE_PER_NETWORK_MECHANISM, layer));
        LibRainDeployDeclaration.addMechanism(d, handler(BEACON_PROXY_MECHANISM, layer));
        LibRainDeployDeclaration.addMechanism(d, handler(BEACON_PROXY_PER_NETWORK_MECHANISM, layer));
    }

    function deployLocally(Vm vm, DeploySuite memory suite) internal returns (address[] memory) {
        uint256[] memory chainIds = addressChainIds(suite);
        address[] memory deployed = new address[](chainIds.length);
        for (uint256 i = 0; i < chainIds.length; i++) {
            deployed[i] = deployedAddress(suite, chainIds[i]);
        }
        LibRainDeploy.etchDependencies(vm, suite.dependencies);
        deployTargets(vm, suite, deployed);
        return deployed;
    }

    function deployLocallyOnChain(Vm vm, DeploySuite memory suite) internal {
        if (!isPerNetwork(suite)) {
            deployLocally(vm, suite);
            return;
        }
        bytes memory mechanismData = suite.mechanismData;
        suite.mechanismData = onChainMechanismData(suite, block.chainid);
        deployLocally(vm, suite);
        suite.mechanismData = mechanismData;
    }

    function addUnrecordedNetworks(DeploySuite memory suite, DeploySuite memory candidate, uint256[] memory chainIds)
        internal
        pure
    {
        suite.mechanismData = withUnrecordedNetworks(suite, candidate, chainIds).mechanismData;
    }

    /// Appends a per-network release's extended networks record, read under `LibRainDeploySnapshot.LIB_FS_ROOT`.
    function addRecordedNetworks(DeploySuite memory suite) internal view {
        if (!isPerNetwork(suite)) {
            return;
        }
        ChainDeploy[] memory extended = LibRainDeployExtendedNetworks.recordedExtendedNetworks(
            Vm(address(uint160(uint256(keccak256("hevm cheat code"))))), LibRainDeploySnapshot.LIB_FS_ROOT, suite.suite
        );
        suite.mechanismData = appendExtendedNetworks(suite, extended).mechanismData;
    }

    function logVerification(Vm vm, string[] memory networks, DeploySuite memory suite, address[] memory deployed)
        internal
    {
        if (!isProxyArtifactPath(suite.artifactPath)) {
            LibRainDeploy.logVerifyCommands(vm, networks, deployed[0], suite.artifactPath);
        } else {
            // slither-disable-next-line reentrancy-events
            emit UnverifiableSource(msg.sender, deployed[0], networks);
            console2.log(unverifiableSourceNotice(vm, networks, deployed[0]));
        }
    }

    /// @param mechanismData A suite's mechanism data.
    /// @return Its leading word, or zero when it is shorter than one.
    function mechanismTag(bytes memory mechanismData) internal pure returns (bytes32) {
        if (mechanismData.length < 0x20) {
            return bytes32(0);
        }
        return abi.decode(mechanismData, (bytes32));
    }

    /// @param suite The suite.
    /// @return Whether its mechanism data carries one of the four tags here.
    function isFactoryMechanism(DeploySuite memory suite) internal pure returns (bool) {
        bytes32 tag = mechanismTag(suite.mechanismData);
        return tag == CLONE_MECHANISM || tag == CLONE_PER_NETWORK_MECHANISM || tag == BEACON_PROXY_MECHANISM
            || tag == BEACON_PROXY_PER_NETWORK_MECHANISM;
    }

    /// @param suite The suite.
    /// @return Whether it is a per-network clone or beacon proxy.
    function isPerNetwork(DeploySuite memory suite) internal pure returns (bool) {
        bytes32 tag = mechanismTag(suite.mechanismData);
        return tag == CLONE_PER_NETWORK_MECHANISM || tag == BEACON_PROXY_PER_NETWORK_MECHANISM;
    }

    /// @param suite The suite.
    /// @return Whether it is a beacon proxy, per network or not.
    function isBeaconProxy(DeploySuite memory suite) internal pure returns (bool) {
        bytes32 tag = mechanismTag(suite.mechanismData);
        return tag == BEACON_PROXY_MECHANISM || tag == BEACON_PROXY_PER_NETWORK_MECHANISM;
    }

    /// @param suite The suite.
    /// @return The payload its tag wraps.
    function payload(DeploySuite memory suite) internal pure returns (bytes memory) {
        (, bytes memory data) = abi.decode(suite.mechanismData, (bytes32, bytes));
        return data;
    }

    /// The address `target` derives as a beacon proxy or as a clone.
    /// @param beaconProxy Whether `target` is a beacon proxy.
    /// @param target The factory call.
    /// @return The derived address.
    function targetAddress(bool beaconProxy, CloneTarget memory target) internal pure returns (address) {
        return beaconProxy
            ? LibRainDeployBeaconProxy.beaconProxyDeployedAddress(target)
            : LibRainDeployClone.cloneDeployedAddress(target);
    }

    /// @param suite A clone or beacon proxy suite.
    /// @param target One of its factory calls.
    /// @return The address `target` derives under `suite`'s mechanism.
    function targetAddress(DeploySuite memory suite, CloneTarget memory target) internal pure returns (address) {
        return targetAddress(isBeaconProxy(suite), target);
    }

    /// @param suite A clone or beacon proxy suite that is not per network.
    /// @return Its factory call, its dependencies checked against it.
    function cloneTarget(DeploySuite memory suite) internal pure returns (CloneTarget memory) {
        CloneTarget memory target = abi.decode(payload(suite), (CloneTarget));
        LibRainDeployClone.checkCloneDependencies(target, suite.dependencies);
        return target;
    }

    /// @param suite A per-network clone or beacon proxy suite.
    /// @return Its networks, refusing a stored deployed address and checking its networks and dependencies.
    function cloneNetworks(DeploySuite memory suite) internal pure returns (CloneNetworks memory) {
        if (suite.storedDeployedAddress != address(0)) {
            revert UnexpectedStoredDeployedAddress(suite.suite, suite.storedDeployedAddress);
        }
        CloneNetworks memory clones = abi.decode(payload(suite), (CloneNetworks));
        LibRainDeployClone.checkCloneNetworks(clones, suite.dependencies);
        return clones;
    }

    /// @param suite A clone or beacon proxy suite.
    /// @param chainId The network's chain id; ignored unless `suite` is per network.
    /// @return Its factory call on that network.
    function cloneTargetOn(DeploySuite memory suite, uint256 chainId) internal pure returns (CloneTarget memory) {
        if (isPerNetwork(suite)) {
            CloneNetworks memory clones = cloneNetworks(suite);
            return LibRainDeployClone.cloneNetworkTarget(clones, LibRainDeployClone.cloneNetworkIndex(clones, chainId));
        }
        return cloneTarget(suite);
    }

    /// @param suite A clone or beacon proxy suite.
    /// @param chainId The network's chain id.
    /// @return The address its factory call derives there.
    function deployedAddress(DeploySuite memory suite, uint256 chainId) internal pure returns (address) {
        return targetAddress(suite, cloneTargetOn(suite, chainId));
    }

    /// @param suite A clone or beacon proxy suite.
    /// @param chainId The network's chain id.
    /// @return The address it records there.
    function recordedAddress(DeploySuite memory suite, uint256 chainId) internal pure returns (address) {
        if (isPerNetwork(suite)) {
            CloneNetworks memory clones = cloneNetworks(suite);
            return clones.networks[LibRainDeployClone.cloneNetworkIndex(clones, chainId)].deployedAddress;
        }
        return suite.storedDeployedAddress;
    }

    /// @param suite A clone or beacon proxy suite.
    /// @return The chain id of each of its networks when per network, else none.
    function addressChainIds(DeploySuite memory suite) internal pure returns (uint256[] memory) {
        if (!isPerNetwork(suite)) {
            return new uint256[](0);
        }
        CloneNetworks memory clones = cloneNetworks(suite);
        uint256[] memory chainIds = new uint256[](clones.networks.length);
        for (uint256 i = 0; i < clones.networks.length; i++) {
            chainIds[i] = clones.networks[i].chainId;
        }
        return chainIds;
    }

    /// @param suite A clone or beacon proxy suite.
    /// @param chainId The network's chain id.
    /// @return The `abi.encode`d factory call its step makes there.
    function deployStepData(DeploySuite memory suite, uint256 chainId) internal pure returns (bytes memory) {
        return abi.encode(cloneTargetOn(suite, chainId));
    }

    /// @param suite A clone or beacon proxy suite.
    /// @return Its `LibRainDeploy.deployStepToNetworks` step.
    function deployStep(DeploySuite memory suite)
        internal
        pure
        returns (function(Vm, string memory, address, bytes memory) internal returns (address))
    {
        return
            isBeaconProxy(suite) ? LibRainDeployBeaconProxy.beaconProxyDeployStep : LibRainDeployClone.cloneDeployStep;
    }

    /// A per-network suite with an entry for every network in `chainIds` its candidate has and it lacks, each at the
    /// address the candidate's init data derives there. Any other suite, or one whose candidate is under another
    /// mechanism, is returned as it is.
    /// @param suite A clone or beacon proxy suite.
    /// @param candidate Its candidate, or `suite` when it has none.
    /// @param chainIds The chain ids in play.
    /// @return The suite with those networks.
    function withUnrecordedNetworks(DeploySuite memory suite, DeploySuite memory candidate, uint256[] memory chainIds)
        internal
        pure
        returns (DeploySuite memory)
    {
        if (!isPerNetwork(suite) || mechanismTag(candidate.mechanismData) != mechanismTag(suite.mechanismData)) {
            return suite;
        }
        CloneNetworks memory clones = cloneNetworks(suite);
        ChainDeploy[] memory declared = cloneNetworks(candidate).networks;
        uint256 recorded = clones.networks.length;
        ChainDeploy[] memory networks = new ChainDeploy[](recorded + declared.length);
        for (uint256 i = 0; i < recorded; i++) {
            networks[i] = clones.networks[i];
        }
        uint256 count = recorded;
        for (uint256 i = 0; i < declared.length; i++) {
            if (!hasChainId(networks, recorded, declared[i].chainId) && containsChainId(chainIds, declared[i].chainId))
            {
                networks[count] =
                    ChainDeploy({chainId: declared[i].chainId, data: declared[i].data, deployedAddress: address(0)});
                count++;
            }
        }
        clones.networks = new ChainDeploy[](count);
        for (uint256 i = 0; i < count; i++) {
            clones.networks[i] = networks[i];
        }
        for (uint256 i = recorded; i < count; i++) {
            clones.networks[i].deployedAddress = targetAddress(suite, LibRainDeployClone.cloneNetworkTarget(clones, i));
        }
        return withPayload(suite, abi.encode(clones));
    }

    /// A per-network release with `extended` appended, each checked to derive the address it declares. Refuses
    /// `ExtendedNetworksUnexpected` for any on a suite that is not per network.
    /// @param suite A clone or beacon proxy release.
    /// @param extended The networks declared for it beyond those it records.
    /// @return The release with them.
    function appendExtendedNetworks(DeploySuite memory suite, ChainDeploy[] memory extended)
        internal
        pure
        returns (DeploySuite memory)
    {
        if (extended.length == 0) {
            return suite;
        }
        if (!isPerNetwork(suite)) {
            revert ExtendedNetworksUnexpected(suite.suite);
        }
        CloneNetworks memory clones = cloneNetworks(suite);
        uint256 recorded = clones.networks.length;
        ChainDeploy[] memory networks = new ChainDeploy[](recorded + extended.length);
        for (uint256 i = 0; i < recorded; i++) {
            networks[i] = clones.networks[i];
        }
        for (uint256 i = 0; i < extended.length; i++) {
            networks[recorded + i] = extended[i];
        }
        clones.networks = networks;
        LibRainDeployClone.checkCloneNetworks(clones, suite.dependencies);
        for (uint256 i = recorded; i < networks.length; i++) {
            address derived = targetAddress(suite, LibRainDeployClone.cloneNetworkTarget(clones, i));
            if (derived != networks[i].deployedAddress) {
                revert ExtendedNetworkAddressMismatch(
                    suite.suite, networks[i].chainId, derived, networks[i].deployedAddress
                );
            }
        }
        return withPayload(suite, abi.encode(clones));
    }

    /// Refuses `ExtendedNetworkUnfrozen` for a per-network release on a network it neither records nor declares as
    /// extended.
    /// @param frozen The release with its extended networks.
    /// @param network The network's name.
    /// @param chainId The network's chain id.
    /// @param where The address checked on it.
    function checkNetworkFrozen(DeploySuite memory frozen, string memory network, uint256 chainId, address where)
        internal
        pure
    {
        if (!isPerNetwork(frozen)) {
            return;
        }
        CloneNetworks memory clones = cloneNetworks(frozen);
        if (!hasChainId(clones.networks, clones.networks.length, chainId)) {
            revert ExtendedNetworkUnfrozen(frozen.suite, network, where);
        }
    }

    /// @param suite A beacon proxy suite.
    /// @param chainId The network's chain id.
    /// @return The beacon its factory call names there.
    function beacon(DeploySuite memory suite, uint256 chainId) internal pure returns (address) {
        return cloneTargetOn(suite, chainId).implementation;
    }

    /// @param chainIds The chain ids.
    /// @param chainId The chain id sought.
    /// @return Whether `chainIds` holds `chainId`.
    function containsChainId(uint256[] memory chainIds, uint256 chainId) internal pure returns (bool) {
        for (uint256 i = 0; i < chainIds.length; i++) {
            if (chainIds[i] == chainId) {
                return true;
            }
        }
        return false;
    }

    /// @param networks The networks.
    /// @param count How many leading entries of `networks` to search.
    /// @param chainId The chain id sought.
    /// @return Whether one of the first `count` of `networks` is on `chainId`.
    function hasChainId(ChainDeploy[] memory networks, uint256 count, uint256 chainId) internal pure returns (bool) {
        for (uint256 i = 0; i < count; i++) {
            if (networks[i].chainId == chainId) {
                return true;
            }
        }
        return false;
    }

    /// @param suite A clone or beacon proxy suite.
    /// @param data The new payload.
    /// @return A copy of `suite` whose mechanism data wraps `data` under its tag.
    function withPayload(DeploySuite memory suite, bytes memory data) internal pure returns (DeploySuite memory) {
        return DeploySuite({
            suite: suite.suite,
            creationCode: suite.creationCode,
            storedDeployedAddress: suite.storedDeployedAddress,
            storedBytecodeHash: suite.storedBytecodeHash,
            storedRuntimeCode: suite.storedRuntimeCode,
            artifactPath: suite.artifactPath,
            dependencies: suite.dependencies,
            mechanismData: abi.encode(mechanismTag(suite.mechanismData), data),
            networks: suite.networks
        });
    }

    /// @param suite A per-network clone or beacon proxy suite.
    /// @param chainId The network's chain id.
    /// @return `suite`'s mechanism data cut down to its one network on `chainId`.
    function onChainMechanismData(DeploySuite memory suite, uint256 chainId) internal pure returns (bytes memory) {
        CloneNetworks memory clones = cloneNetworks(suite);
        ChainDeploy[] memory own = new ChainDeploy[](1);
        own[0] = clones.networks[LibRainDeployClone.cloneNetworkIndex(clones, chainId)];
        clones.networks = own;
        return abi.encode(mechanismTag(suite.mechanismData), abi.encode(clones));
    }

    /// Places each of a clone or beacon proxy suite's targets at its derived address: a clone through its factory, a
    /// beacon proxy by etching its frozen runtime code.
    /// @param vm The Vm instance to etch with.
    /// @param suite The suite.
    /// @param deployed Its derived addresses, in its address order.
    function deployTargets(Vm vm, DeploySuite memory suite, address[] memory deployed) internal {
        CloneTarget[] memory targets = cloneTargets(suite);
        bool beaconProxy = isBeaconProxy(suite);
        checkCloneCreationCode(suite, beaconProxy, targets[0].implementation);
        for (uint256 i = 0; i < targets.length; i++) {
            if (deployedEarlier(deployed, i)) {
                continue;
            }
            if (beaconProxy) {
                // The frozen runtime code is generated by the repo's Build script and checked by the `Git is
                // clean` job, so it is placed rather than derived here.
                vm.etch(deployed[i], suite.storedRuntimeCode);
            } else {
                deployCloneTarget(vm, suite.suite, beaconProxy, targets[i], deployed[i]);
            }
        }
    }

    /// @param suite A clone or beacon proxy suite.
    /// @return Its factory calls, in its address order.
    function cloneTargets(DeploySuite memory suite) internal pure returns (CloneTarget[] memory) {
        CloneTarget[] memory targets;
        if (isPerNetwork(suite)) {
            CloneNetworks memory clones = cloneNetworks(suite);
            targets = new CloneTarget[](clones.networks.length);
            for (uint256 i = 0; i < targets.length; i++) {
                targets[i] = LibRainDeployClone.cloneNetworkTarget(clones, i);
            }
        } else {
            targets = new CloneTarget[](1);
            targets[0] = cloneTarget(suite);
        }
        return targets;
    }

    /// Refuses `CloneCreationCodeMismatch` unless `suite`'s creation code is its mechanism's over `implementation`.
    /// @param suite The suite.
    /// @param beaconProxy Whether it is a beacon proxy.
    /// @param implementation The implementation, or the beacon for a beacon proxy.
    function checkCloneCreationCode(DeploySuite memory suite, bool beaconProxy, address implementation) internal pure {
        if (
            keccak256(suite.creationCode)
                != keccak256(
                    beaconProxy
                        ? LibRainDeployBeaconProxy.beaconProxyCreationCode(implementation)
                        : LibRainDeployClone.cloneCreationCode(implementation)
                )
        ) {
            revert CloneCreationCodeMismatch(suite.suite);
        }
    }

    /// Deploys one factory call locally, refusing a derivation mismatch and any read of storage not under the clone.
    /// @param vm The Vm instance to record with.
    /// @param suite The suite key.
    /// @param beaconProxy Whether the call deploys a beacon proxy.
    /// @param target The factory call.
    /// @param expected Its derived address.
    function deployCloneTarget(
        Vm vm,
        string memory suite,
        bool beaconProxy,
        CloneTarget memory target,
        address expected
    ) internal {
        vm.etch(expected, hex"");
        vm.resetNonce(expected);
        bytes memory factoryCall = beaconProxy
            ? abi.encodeCall(
                ICloneableFactoryV6(target.factory).beaconProxyDeterministicOpenSalt,
                (target.implementation, target.data, target.salt)
            )
            : abi.encodeCall(
                ICloneableFactoryV6(target.factory).cloneDeterministicOpenSalt,
                (target.implementation, target.data, target.salt)
            );
        vm.startStateDiffRecording();
        // slither-disable-next-line low-level-calls
        (bool success, bytes memory result) = target.factory.call(factoryCall);
        Vm.AccountAccess[] memory accesses = vm.stopAndReturnStateDiff();
        if (success) {
            address cloneAddress = abi.decode(result, (address));
            if (cloneAddress != expected) {
                revert CloneDerivationMismatch(suite, expected, cloneAddress);
            }
        }
        checkReadsOwnStorageOnly(suite, expected, accesses);
        if (!success) {
            assembly ("memory-safe") {
                revert(add(result, 0x20), mload(result))
            }
        }
    }

    /// Refuses `CloneInitializeReadsStorage` for a read of storage of an account not created under `clone`.
    /// @param suite The suite key.
    /// @param clone The clone.
    /// @param accesses The recorded state diff.
    function checkReadsOwnStorageOnly(string memory suite, address clone, Vm.AccountAccess[] memory accesses)
        internal
        pure
    {
        for (uint256 i = 0; i < accesses.length; i++) {
            for (uint256 j = 0; j < accesses[i].storageAccesses.length; j++) {
                Vm.StorageAccess memory access = accesses[i].storageAccesses[j];
                if (!access.isWrite && !createdUnder(access.account, clone, accesses)) {
                    revert CloneInitializeReadsStorage(suite, access.account, access.slot);
                }
            }
        }
    }

    /// @param account The account.
    /// @param clone The clone.
    /// @param accesses The recorded state diff.
    /// @return Whether `account` is `clone` or was created, at any depth, by it.
    function createdUnder(address account, address clone, Vm.AccountAccess[] memory accesses)
        internal
        pure
        returns (bool)
    {
        for (uint256 hops = 0; hops <= accesses.length; hops++) {
            if (account == clone) {
                return true;
            }
            (bool created, address creator) = creatorIn(account, accesses);
            if (!created) {
                return false;
            }
            account = creator;
        }
        return false;
    }

    /// @param account The account.
    /// @param accesses The recorded state diff.
    /// @return Whether `accesses` creates `account`, and its creator if so.
    function creatorIn(address account, Vm.AccountAccess[] memory accesses) internal pure returns (bool, address) {
        bool created = false;
        address creator = address(0);
        for (uint256 k = 0; k < accesses.length && !created; k++) {
            created = accesses[k].kind == VmSafe.AccountAccessKind.Create && accesses[k].account == account;
            creator = created ? accesses[k].accessor : address(0);
        }
        return (created, creator);
    }

    /// @param addresses The addresses.
    /// @param index The index checked.
    /// @return Whether an earlier entry of `addresses` equals the one at `index`.
    function deployedEarlier(address[] memory addresses, uint256 index) internal pure returns (bool) {
        for (uint256 j = 0; j < index; j++) {
            if (addresses[j] == addresses[index]) {
                return true;
            }
        }
        return false;
    }

    /// @param vm The Vm instance to format with.
    /// @param networks The networks broadcast to.
    /// @param where Where the entry is.
    /// @return The notice logged in place of a verify command.
    function unverifiableSourceNotice(Vm vm, string[] memory networks, address where)
        internal
        pure
        returns (string memory)
    {
        string memory notice = string.concat(
            "no verify command: the Zoltu entry carries a factory proxy artifact path; verify the source at ",
            vm.toString(where),
            " by hand on"
        );
        for (uint256 i = 0; i < networks.length; i++) {
            notice = string.concat(notice, " ", networks[i]);
        }
        return notice;
    }

    /// @param artifactPath The artifact path.
    /// @return Whether it is `CLONE_ARTIFACT_PATH` or `BEACON_PROXY_ARTIFACT_PATH`.
    function isProxyArtifactPath(string memory artifactPath) internal pure returns (bool) {
        bytes32 path = keccak256(bytes(artifactPath));
        return path == keccak256(bytes(CLONE_ARTIFACT_PATH)) || path == keccak256(bytes(BEACON_PROXY_ARTIFACT_PATH));
    }

    /// @param clone The clone declaration.
    /// @param chainIds The supported networks' chain ids.
    /// @return Its candidate.
    function cloneCandidate(CloneDeploy memory clone, uint256[] memory chainIds)
        internal
        view
        returns (DeployCandidate memory)
    {
        return factoryCandidate(clone, chainIds, false);
    }

    /// @param proxy The beacon proxy declaration.
    /// @param chainIds The supported networks' chain ids.
    /// @return Its candidate, carrying its declared runtime code.
    function beaconProxyCandidate(BeaconProxyDeploy memory proxy, uint256[] memory chainIds)
        internal
        view
        returns (DeployCandidate memory)
    {
        DeployCandidate memory candidate = factoryCandidate(
            CloneDeploy({
                suite: proxy.suite,
                factory: proxy.factory,
                implementation: proxy.beacon,
                data: proxy.data,
                initDataPerNetwork: proxy.initDataPerNetwork,
                initData: proxy.initData,
                salt: proxy.salt,
                dependencies: proxy.dependencies
            }),
            chainIds,
            true
        );
        candidate.snapshot.storedRuntimeCode = proxy.runtimeCode;
        candidate.snapshot.storedBytecodeHash = keccak256(proxy.runtimeCode);
        return candidate;
    }

    /// @param clone The declaration, a beacon proxy's beacon in `implementation`.
    /// @param chainIds The supported networks' chain ids.
    /// @param beaconProxy Whether it is a beacon proxy.
    /// @return Its candidate. Refuses `CloneDataAmbiguous` for per-network init data alongside `data`.
    function factoryCandidate(CloneDeploy memory clone, uint256[] memory chainIds, bool beaconProxy)
        internal
        view
        returns (DeployCandidate memory)
    {
        bytes memory mechanismData;
        address storedDeployedAddress = address(0);
        if (!clone.initDataPerNetwork) {
            CloneTarget memory target = CloneTarget({
                factory: clone.factory, implementation: clone.implementation, data: clone.data, salt: clone.salt
            });
            mechanismData = abi.encode(beaconProxy ? BEACON_PROXY_MECHANISM : CLONE_MECHANISM, abi.encode(target));
            storedDeployedAddress = targetAddress(beaconProxy, target);
        } else {
            if (clone.data.length != 0) {
                revert CloneDataAmbiguous(clone.suite);
            }
            CloneNetworks memory clones = CloneNetworks({
                factory: clone.factory,
                implementation: clone.implementation,
                salt: clone.salt,
                networks: new ChainDeploy[](chainIds.length)
            });
            for (uint256 i = 0; i < chainIds.length; i++) {
                clones.networks[i] =
                    ChainDeploy({chainId: chainIds[i], data: clone.initData(chainIds[i]), deployedAddress: address(0)});
                clones.networks[i].deployedAddress =
                    targetAddress(beaconProxy, LibRainDeployClone.cloneNetworkTarget(clones, i));
            }
            mechanismData = abi.encode(
                beaconProxy ? BEACON_PROXY_PER_NETWORK_MECHANISM : CLONE_PER_NETWORK_MECHANISM, abi.encode(clones)
            );
        }
        DeploySuite memory snapshot = DeploySuite({
            suite: clone.suite,
            creationCode: "",
            storedDeployedAddress: storedDeployedAddress,
            storedBytecodeHash: 0,
            storedRuntimeCode: "",
            artifactPath: "",
            dependencies: clone.dependencies,
            mechanismData: mechanismData,
            networks: new string[](0)
        });
        if (beaconProxy) {
            snapshot.creationCode = LibRainDeployBeaconProxy.beaconProxyCreationCode(clone.implementation);
            snapshot.artifactPath = BEACON_PROXY_ARTIFACT_PATH;
        } else {
            snapshot.creationCode = LibRainDeployClone.cloneCreationCode(clone.implementation);
            snapshot.storedRuntimeCode = LibRainDeployClone.cloneRuntimeCode(clone.implementation);
            snapshot.artifactPath = CLONE_ARTIFACT_PATH;
        }
        snapshot.storedBytecodeHash = keccak256(snapshot.storedRuntimeCode);
        return DeployCandidate({
            snapshot: snapshot,
            unanchorableReason: beaconProxy ? BEACON_PROXY_UNANCHORABLE_REASON : CLONE_UNANCHORABLE_REASON
        });
    }
}
