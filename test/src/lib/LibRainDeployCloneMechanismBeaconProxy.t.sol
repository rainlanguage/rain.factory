// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {Vm} from "forge-std-1.17.0/src/Vm.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/UpgradeableBeacon.sol";
import {
    DeployCandidate,
    DeployDeclaration,
    DeploySuite
} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {DeployDependency, LibRainDeploy} from "rain-deploy-0.1.29/src/lib/LibRainDeploy.sol";
import {LibRainDeployZoltuMechanism} from "rain-deploy-0.1.29/src/lib/LibRainDeployZoltuMechanism.sol";
import {
    CLONE_ARTIFACT_PATH,
    CloneNetworks,
    CloneTarget,
    LibRainDeployClone
} from "../../../src/lib/LibRainDeployClone.sol";
import {ChainDeploy} from "../../../src/lib/LibRainDeployExtendedNetworks.sol";
import {
    BEACON_PROXY_ARTIFACT_PATH,
    BEACON_PROXY_UNANCHORABLE_REASON,
    BeaconProxyDeploy,
    LibRainDeployBeaconProxy
} from "../../../src/lib/LibRainDeployBeaconProxy.sol";
import {
    BEACON_PROXY_MECHANISM,
    BEACON_PROXY_PER_NETWORK_MECHANISM,
    CLONE_MECHANISM,
    CLONE_PER_NETWORK_MECHANISM,
    CloneCreationCodeMismatch,
    CloneDataAmbiguous,
    ExtendedNetworksUnexpected,
    ExtendedNetworkUnfrozen,
    LibRainDeployCloneMechanism
} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {ExampleCloneDeploy} from "../../concrete/ExampleCloneDeploy.sol";
import {LocalForkVm} from "../../concrete/LocalForkVm.sol";
import {MockBeaconProxyFactory} from "../../concrete/MockBeaconProxyFactory.sol";
import {MockCloneableV2} from "../../concrete/MockCloneableV2.sol";
import {MockStorageReadingBeaconProxyFactory} from "../../concrete/MockStorageReadingBeaconProxyFactory.sol";
import {
    perNetworkCloneChainIds,
    perNetworkCloneInitData,
    perNetworkCloneNetworks
} from "../../abstract/PerNetworkCloneDeploys.sol";
import {LibBeaconProxyTest} from "../../lib/LibBeaconProxyTest.sol";

