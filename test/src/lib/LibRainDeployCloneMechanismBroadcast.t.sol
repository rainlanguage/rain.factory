// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {DeployDependency, LibRainDeploy} from "rain-deploy-0.1.27/src/lib/LibRainDeploy.sol";
import {
    CLONE_ARTIFACT_PATH,
    CloneNetworks,
    CloneTarget,
    LibRainDeployClone
} from "../../../src/lib/LibRainDeployClone.sol";
import {ChainDeploy} from "../../../src/lib/LibRainDeployExtendedNetworks.sol";
import {
    CLONE_MECHANISM,
    CLONE_PER_NETWORK_MECHANISM,
    ExtendedNetworkUnfrozen,
    LibRainDeployCloneMechanism,
    UnexpectedStoredDeployedAddress,
    UnverifiableSource
} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {DeploySuite, UnexpectedMechanismData} from "rain-deploy-0.1.27/src/abstract/RainDeploySuitesBase.sol";
import {
    LibRainDeployZoltuMechanism,
    ZOLTU_MECHANISM_ID
} from "rain-deploy-0.1.27/src/lib/LibRainDeployZoltuMechanism.sol";
import {BEACON_PROXY_ARTIFACT_PATH, LibRainDeployBeaconProxy} from "../../../src/lib/LibRainDeployBeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/UpgradeableBeacon.sol";
import {MockBeaconProxyFactory} from "../../concrete/MockBeaconProxyFactory.sol";
import {MockOriginOwnedCloneable} from "../../concrete/MockOriginOwnedCloneable.sol";
import {LibBeaconProxyTest} from "../../lib/LibBeaconProxyTest.sol";
import {perNetworkCloneChainIds} from "../../abstract/PerNetworkCloneDeploys.sol";
import {
    exampleCloneDependencies,
    exampleCloneFactory,
    exampleCloneImplementation
} from "../../abstract/ExampleCloneDeploys.sol";
import {ExampleCloneDeploy} from "../../concrete/ExampleCloneDeploy.sol";
import {ZoltuDeployOrAdopt} from "../../abstract/ZoltuDeployOrAdopt.sol";
import {MockCloneFactory} from "../../concrete/MockCloneFactory.sol";
import {MockCloneable} from "../../concrete/MockCloneable.sol";
import {LocalForkVm} from "../../concrete/LocalForkVm.sol";
import {Vm} from "forge-std-1.17.0/src/Vm.sol";