/// @title LibRainDeployCloneMechanismBeaconProxyTest
/// @notice The BEACON_PROXY mechanisms as `LibRainDeployCloneMechanism` reads them, directly and through the
/// example clone declaration: the candidate, the address and step dispatch, and the local deploy.
contract LibRainDeployCloneMechanismBeaconProxyTest is Test {
    bytes32 constant TEST_SALT = 0x1122334455667788990011223344556677889900112233445566778899001122;

    bytes constant TEST_DATA = hex"deadbeefcafe0102030405060708090a0b0c0d0e0f";

    ExampleCloneDeploy internal sDeploy;

    function setUp() external {
        sDeploy = new ExampleCloneDeploy();
    }

    /// @return An empty declaration, for the library's steps that read none of it.
    function noDeclaration() internal pure returns (DeployDeclaration memory) {
        DeployDeclaration memory d;
        return d;
    }

    /// A beacon proxy over a fresh factory and a fresh beacon, both declared as its dependencies.
    /// @param initDataPerNetwork Whether the init data is per network.
    /// @return The declaration.
    function declaredBeaconProxy(bool initDataPerNetwork) internal returns (BeaconProxyDeploy memory) {
        address beacon = address(new UpgradeableBeacon(address(new MockCloneableV2()), address(this)));
        return LibBeaconProxyTest.declared(
            "beacon-proxy",
            address(new MockBeaconProxyFactory()),
            beacon,
            TEST_DATA,
            initDataPerNetwork,
            TEST_SALT,
            LibBeaconProxyTest.runtimeOf(vm, beacon)
        );
    }

    /// @param proxy The declaration.
    /// @param chainIds The chain ids to build it for.
    /// @return The candidate.
    function candidateOf(BeaconProxyDeploy memory proxy, uint256[] memory chainIds)
        internal
        view
        returns (DeployCandidate memory)
    {
        return LibRainDeployCloneMechanism.beaconProxyCandidate(proxy, chainIds);
    }

    /// @param proxy The declaration.
    /// @param chainIds The chain ids to build it for.
    /// @return The candidate's suite, on Arbitrum One and Polygon.
    function suiteOf(BeaconProxyDeploy memory proxy, uint256[] memory chainIds)
        internal
        view
        returns (DeploySuite memory)
    {
        DeploySuite memory suite = candidateOf(proxy, chainIds).snapshot;
        suite.networks = perNetworkCloneNetworks();
        return suite;
    }

    /// @param suite A per-network suite.
    /// @return Its payload as `CloneNetworks`.
    function networksOf(DeploySuite memory suite) internal pure returns (CloneNetworks memory) {
        return abi.decode(LibRainDeployCloneMechanism.payload(suite), (CloneNetworks));
    }

    /// @param data The one init data for every network, set beside per-network init data.
    /// @return The candidate over `perNetworkCloneChainIds()`.
    function externalPerNetworkCandidateWithData(bytes memory data) external returns (DeployCandidate memory) {
        BeaconProxyDeploy memory proxy = declaredBeaconProxy(true);
        proxy.data = data;
        return candidateOf(proxy, perNetworkCloneChainIds());
    }

    /// Runs a suite's step through the declaration on a local Arbitrum One fork, as this contract.
    /// @param suite The suite whose step is run.
    /// @return The address the step reports.
    function runDeployStep(DeploySuite memory suite) internal returns (address) {
        return sDeploy.externalRunDeployStep(
            Vm(address(new LocalForkVm())),
            suite,
            LibRainDeploy.ARBITRUM_ONE,
            address(this),
            sDeploy.externalDeployStepData(suite, 42161)
        );
    }

    /// Every field of a one-data beacon proxy candidate is the beacon proxy derivation's, its mechanism data tagged
    /// `BEACON_PROXY_MECHANISM` over the target.
    function testBeaconProxyCandidateDerivesEveryField() external {
        BeaconProxyDeploy memory proxy = declaredBeaconProxy(false);
        CloneTarget memory target =
            CloneTarget({factory: proxy.factory, implementation: proxy.beacon, data: proxy.data, salt: proxy.salt});
        DeployCandidate memory candidate = candidateOf(proxy, perNetworkCloneChainIds());

        assertEq(candidate.snapshot.suite, proxy.suite);
        assertEq(candidate.snapshot.creationCode, LibRainDeployBeaconProxy.beaconProxyCreationCode(proxy.beacon));
        assertEq(candidate.snapshot.storedDeployedAddress, LibRainDeployBeaconProxy.beaconProxyDeployedAddress(target));
        assertEq(candidate.snapshot.storedRuntimeCode, proxy.runtimeCode);
        assertEq(candidate.snapshot.storedBytecodeHash, keccak256(proxy.runtimeCode));
        assertEq(candidate.snapshot.artifactPath, BEACON_PROXY_ARTIFACT_PATH);
        assertEq(LibRainDeployCloneMechanism.mechanismTag(candidate.snapshot.mechanismData), BEACON_PROXY_MECHANISM);
        assertEq(candidate.snapshot.mechanismData, abi.encode(BEACON_PROXY_MECHANISM, abi.encode(target)));
        assertEq(LibRainDeployCloneMechanism.payload(candidate.snapshot), abi.encode(target));
        assertEq(candidate.snapshot.dependencies.length, 2);
        assertEq(candidate.snapshot.dependencies[0].deployedAddress, proxy.factory);
        assertEq(candidate.snapshot.dependencies[1].deployedAddress, proxy.beacon);
        assertEq(candidate.unanchorableReason, BEACON_PROXY_UNANCHORABLE_REASON);
        assertNotEq(candidate.snapshot.storedDeployedAddress, LibRainDeployClone.cloneDeployedAddress(target));
    }

    /// A per-network beacon proxy candidate carries each network's init data and address, in the
    /// given chain id order, and no stored address.
    function testPerNetworkBeaconProxyCandidateDerivesEveryField() external {
        BeaconProxyDeploy memory proxy = declaredBeaconProxy(true);
        uint256[] memory chainIds = perNetworkCloneChainIds();
        DeployCandidate memory candidate = candidateOf(proxy, chainIds);

        assertEq(
            LibRainDeployCloneMechanism.mechanismTag(candidate.snapshot.mechanismData),
            BEACON_PROXY_PER_NETWORK_MECHANISM
        );
        assertEq(candidate.snapshot.storedDeployedAddress, address(0));
        assertEq(candidate.snapshot.creationCode, LibRainDeployBeaconProxy.beaconProxyCreationCode(proxy.beacon));
        assertEq(candidate.snapshot.storedRuntimeCode, proxy.runtimeCode);
        assertEq(candidate.snapshot.artifactPath, BEACON_PROXY_ARTIFACT_PATH);
        assertEq(candidate.unanchorableReason, BEACON_PROXY_UNANCHORABLE_REASON);

        CloneNetworks memory clones = networksOf(candidate.snapshot);
        assertEq(candidate.snapshot.mechanismData, abi.encode(BEACON_PROXY_PER_NETWORK_MECHANISM, abi.encode(clones)));
        assertEq(clones.factory, proxy.factory);
        assertEq(clones.implementation, proxy.beacon);
        assertEq(clones.salt, proxy.salt);
        assertEq(clones.networks.length, chainIds.length);
        for (uint256 i = 0; i < chainIds.length; i++) {
            assertEq(clones.networks[i].chainId, chainIds[i]);
            assertEq(clones.networks[i].data, perNetworkCloneInitData(chainIds[i]));
            CloneTarget memory target = CloneTarget({
                factory: proxy.factory, implementation: proxy.beacon, data: clones.networks[i].data, salt: proxy.salt
            });
            assertEq(clones.networks[i].deployedAddress, LibRainDeployBeaconProxy.beaconProxyDeployedAddress(target));
        }
        assertNotEq(clones.networks[0].deployedAddress, clones.networks[1].deployedAddress);
    }

    /// Each mechanism tag is per network or beacon proxy exactly as its name says, and the Zoltu tag is neither.
    function testIsPerNetworkAndIsBeaconProxyOfEveryMechanism() external pure {
        DeploySuite memory suite;
        suite.mechanismData = LibRainDeployZoltuMechanism.mechanismData();
        assertFalse(LibRainDeployCloneMechanism.isPerNetwork(suite));
        assertFalse(LibRainDeployCloneMechanism.isBeaconProxy(suite));
        suite.mechanismData = abi.encode(CLONE_MECHANISM, bytes(""));
        assertFalse(LibRainDeployCloneMechanism.isPerNetwork(suite));
        assertFalse(LibRainDeployCloneMechanism.isBeaconProxy(suite));
        suite.mechanismData = abi.encode(CLONE_PER_NETWORK_MECHANISM, bytes(""));
        assertTrue(LibRainDeployCloneMechanism.isPerNetwork(suite));
        assertFalse(LibRainDeployCloneMechanism.isBeaconProxy(suite));
        suite.mechanismData = abi.encode(BEACON_PROXY_MECHANISM, bytes(""));
        assertFalse(LibRainDeployCloneMechanism.isPerNetwork(suite));
        assertTrue(LibRainDeployCloneMechanism.isBeaconProxy(suite));
        suite.mechanismData = abi.encode(BEACON_PROXY_PER_NETWORK_MECHANISM, bytes(""));
        assertTrue(LibRainDeployCloneMechanism.isPerNetwork(suite));
        assertTrue(LibRainDeployCloneMechanism.isBeaconProxy(suite));
    }

    /// The target address follows the suite's mechanism tag: the beacon proxy derivation for a beacon
    /// proxy, the clone derivation for a clone.
    function testTargetAddressFollowsTheMechanism(CloneTarget memory target) external pure {
        DeploySuite memory suite;
        suite.mechanismData = abi.encode(BEACON_PROXY_MECHANISM, bytes(""));
        assertEq(
            LibRainDeployCloneMechanism.targetAddress(suite, target),
            LibRainDeployBeaconProxy.beaconProxyDeployedAddress(target)
        );
        suite.mechanismData = abi.encode(BEACON_PROXY_PER_NETWORK_MECHANISM, bytes(""));
        assertEq(
            LibRainDeployCloneMechanism.targetAddress(suite, target),
            LibRainDeployBeaconProxy.beaconProxyDeployedAddress(target)
        );
        suite.mechanismData = abi.encode(CLONE_MECHANISM, bytes(""));
        assertEq(
            LibRainDeployCloneMechanism.targetAddress(suite, target), LibRainDeployClone.cloneDeployedAddress(target)
        );
        suite.mechanismData = abi.encode(CLONE_PER_NETWORK_MECHANISM, bytes(""));
        assertEq(
            LibRainDeployCloneMechanism.targetAddress(suite, target), LibRainDeployClone.cloneDeployedAddress(target)
        );
    }

    /// A beacon proxy is placed locally at its derived address with its frozen runtime code, once for each of its
    /// networks, and its beacon is left as declared.
    function testBeaconProxySuiteDeploysLocallyToItsDerivedAddress() external {
        DeploySuite memory suite = suiteOf(declaredBeaconProxy(false), perNetworkCloneChainIds());
        address[] memory deployed = sDeploy.externalDeployLocally(vm, suite);
        assertEq(deployed, sDeploy.externalDeployedAddresses(suite));
        assertEq(deployed.length, suite.networks.length);
        for (uint256 i = 0; i < deployed.length; i++) {
            assertEq(deployed[i], suite.storedDeployedAddress);
        }
        assertEq(deployed[0].code, suite.storedRuntimeCode);
        address beacon = abi.decode(LibRainDeployCloneMechanism.payload(suite), (CloneTarget)).implementation;
        assertEq(beacon.code, suite.dependencies[1].runtimeCode);
    }

    /// A per-network beacon proxy deploys locally to each network's address.
    function testPerNetworkBeaconProxySuiteDeploysLocallyToEachNetworksAddress() external {
        DeploySuite memory suite = suiteOf(declaredBeaconProxy(true), perNetworkCloneChainIds());
        address[] memory deployed = sDeploy.externalDeployLocally(vm, suite);
        assertEq(deployed, sDeploy.externalDeployedAddresses(suite));
        assertEq(deployed.length, 2);
        assertNotEq(deployed[0], deployed[1]);
        assertEq(deployed[0].code, suite.storedRuntimeCode);
        assertEq(deployed[1].code, suite.storedRuntimeCode);
    }

    /// A beacon proxy's local derivation never calls its factory, so neither a factory landing off the formula nor
    /// one reading storage is reached: the frozen runtime code is placed at the derived address.
    function testBeaconProxyLocalDerivationNeverCallsTheFactory() external {
        DeploySuite memory suite = suiteOf(declaredBeaconProxy(false), perNetworkCloneChainIds());
        address factory = suite.dependencies[0].deployedAddress;
        suite.dependencies[0].runtimeCode = type(MockStorageReadingBeaconProxyFactory).runtimeCode;
        vm.expectCall(factory, bytes(""), 0);
        address[] memory deployed = sDeploy.externalDeployLocally(vm, suite);
        assertEq(deployed[0], suite.storedDeployedAddress);
        assertEq(deployed[0].code, suite.storedRuntimeCode);
    }

    /// A beacon proxy suite, one-data or per-network, that does not declare its beacon is refused
    /// naming the beacon, by the address derivation and the local deploy alike.
    function testBeaconProxySuiteMissingItsBeaconIsRefused(bool initDataPerNetwork) external {
        BeaconProxyDeploy memory proxy = declaredBeaconProxy(initDataPerNetwork);
        DeploySuite memory suite = suiteOf(proxy, perNetworkCloneChainIds());
        DeployDependency[] memory declared = suite.dependencies;
        suite.dependencies = new DeployDependency[](1);
        suite.dependencies[0] = declared[0];
        vm.expectRevert(abi.encodeWithSelector(LibRainDeployClone.CloneDependencyUndeclared.selector, proxy.beacon));
        sDeploy.externalDeployedAddresses(suite);
        vm.expectRevert(abi.encodeWithSelector(LibRainDeployClone.CloneDependencyUndeclared.selector, proxy.beacon));
        sDeploy.externalDeployLocally(vm, suite);
    }

    /// A beacon proxy declaration with init data per network AND one init data for every network is
    /// refused naming its suite.
    function testBeaconProxyCandidateRefusesDataBesidePerNetworkData(bytes memory data) external {
        vm.assume(data.length != 0);
        vm.expectRevert(abi.encodeWithSelector(CloneDataAmbiguous.selector, "beacon-proxy"));
        this.externalPerNetworkCandidateWithData(data);
    }

    /// A beacon proxy suite whose creation code is not the beacon proxy's over its beacon is
    /// refused, including the clone creation code over the same beacon.
    function testBeaconProxyCreationCodeThatIsNotTheProxyIsRefused() external {
        BeaconProxyDeploy memory proxy = declaredBeaconProxy(false);
        DeploySuite memory suite = suiteOf(proxy, perNetworkCloneChainIds());

        suite.creationCode = LibRainDeployClone.cloneCreationCode(proxy.beacon);
        vm.expectRevert(abi.encodeWithSelector(CloneCreationCodeMismatch.selector, suite.suite));
        sDeploy.externalDeployLocally(vm, suite);

        suite.creationCode = LibRainDeployBeaconProxy.beaconProxyCreationCode(proxy.factory);
        vm.expectRevert(abi.encodeWithSelector(CloneCreationCodeMismatch.selector, suite.suite));
        sDeploy.externalDeployLocally(vm, suite);
    }

    /// A clone suite over a beacon proxy's target is refused as a creation code mismatch: the
    /// mechanism tag, not the target, says which proxy is deployed.
    function testCloneSuiteCarryingBeaconProxyCreationCodeIsRefused() external {
        DeploySuite memory suite = suiteOf(declaredBeaconProxy(false), perNetworkCloneChainIds());
        suite.mechanismData = abi.encode(CLONE_MECHANISM, LibRainDeployCloneMechanism.payload(suite));
        vm.expectRevert(abi.encodeWithSelector(CloneCreationCodeMismatch.selector, suite.suite));
        sDeploy.externalDeployLocally(vm, suite);
    }

    /// A beacon proxy suite's deploy step is the beacon proxy step, deploying to its derived
    /// address with the beacon proxy's code.
    function testBeaconProxyDeployStepIsTheBeaconProxyStep() external {
        DeploySuite memory suite = suiteOf(declaredBeaconProxy(false), perNetworkCloneChainIds());
        address deployed = runDeployStep(suite);
        assertEq(deployed, suite.storedDeployedAddress);
        assertEq(deployed.codehash, suite.storedBytecodeHash);
    }

    /// A per-network beacon proxy suite's deploy step deploys that network's proxy.
    function testPerNetworkBeaconProxyDeployStepDeploysThatNetworksProxy() external {
        DeploySuite memory suite = suiteOf(declaredBeaconProxy(true), perNetworkCloneChainIds());
        address deployed = runDeployStep(suite);
        assertEq(deployed, sDeploy.externalDeployedAddress(suite, 42161));
        assertEq(deployed.codehash, suite.storedBytecodeHash);
    }

    /// The address the beacon proxy derivation gives a per-network beacon proxy on one network.
    /// @param proxy The declaration.
    /// @param chainId The network's chain id.
    /// @return The address.
    function beaconProxyAddressOn(BeaconProxyDeploy memory proxy, uint256 chainId) internal pure returns (address) {
        return LibRainDeployBeaconProxy.beaconProxyDeployedAddress(
            CloneTarget({
                factory: proxy.factory,
                implementation: proxy.beacon,
                data: perNetworkCloneInitData(chainId),
                salt: proxy.salt
            })
        );
    }

    /// A per-network beacon proxy suite recording only its first network.
    /// @param suite The suite.
    /// @return The suite with its other networks dropped.
    function firstNetworkOnly(DeploySuite memory suite) internal pure returns (DeploySuite memory) {
        CloneNetworks memory clones = networksOf(suite);
        ChainDeploy[] memory first = new ChainDeploy[](1);
        first[0] = clones.networks[0];
        clones.networks = first;
        return LibRainDeployCloneMechanism.withPayload(suite, abi.encode(clones));
    }

    /// @param suite The release.
    /// @param extended The networks declared for it.
    /// @return The release with them.
    function externalWithExtendedNetworks(DeploySuite memory suite, ChainDeploy[] memory extended)
        external
        pure
        returns (DeploySuite memory)
    {
        return LibRainDeployCloneMechanism.appendExtendedNetworks(suite, extended);
    }

    /// A per-network beacon proxy records, and is addressed by, each network's own beacon proxy.
    function testPerNetworkBeaconProxyRecordsEachNetworksAddress() external {
        BeaconProxyDeploy memory proxy = declaredBeaconProxy(true);
        uint256[] memory chainIds = perNetworkCloneChainIds();
        DeploySuite memory suite = suiteOf(proxy, chainIds);

        address[] memory recorded = sDeploy.externalRecordedAddresses(suite);
        assertEq(recorded.length, 2);
        assertEq(LibRainDeployCloneMechanism.addressChainIds(suite), chainIds);
        for (uint256 i = 0; i < chainIds.length; i++) {
            assertEq(recorded[i], beaconProxyAddressOn(proxy, chainIds[i]));
            assertEq(sDeploy.externalRecordedAddress(suite, chainIds[i]), beaconProxyAddressOn(proxy, chainIds[i]));
        }
    }

    /// A per-network beacon proxy recording one network takes its candidate's other network in play at that
    /// network's beacon proxy address, and takes nothing from a per-network clone candidate.
    function testPerNetworkBeaconProxyTakesItsCandidatesUnrecordedNetworks() external {
        BeaconProxyDeploy memory proxy = declaredBeaconProxy(true);
        uint256[] memory chainIds = perNetworkCloneChainIds();
        DeploySuite memory candidate = suiteOf(proxy, chainIds);
        DeploySuite memory release = firstNetworkOnly(candidate);

        DeploySuite memory onNetworks = LibRainDeployCloneMechanism.withUnrecordedNetworks(release, candidate, chainIds);
        ChainDeploy[] memory networks = networksOf(onNetworks).networks;
        assertEq(networks.length, 2);
        assertEq(networks[0].chainId, chainIds[0]);
        assertEq(networks[0].deployedAddress, beaconProxyAddressOn(proxy, chainIds[0]));
        assertEq(networks[1].chainId, chainIds[1]);
        assertEq(networks[1].data, perNetworkCloneInitData(chainIds[1]));
        assertEq(networks[1].deployedAddress, beaconProxyAddressOn(proxy, chainIds[1]));

        DeploySuite memory cloneCandidate = suiteOf(proxy, chainIds);
        cloneCandidate.mechanismData =
            abi.encode(CLONE_PER_NETWORK_MECHANISM, LibRainDeployCloneMechanism.payload(cloneCandidate));
        assertEq(
            LibRainDeployCloneMechanism.withUnrecordedNetworks(release, cloneCandidate, chainIds).mechanismData,
            release.mechanismData
        );
    }

    /// A per-network beacon proxy takes an extended network held to that network's beacon proxy address.
    function testPerNetworkBeaconProxyTakesAnExtendedNetworkAtItsBeaconProxyAddress() external {
        BeaconProxyDeploy memory proxy = declaredBeaconProxy(true);
        uint256[] memory chainIds = perNetworkCloneChainIds();
        DeploySuite memory release = firstNetworkOnly(suiteOf(proxy, chainIds));
        ChainDeploy[] memory extended = new ChainDeploy[](1);
        extended[0] = ChainDeploy({
            chainId: chainIds[1],
            data: perNetworkCloneInitData(chainIds[1]),
            deployedAddress: beaconProxyAddressOn(proxy, chainIds[1])
        });

        DeploySuite memory frozen = this.externalWithExtendedNetworks(release, extended);
        assertEq(sDeploy.externalRecordedAddresses(frozen).length, 2);
        assertEq(sDeploy.externalRecordedAddress(frozen, chainIds[1]), beaconProxyAddressOn(proxy, chainIds[1]));
    }

    /// Extended networks on a one-data beacon proxy suite are refused.
    function testExtendedNetworksOnAOneDataBeaconProxyAreRefused() external {
        DeploySuite memory oneData = suiteOf(declaredBeaconProxy(false), perNetworkCloneChainIds());
        ChainDeploy[] memory extended = new ChainDeploy[](1);
        extended[0] = ChainDeploy({chainId: 137, data: TEST_DATA, deployedAddress: oneData.storedDeployedAddress});
        vm.expectRevert(abi.encodeWithSelector(ExtendedNetworksUnexpected.selector, oneData.suite));
        this.externalWithExtendedNetworks(oneData, extended);
    }

    /// A per-network beacon proxy is frozen only on the networks it records, and a broadcast to another is refused.
    function testPerNetworkBeaconProxyIsFrozenOnlyOnItsRecordedNetworks() external {
        BeaconProxyDeploy memory proxy = declaredBeaconProxy(true);
        uint256[] memory chainIds = perNetworkCloneChainIds();
        DeploySuite memory candidate = suiteOf(proxy, chainIds);
        DeploySuite memory release = firstNetworkOnly(candidate);
        address polygonAddress = beaconProxyAddressOn(proxy, chainIds[1]);

        sDeploy.externalCheckNetworkFrozen(release, "net", chainIds[0], address(1));
        vm.expectRevert(abi.encodeWithSelector(ExtendedNetworkUnfrozen.selector, release.suite, "net", address(2)));
        sDeploy.externalCheckNetworkFrozen(release, "net", chainIds[1], address(2));

        string[] memory networks = new string[](2);
        networks[0] = LibRainDeploy.ARBITRUM_ONE;
        networks[1] = LibRainDeploy.POLYGON;
        DeploySuite memory onNetworks = LibRainDeployCloneMechanism.withUnrecordedNetworks(release, candidate, chainIds);
        vm.expectRevert(
            abi.encodeWithSelector(
                ExtendedNetworkUnfrozen.selector, release.suite, LibRainDeploy.POLYGON, polygonAddress
            )
        );
        sDeploy.externalCheckNetworksFrozen(release, onNetworks, networks);
    }

    /// A per-network beacon proxy deployed locally on one chain deploys only that network's proxy, and keeps its
    /// mechanism data.
    function testPerNetworkBeaconProxyDeploysLocallyOnChainOnlyThatNetworksProxy() external {
        BeaconProxyDeploy memory proxy = declaredBeaconProxy(true);
        uint256[] memory chainIds = perNetworkCloneChainIds();
        DeploySuite memory suite = suiteOf(proxy, chainIds);
        bytes memory mechanismData = suite.mechanismData;

        vm.chainId(chainIds[1]);
        LibRainDeployCloneMechanism.deployLocallyOnChain(noDeclaration(), vm, suite);
        assertEq(suite.mechanismData, mechanismData);
        assertEq(beaconProxyAddressOn(proxy, chainIds[1]).code, suite.storedRuntimeCode);
        assertEq(beaconProxyAddressOn(proxy, chainIds[0]).code.length, 0);
    }
}