/// @title LibRainDeployCloneMechanismBroadcastTest
/// @notice `deployAndBroadcast` through the example clone declaration, over clone, per-network clone, beacon proxy
/// and Zoltu suites.
contract LibRainDeployCloneMechanismBroadcastTest is ZoltuDeployOrAdopt {
    bytes32 constant TEST_SALT = 0x1122334455667788990011223344556677889900112233445566778899001122;

    bytes constant TEST_DATA = hex"deadbeefcafe0102030405060708090a0b0c0d0e0f";

    ExampleCloneDeploy internal sDeploy;

    function setUp() external {
        sDeploy = new ExampleCloneDeploy();
        vm.makePersistent(address(sDeploy));
    }

    function localClone(address factory, address implementation) internal pure returns (CloneTarget memory) {
        return CloneTarget({factory: factory, implementation: implementation, data: TEST_DATA, salt: TEST_SALT});
    }

    function cloneSuite(
        CloneTarget memory clone,
        address recordedAddress,
        bytes32 codeHash,
        DeployDependency[] memory dependencies
    ) internal pure returns (DeploySuite memory) {
        return DeploySuite({
            suite: "clone",
            creationCode: LibRainDeployClone.cloneCreationCode(clone.implementation),
            storedDeployedAddress: recordedAddress,
            storedBytecodeHash: codeHash,
            storedRuntimeCode: "",
            artifactPath: CLONE_ARTIFACT_PATH,
            dependencies: dependencies,
            mechanismData: abi.encode(CLONE_MECHANISM, abi.encode(clone)),
            networks: arbitrumAndPolygon()
        });
    }

    function exampleCloneNetworks() internal pure returns (CloneNetworks memory) {
        CloneNetworks memory clones = CloneNetworks({
            factory: exampleCloneFactory(),
            implementation: exampleCloneImplementation(),
            salt: TEST_SALT,
            networks: new ChainDeploy[](2)
        });
        clones.networks[0] =
            ChainDeploy({chainId: 42161, data: abi.encode(uint256(42161)), deployedAddress: address(0)});
        clones.networks[1] = ChainDeploy({chainId: 137, data: abi.encode(uint256(137)), deployedAddress: address(0)});
        for (uint256 i = 0; i < clones.networks.length; i++) {
            clones.networks[i].deployedAddress =
                LibRainDeployClone.cloneDeployedAddress(LibRainDeployClone.cloneNetworkTarget(clones, i));
        }
        return clones;
    }

    function perNetworkSuite(CloneNetworks memory clones) internal pure returns (DeploySuite memory) {
        return DeploySuite({
            suite: "clone-per-network",
            creationCode: LibRainDeployClone.cloneCreationCode(clones.implementation),
            storedDeployedAddress: address(0),
            storedBytecodeHash: bytes32(0),
            storedRuntimeCode: "",
            artifactPath: CLONE_ARTIFACT_PATH,
            dependencies: exampleCloneDependencies(),
            mechanismData: abi.encode(CLONE_PER_NETWORK_MECHANISM, abi.encode(clones)),
            networks: arbitrumAndPolygon()
        });
    }

    function zoltuSuite(address recordedAddress) internal pure returns (DeploySuite memory) {
        return DeploySuite({
            suite: "zoltu",
            creationCode: type(MockCloneable).creationCode,
            storedDeployedAddress: recordedAddress,
            storedBytecodeHash: bytes32(0),
            storedRuntimeCode: "",
            artifactPath: "test/concrete/MockCloneable.sol:MockCloneable",
            dependencies: new DeployDependency[](0),
            mechanismData: LibRainDeployZoltuMechanism.mechanismData(),
            networks: arbitrumAndPolygon()
        });
    }

    /// `exampleCloneNetworks` as a release recording Arbitrum One alone, with Polygon declared as extended at the
    /// address its init data derives: the frozen suite `appendExtendedNetworks` gives.
    /// @return The frozen suite.
    function frozenExampleCloneNetworks() internal pure returns (DeploySuite memory) {
        CloneNetworks memory clones = exampleCloneNetworks();
        ChainDeploy[] memory extended = new ChainDeploy[](1);
        extended[0] = clones.networks[1];
        clones.networks = new ChainDeploy[](1);
        clones.networks[0] = exampleCloneNetworks().networks[0];
        return LibRainDeployCloneMechanism.appendExtendedNetworks(perNetworkSuite(clones), extended);
    }

    /// A clone broadcast formats no verify command, even under a compiled artifact's path.
    function testCloneBroadcastPrintsNoVerifyCommand() external {
        address factory = LibRainDeploy.etchAndDeployZoltu(vm, type(MockCloneFactory).creationCode);
        address implementation = LibRainDeploy.etchAndDeployZoltu(vm, type(MockCloneable).creationCode);
        CloneTarget memory clone = localClone(factory, implementation);
        address expected = LibRainDeployClone.cloneDeployedAddress(clone);
        DeploySuite memory suite = cloneSuite(
            clone, expected, LibRainDeployClone.cloneDeployedCodehash(implementation), exampleCloneDependencies()
        );
        suite.artifactPath = "test/concrete/MockCloneable.sol:MockCloneable";
        string[] memory networks = new string[](1);
        networks[0] = LibRainDeploy.ARBITRUM_ONE;

        LocalForkVm forkVm = new LocalForkVm();
        vm.expectCall(address(forkVm), abi.encodeWithSignature("toString(address)"), 0);
        (address[] memory deployed,) = sDeploy.externalDeployAndBroadcast(Vm(address(forkVm)), networks, 1, suite, suite);
        assertEq(deployed.length, 1);
        assertEq(deployed[0], expected);
        assertEq(deployed[0].code, LibRainDeployClone.cloneRuntimeCode(implementation));
    }

    /// A Zoltu broadcast under `CLONE_ARTIFACT_PATH` formats no verify command, and instead one notice naming the
    /// deployed address once, whose source needs verifying by hand on each network, emitted as `UnverifiableSource`
    /// with the caller, not the deploy, as its sender.
    function testZoltuBroadcastUnderTheCloneArtifactPathPrintsAManualVerificationNotice() external {
        LibRainDeploy.etchZoltuFactory(vm);
        DeploySuite memory suite = zoltuSuite(LibRainDeploy.zoltuAddress(type(MockCloneable).creationCode));
        suite.storedBytecodeHash = keccak256(type(MockCloneable).runtimeCode);
        suite.artifactPath = CLONE_ARTIFACT_PATH;
        string[] memory networks = arbitrumAndPolygon();

        address caller = makeAddr("broadcast caller");
        LocalForkVm forkVm = new LocalForkVm();
        vm.expectCall(address(forkVm), abi.encodeWithSignature("toString(address)"), 1);
        vm.expectCall(address(forkVm), abi.encodeWithSignature("toString(address)", suite.storedDeployedAddress), 1);
        vm.expectEmit(address(sDeploy));
        emit UnverifiableSource(caller, suite.storedDeployedAddress, networks);
        vm.prank(caller);
        (address[] memory deployed,) = sDeploy.externalDeployAndBroadcast(Vm(address(forkVm)), networks, 1, suite, suite);
        assertEq(deployed.length, 2);
        assertEq(deployed[0], suite.storedDeployedAddress);
        assertEq(deployed[1], suite.storedDeployedAddress);
        assertEq(deployed[0].code, type(MockCloneable).runtimeCode);
    }

    /// `UnverifiableSource` indexes nothing: its one log carries the signature as its only topic, and the sender,
    /// entry address and networks ABI-encoded in its data.
    function testUnverifiableSourceLogsEveryArgumentAsData() external {
        LibRainDeploy.etchZoltuFactory(vm);
        DeploySuite memory suite = zoltuSuite(LibRainDeploy.zoltuAddress(type(MockCloneable).creationCode));
        suite.storedBytecodeHash = keccak256(type(MockCloneable).runtimeCode);
        suite.artifactPath = CLONE_ARTIFACT_PATH;
        string[] memory networks = arbitrumAndPolygon();

        address caller = makeAddr("broadcast caller");
        LocalForkVm forkVm = new LocalForkVm();
        vm.recordLogs();
        vm.prank(caller);
        sDeploy.externalDeployAndBroadcast(Vm(address(forkVm)), networks, 1, suite, suite);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bytes32 signature = keccak256("UnverifiableSource(address,address,string[])");
        uint256 found = 0;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == signature) {
                found++;
                assertEq(logs[i].emitter, address(sDeploy));
                assertEq(logs[i].topics.length, 1);
                assertEq(logs[i].data, abi.encode(caller, suite.storedDeployedAddress, networks));
            }
        }
        assertEq(found, 1);
    }

    /// A Zoltu broadcast under `BEACON_PROXY_ARTIFACT_PATH` is treated as one under `CLONE_ARTIFACT_PATH`: one
    /// `UnverifiableSource` notice and no verify command.
    function testZoltuBroadcastUnderTheBeaconProxyArtifactPathPrintsAManualVerificationNotice() external {
        LibRainDeploy.etchZoltuFactory(vm);
        DeploySuite memory suite = zoltuSuite(LibRainDeploy.zoltuAddress(type(MockCloneable).creationCode));
        suite.storedBytecodeHash = keccak256(type(MockCloneable).runtimeCode);
        suite.artifactPath = BEACON_PROXY_ARTIFACT_PATH;
        string[] memory networks = arbitrumAndPolygon();

        address caller = makeAddr("broadcast caller");
        LocalForkVm forkVm = new LocalForkVm();
        vm.expectCall(address(forkVm), abi.encodeWithSelector(bytes4(keccak256("toString(address)"))), 1);
        vm.expectCall(
            address(forkVm),
            abi.encodeWithSelector(bytes4(keccak256("toString(address)")), suite.storedDeployedAddress),
            1
        );
        vm.expectEmit(address(sDeploy));
        emit UnverifiableSource(caller, suite.storedDeployedAddress, networks);
        vm.prank(caller);
        (address[] memory deployed,) = sDeploy.externalDeployAndBroadcast(Vm(address(forkVm)), networks, 1, suite, suite);
        assertEq(deployed.length, 2);
        assertEq(deployed[0], suite.storedDeployedAddress);
        assertEq(deployed[1], suite.storedDeployedAddress);
    }

    /// A beacon proxy suite over a fresh factory and a beacon of `MockOriginOwnedCloneable`, seating `owner`, on
    /// Arbitrum One and Polygon.
    /// @param owner The owner the proxy's init data names.
    /// @return The suite.
    function ownedBeaconProxySuite(address owner) internal returns (DeploySuite memory) {
        address beacon = address(new UpgradeableBeacon(address(new MockOriginOwnedCloneable()), address(this)));
        DeploySuite memory suite = LibRainDeployCloneMechanism.beaconProxyCandidate(
            LibBeaconProxyTest.declared(
                "owned-beacon-proxy",
                address(new MockBeaconProxyFactory()),
                beacon,
                abi.encode(owner),
                false,
                TEST_SALT,
                LibBeaconProxyTest.runtimeOf(vm, beacon)
            ),
            perNetworkCloneChainIds()
        )
        .snapshot;
        suite.networks = arbitrumAndPolygon();
        return suite;
    }

    /// A beacon proxy broadcast that would seat the deploy key is refused on the network's fork, naming the network
    /// and the proxy's derived address.
    function testBeaconProxyBroadcastRefusesTheDeployKeySeated() external {
        DeploySuite memory suite = ownedBeaconProxySuite(vm.addr(1));
        address derived = sDeploy.externalDeployedAddress(suite, 42161);
        string[] memory networks = new string[](1);
        networks[0] = LibRainDeploy.ARBITRUM_ONE;
        Vm forkVm = Vm(address(new LocalForkVm()));
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRainDeployBeaconProxy.BeaconProxySeatsDeployKey.selector, LibRainDeploy.ARBITRUM_ONE, derived
            )
        );
        sDeploy.externalDeployAndBroadcast(forkVm, networks, 1, suite, suite);
    }

    /// A beacon proxy broadcast seating anyone but the deploy key deploys the proxy at its derived address.
    function testBeaconProxyBroadcastSeatsAnotherOwner(address owner) external {
        vm.assume(owner != vm.addr(1) && owner != address(0));
        DeploySuite memory suite = ownedBeaconProxySuite(owner);
        address derived = sDeploy.externalDeployedAddress(suite, 42161);
        string[] memory networks = new string[](1);
        networks[0] = LibRainDeploy.ARBITRUM_ONE;
        (address[] memory deployed,) =
            sDeploy.externalDeployAndBroadcast(Vm(address(new LocalForkVm())), networks, 1, suite, suite);
        assertEq(deployed.length, 1);
        assertEq(deployed[0], derived);
        assertEq(MockOriginOwnedCloneable(derived).owner(), owner);
    }

    /// A per-network clone broadcast formats no verify command and no notice, even under a compiled artifact's path.
    function testPerNetworkBroadcastUnderACompiledArtifactPrintsNoVerifyCommand() external {
        LibRainDeploy.etchAndDeployZoltu(vm, type(MockCloneFactory).creationCode);
        address implementation = LibRainDeploy.etchAndDeployZoltu(vm, type(MockCloneable).creationCode);
        CloneNetworks memory clones = exampleCloneNetworks();
        DeploySuite memory frozen = frozenExampleCloneNetworks();
        frozen.storedBytecodeHash = LibRainDeployClone.cloneDeployedCodehash(implementation);
        frozen.artifactPath = "test/concrete/MockCloneable.sol:MockCloneable";
        LocalForkVm forkVm = new LocalForkVm();
        vm.expectCall(address(forkVm), abi.encodeWithSignature("toString(address)"), 0);
        (address[] memory deployed,) = sDeploy.externalDeployAndBroadcast(
            Vm(address(forkVm)), arbitrumAndPolygon(), 1, frozen, perNetworkSuite(clones)
        );
        assertEq(deployed.length, 2);
        assertEq(deployed[0], clones.networks[0].deployedAddress);
        assertEq(deployed[1], clones.networks[1].deployedAddress);
    }

    /// A release recording Arbitrum One alone, with Polygon declared at init data other than the candidate's, lands on
    /// Polygon at the declared address with the declared data, not where the candidate's data derives.
    function testBroadcastsAnExtendedNetworkAtItsDeclaredDataOffline() external {
        LibRainDeploy.etchAndDeployZoltu(vm, type(MockCloneFactory).creationCode);
        address implementation = LibRainDeploy.etchAndDeployZoltu(vm, type(MockCloneable).creationCode);
        CloneNetworks memory candidate = exampleCloneNetworks();
        CloneNetworks memory recorded = exampleCloneNetworks();
        recorded.networks = new ChainDeploy[](1);
        recorded.networks[0] = candidate.networks[0];
        ChainDeploy[] memory extended = new ChainDeploy[](1);
        extended[0] = ChainDeploy({chainId: 137, data: abi.encode(uint256(0xc4)), deployedAddress: address(0)});
        CloneNetworks memory declaredClones = exampleCloneNetworks();
        declaredClones.networks[1].data = extended[0].data;
        extended[0].deployedAddress =
            LibRainDeployClone.cloneDeployedAddress(LibRainDeployClone.cloneNetworkTarget(declaredClones, 1));
        assertNotEq(extended[0].deployedAddress, candidate.networks[1].deployedAddress);
        DeploySuite memory frozen =
            LibRainDeployCloneMechanism.appendExtendedNetworks(perNetworkSuite(recorded), extended);
        frozen.storedBytecodeHash = LibRainDeployClone.cloneDeployedCodehash(implementation);

        (address[] memory deployed,) = sDeploy.externalDeployAndBroadcast(
            Vm(address(new LocalForkVm())), arbitrumAndPolygon(), 1, frozen, perNetworkSuite(candidate)
        );
        assertEq(deployed[1], extended[0].deployedAddress);
        assertEq(MockCloneable(deployed[1]).sInitData(), extended[0].data);
        assertEq(candidate.networks[1].deployedAddress.code.length, 0);
    }

    /// The release passed as its own candidate takes no network it does not record, so it is refused one before any
    /// fork rather than broadcast there.
    function testTheReleaseAsItsOwnCandidateIsRefusedAnUnrecordedNetworkBeforeForking() external {
        CloneNetworks memory recorded = exampleCloneNetworks();
        recorded.networks = new ChainDeploy[](1);
        recorded.networks[0] = exampleCloneNetworks().networks[0];
        DeploySuite memory release = perNetworkSuite(recorded);

        vm.expectRevert(abi.encodeWithSelector(LibRainDeployClone.CloneNetworkUndeclared.selector, 137));
        sDeploy.externalDeployAndBroadcast(vm, arbitrumAndPolygon(), 1, release, release);
        assertFalse(anyForkExists());
    }

    /// A Zoltu broadcast under a compiled artifact path formats one verify command per network and emits no
    /// `UnverifiableSource`.
    function testZoltuBroadcastUnderACompiledArtifactPrintsVerifyCommands() external {
        LibRainDeploy.etchZoltuFactory(vm);
        DeploySuite memory suite = zoltuSuite(LibRainDeploy.zoltuAddress(type(MockCloneable).creationCode));
        suite.storedBytecodeHash = keccak256(type(MockCloneable).runtimeCode);
        string[] memory networks = arbitrumAndPolygon();
        LocalForkVm forkVm = new LocalForkVm();
        vm.expectCall(address(forkVm), abi.encodeWithSignature("toString(address)", suite.storedDeployedAddress), 2);
        vm.recordLogs();
        sDeploy.externalDeployAndBroadcast(Vm(address(forkVm)), networks, 1, suite, suite);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            assertTrue(logs[i].topics.length == 0 || logs[i].topics[0] != UnverifiableSource.selector);
        }
    }

    function anyForkExists() internal returns (bool) {
        (bool forked,) = address(vm).call(abi.encodeWithSignature("selectFork(uint256)", uint256(0)));
        return forked;
    }

    function walletsHold(address account) internal view returns (bool) {
        address[] memory wallets = vm.getWallets();
        for (uint256 i = 0; i < wallets.length; i++) {
            if (wallets[i] == account) {
                return true;
            }
        }
        return false;
    }

    function arbitrumAndPolygon() internal pure returns (string[] memory) {
        string[] memory networks = new string[](2);
        networks[0] = LibRainDeploy.ARBITRUM_ONE;
        networks[1] = LibRainDeploy.POLYGON;
        return networks;
    }

    /// Key zero has no wallet, so `NoNetworks` proves the list is refused before the key, and a
    /// stale recorded address proves it is refused before the address check.
    function testNoNetworksRevertsBeforeTheKeyAndTheAddress() external {
        CloneTarget memory clone = localClone(exampleCloneFactory(), exampleCloneImplementation());
        address stale = address(uint160(LibRainDeployClone.cloneDeployedAddress(clone)) + 1);
        DeploySuite memory staleClone = cloneSuite(clone, stale, bytes32(0), exampleCloneDependencies());

        vm.expectRevert(abi.encodeWithSelector(LibRainDeploy.NoNetworks.selector));
        sDeploy.externalDeployAndBroadcast(vm, new string[](0), 0, staleClone, staleClone);

        CloneNetworks memory clones = exampleCloneNetworks();
        clones.networks[0].deployedAddress = address(1);
        vm.expectRevert(abi.encodeWithSelector(LibRainDeploy.NoNetworks.selector));
        sDeploy.externalDeployAndBroadcast(
            vm, new string[](0), 0, frozenExampleCloneNetworks(), perNetworkSuite(clones)
        );

        DeploySuite memory staleZoltu = zoltuSuite(address(1));
        vm.expectRevert(abi.encodeWithSelector(LibRainDeploy.NoNetworks.selector));
        sDeploy.externalDeployAndBroadcast(vm, new string[](0), 0, staleZoltu, staleZoltu);
    }

    /// The broadcast refuses a per-network suite on a network its frozen suite neither records nor declares, before
    /// any fork.
    function testDeployAndBroadcastRefusesAnUnfrozenNetworkBeforeForking() external {
        CloneNetworks memory clones = exampleCloneNetworks();
        DeploySuite memory onNetworks = perNetworkSuite(clones);
        CloneNetworks memory recorded = exampleCloneNetworks();
        recorded.networks = new ChainDeploy[](1);
        recorded.networks[0] = clones.networks[0];

        vm.expectRevert(
            abi.encodeWithSelector(
                ExtendedNetworkUnfrozen.selector,
                onNetworks.suite,
                LibRainDeploy.POLYGON,
                clones.networks[1].deployedAddress
            )
        );
        sDeploy.externalDeployAndBroadcast(vm, arbitrumAndPolygon(), 1, perNetworkSuite(recorded), onNetworks);
        assertFalse(anyForkExists());
    }

    function testZoltuStaleRecordedAddressRevertsBeforeForking() external {
        address derived = LibRainDeploy.zoltuAddress(type(MockCloneable).creationCode);
        address stale = address(uint160(derived) + 1);
        DeploySuite memory suite = zoltuSuite(stale);

        vm.expectRevert(abi.encodeWithSelector(LibRainDeploy.UnexpectedDeployedAddress.selector, stale, derived));
        sDeploy.externalDeployAndBroadcast(vm, arbitrumAndPolygon(), 1, suite, suite);
        assertFalse(anyForkExists());
    }

    function testCloneStaleRecordedAddressRevertsBeforeForking() external {
        CloneTarget memory clone = localClone(exampleCloneFactory(), exampleCloneImplementation());
        address derived = LibRainDeployClone.cloneDeployedAddress(clone);
        address stale = address(uint160(derived) + 1);
        DeploySuite memory suite = cloneSuite(clone, stale, bytes32(0), exampleCloneDependencies());

        vm.expectRevert(abi.encodeWithSelector(LibRainDeploy.UnexpectedDeployedAddress.selector, stale, derived));
        sDeploy.externalDeployAndBroadcast(vm, arbitrumAndPolygon(), 1, suite, suite);
        assertFalse(anyForkExists());
    }

    /// The SECOND network is staled, so a check of only the first passes it.
    function testPerNetworkStaleRecordedAddressRevertsBeforeForking() external {
        CloneNetworks memory clones = exampleCloneNetworks();
        address derived = clones.networks[1].deployedAddress;
        address stale = address(uint160(derived) + 1);
        clones.networks[1].deployedAddress = stale;
        DeploySuite memory suite = perNetworkSuite(clones);

        vm.expectRevert(abi.encodeWithSelector(LibRainDeploy.UnexpectedDeployedAddress.selector, stale, derived));
        sDeploy.externalDeployAndBroadcast(vm, arbitrumAndPolygon(), 1, suite, suite);
        assertFalse(anyForkExists());
    }

    function testPerNetworkUndeclaredNetworkRevertsBeforeForking() external {
        string[] memory networks = new string[](3);
        networks[0] = LibRainDeploy.ARBITRUM_ONE;
        networks[1] = LibRainDeploy.POLYGON;
        networks[2] = LibRainDeploy.BASE;

        vm.expectRevert(abi.encodeWithSelector(LibRainDeployClone.CloneNetworkUndeclared.selector, 8453));
        sDeploy.externalDeployAndBroadcast(
            vm, networks, 1, frozenExampleCloneNetworks(), perNetworkSuite(exampleCloneNetworks())
        );
        assertFalse(anyForkExists());
    }

    function testPerNetworkDuplicateChainIdRevertsBeforeForking() external {
        CloneNetworks memory clones = exampleCloneNetworks();
        clones.networks[1].chainId = 42161;
        string[] memory networks = new string[](1);
        networks[0] = LibRainDeploy.ARBITRUM_ONE;

        vm.expectRevert(abi.encodeWithSelector(LibRainDeployClone.DuplicateCloneNetwork.selector, 42161));
        sDeploy.externalDeployAndBroadcast(vm, networks, 1, frozenExampleCloneNetworks(), perNetworkSuite(clones));
        assertFalse(anyForkExists());
    }

    /// The Zoltu id followed by any payload is refused by the broadcast before any fork.
    /// @param payload The trailing payload.
    function testZoltuSuiteCarryingAPayloadIsRefusedBeforeForking(bytes memory payload) external {
        vm.assume(payload.length > 0);
        DeploySuite memory suite = zoltuSuite(LibRainDeploy.zoltuAddress(type(MockCloneable).creationCode));
        suite.mechanismData = bytes.concat(abi.encode(ZOLTU_MECHANISM_ID), payload);

        vm.expectRevert(abi.encodeWithSelector(UnexpectedMechanismData.selector, suite.suite));
        sDeploy.externalDeployAndBroadcast(vm, arbitrumAndPolygon(), 1, suite, suite);
        assertFalse(anyForkExists());
    }

    /// A per-network suite that also carries a `storedDeployedAddress` is refused by the broadcast before any fork.
    function testPerNetworkSuiteCarryingAStoredAddressIsRefusedBeforeForking() external {
        DeploySuite memory suite = perNetworkSuite(exampleCloneNetworks());
        suite.storedDeployedAddress = address(1);

        vm.expectRevert(abi.encodeWithSelector(UnexpectedStoredDeployedAddress.selector, suite.suite, address(1)));
        sDeploy.externalDeployAndBroadcast(vm, arbitrumAndPolygon(), 1, suite, suite);
        assertFalse(anyForkExists());
    }

    function testCloneUndeclaredFactoryReverts() external {
        CloneTarget memory clone = localClone(exampleCloneFactory(), exampleCloneImplementation());
        DeployDependency[] memory dependencies = new DeployDependency[](1);
        dependencies[0] = exampleCloneDependencies()[1];
        DeploySuite memory suite =
            cloneSuite(clone, LibRainDeployClone.cloneDeployedAddress(clone), bytes32(0), dependencies);

        vm.expectRevert(abi.encodeWithSelector(LibRainDeployClone.CloneDependencyUndeclared.selector, clone.factory));
        sDeploy.externalDeployAndBroadcast(vm, arbitrumAndPolygon(), 1, suite, suite);
    }

    function testCloneUndeclaredImplementationReverts() external {
        CloneTarget memory clone = localClone(exampleCloneFactory(), exampleCloneImplementation());
        DeployDependency[] memory dependencies = new DeployDependency[](1);
        dependencies[0] = exampleCloneDependencies()[0];
        DeploySuite memory suite =
            cloneSuite(clone, LibRainDeployClone.cloneDeployedAddress(clone), bytes32(0), dependencies);

        vm.expectRevert(
            abi.encodeWithSelector(LibRainDeployClone.CloneDependencyUndeclared.selector, clone.implementation)
        );
        sDeploy.externalDeployAndBroadcast(vm, arbitrumAndPolygon(), 1, suite, suite);
    }

    function testCloneUndeclaredDependencyRefusedBeforeTheAddress() external {
        CloneTarget memory clone = localClone(exampleCloneFactory(), exampleCloneImplementation());
        address stale = address(uint160(LibRainDeployClone.cloneDeployedAddress(clone)) + 1);
        DeploySuite memory suite = cloneSuite(clone, stale, bytes32(0), new DeployDependency[](0));

        vm.expectRevert(abi.encodeWithSelector(LibRainDeployClone.CloneDependencyUndeclared.selector, clone.factory));
        sDeploy.externalDeployAndBroadcast(vm, arbitrumAndPolygon(), 1, suite, suite);
    }

    function testCloneChangedFactoryReverts() external {
        vm.makePersistent(address(this));
        vm.createSelectFork(LibRainDeploy.ARBITRUM_ONE);

        address factory = zoltuDeployOrAdopt(type(MockCloneFactory).creationCode, type(MockCloneFactory).runtimeCode);
        vm.makePersistent(factory);
        address implementation = zoltuDeployOrAdopt(type(MockCloneable).creationCode, type(MockCloneable).runtimeCode);
        vm.makePersistent(implementation);

        CloneTarget memory clone = localClone(factory, implementation);
        DeployDependency[] memory dependencies = exampleCloneDependencies();
        dependencies[0].runtimeCode = type(MockCloneable).runtimeCode;
        DeploySuite memory suite = cloneSuite(
            clone,
            LibRainDeployClone.cloneDeployedAddress(clone),
            LibRainDeployClone.cloneDeployedCodehash(implementation),
            dependencies
        );

        string[] memory networks = new string[](1);
        networks[0] = LibRainDeploy.ARBITRUM_ONE;

        vm.expectRevert(
            abi.encodeWithSelector(
                LibRainDeploy.DependencyChanged.selector,
                LibRainDeploy.ARBITRUM_ONE,
                factory,
                keccak256(type(MockCloneable).runtimeCode),
                factory.codehash
            )
        );
        sDeploy.externalDeployAndBroadcast(vm, networks, 1, suite, suite);
    }

    function testCloneDeploysThenSkipsOnRerun() external {
        vm.makePersistent(address(this));
        vm.createSelectFork(LibRainDeploy.ARBITRUM_ONE);

        address factory = zoltuDeployOrAdopt(type(MockCloneFactory).creationCode, type(MockCloneFactory).runtimeCode);
        assertEq(factory, exampleCloneFactory());
        vm.makePersistent(factory);
        address implementation = zoltuDeployOrAdopt(type(MockCloneable).creationCode, type(MockCloneable).runtimeCode);
        assertEq(implementation, exampleCloneImplementation());
        vm.makePersistent(implementation);

        CloneTarget memory clone = localClone(factory, implementation);
        address expected = LibRainDeployClone.cloneDeployedAddress(clone);
        bytes32 expectedCodeHash = LibRainDeployClone.cloneDeployedCodehash(implementation);
        DeploySuite memory suite = cloneSuite(clone, expected, expectedCodeHash, exampleCloneDependencies());

        string[] memory networks = new string[](1);
        networks[0] = LibRainDeploy.ARBITRUM_ONE;

        assertEq(expected.code.length, 0);

        (address[] memory deployed,) = sDeploy.externalDeployAndBroadcast(vm, networks, 1, suite, suite);
        assertEq(deployed[0], expected);
        assertEq(deployed[0].codehash, expectedCodeHash);
        assertEq(deployed[0].code, LibRainDeployClone.cloneRuntimeCode(implementation));

        vm.makePersistent(deployed[0]);
        (address[] memory again,) = sDeploy.externalDeployAndBroadcast(vm, networks, 1, suite, suite);
        assertEq(again[0], expected);
        assertEq(again[0].codehash, expectedCodeHash);
    }

    function testCloneReachesEveryNetworkAsTheRememberedKey() external {
        vm.makePersistent(address(this));
        string[] memory networks = arbitrumAndPolygon();

        CloneTarget memory clone = localClone(exampleCloneFactory(), exampleCloneImplementation());
        address expected = LibRainDeployClone.cloneDeployedAddress(clone);
        bytes32 expectedCodeHash = LibRainDeployClone.cloneDeployedCodehash(exampleCloneImplementation());

        address deployer = vm.addr(1);
        assertFalse(walletsHold(deployer));

        for (uint256 i = 0; i < networks.length; i++) {
            vm.createSelectFork(networks[i]);
            address factory =
                zoltuDeployOrAdopt(type(MockCloneFactory).creationCode, type(MockCloneFactory).runtimeCode);
            assertEq(factory, exampleCloneFactory());
            address implementation =
                zoltuDeployOrAdopt(type(MockCloneable).creationCode, type(MockCloneable).runtimeCode);
            assertEq(implementation, exampleCloneImplementation());
            vm.makePersistent(factory);
            vm.makePersistent(implementation);
            assertEq(expected.code.length, 0, networks[i]);
        }

        DeploySuite memory suite = cloneSuite(clone, expected, expectedCodeHash, exampleCloneDependencies());
        (address[] memory deployed, uint256[] memory forkIds) =
            sDeploy.externalDeployAndBroadcast(vm, networks, 1, suite, suite);
        assertEq(deployed.length, networks.length);
        assertEq(forkIds.length, networks.length);
        assertTrue(walletsHold(deployer));

        for (uint256 i = 0; i < forkIds.length; i++) {
            assertEq(deployed[i], expected);
            vm.selectFork(forkIds[i]);
            assertEq(expected.codehash, expectedCodeHash, networks[i]);
        }
    }
}
