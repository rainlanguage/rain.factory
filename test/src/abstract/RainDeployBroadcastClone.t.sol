// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {SuiteSeatsDeployKey} from "rain-deploy-0.1.29/src/abstract/RainDeployBroadcast.sol";
import {DeploySuite} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {DeployDependency, LibRainDeploy} from "rain-deploy-0.1.29/src/lib/LibRainDeploy.sol";
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
    LibRainDeployCloneMechanism
} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {MockChainGatedCloneable} from "../../concrete/MockChainGatedCloneable.sol";
import {
    OriginOwnedCloneDeploy,
    originOwnedCloneNetworks,
    originOwnedCloneSetup
} from "../../concrete/OriginOwnedCloneDeploy.sol";

/// @title RainDeployBroadcastCloneTest
/// @notice `broadcastSuite` and the seat check over clone and per-network clone suites, through a declaration whose
/// candidate's Base clone seats the deploy key.
contract RainDeployBroadcastCloneTest is Test {
    OriginOwnedCloneDeploy internal sDeploy;

    function setUp() external {
        sDeploy = new OriginOwnedCloneDeploy();
    }

    function onlyChainId(uint256 chainId) internal pure returns (uint256[] memory) {
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = chainId;
        return chainIds;
    }

    function arbitrumAndBaseIds() internal pure returns (uint256[] memory) {
        uint256[] memory chainIds = new uint256[](2);
        chainIds[0] = 42161;
        chainIds[1] = 8453;
        return chainIds;
    }

    /// A per-network release of the origin-owned clone on Arbitrum One and Base, seating `arbitrumOwner` and
    /// `baseOwner`, or the initialization's origin where either is zero.
    function originOwnedCloneSuite(address arbitrumOwner, address baseOwner)
        internal
        pure
        returns (DeploySuite memory)
    {
        (address factory, address implementation, DeployDependency[] memory dependencies) = originOwnedCloneSetup();
        CloneNetworks memory clones = CloneNetworks({
            factory: factory, implementation: implementation, salt: bytes32(uint256(7)), networks: new ChainDeploy[](2)
        });
        clones.networks[0] = ChainDeploy({chainId: 42161, data: abi.encode(arbitrumOwner), deployedAddress: address(0)});
        clones.networks[1] = ChainDeploy({chainId: 8453, data: abi.encode(baseOwner), deployedAddress: address(0)});
        for (uint256 i = 0; i < clones.networks.length; i++) {
            clones.networks[i].deployedAddress =
                LibRainDeployClone.cloneDeployedAddress(LibRainDeployClone.cloneNetworkTarget(clones, i));
        }
        bytes memory runtimeCode = LibRainDeployClone.cloneRuntimeCode(implementation);
        return DeploySuite({
            suite: "origin-owned-clone@0_0_1",
            creationCode: LibRainDeployClone.cloneCreationCode(implementation),
            storedDeployedAddress: address(0),
            storedBytecodeHash: keccak256(runtimeCode),
            storedRuntimeCode: runtimeCode,
            artifactPath: CLONE_ARTIFACT_PATH,
            dependencies: dependencies,
            mechanismData: abi.encode(CLONE_PER_NETWORK_MECHANISM, abi.encode(clones)),
            networks: originOwnedCloneNetworks()
        });
    }

    /// @param suite A per-network suite.
    /// @return The suite recording its Arbitrum One entry alone.
    function onlyArbitrum(DeploySuite memory suite) internal pure returns (DeploySuite memory) {
        CloneNetworks memory clones = abi.decode(LibRainDeployCloneMechanism.payload(suite), (CloneNetworks));
        ChainDeploy memory arbitrum = clones.networks[0];
        clones.networks = new ChainDeploy[](1);
        clones.networks[0] = arbitrum;
        return LibRainDeployCloneMechanism.withPayload(suite, abi.encode(clones));
    }

    function testBroadcastRefusesAPerNetworkSuiteWhoseSecondCloneSeatsTheDeployKey() external {
        DeploySuite memory suite = originOwnedCloneSuite(address(0xB0B), address(0));
        address seating = sDeploy.externalDeployedAddress(suite, 8453);
        vm.expectRevert(abi.encodeWithSelector(SuiteSeatsDeployKey.selector, suite.suite, seating));
        sDeploy.externalBroadcastSuite(suite, new string[](0), 1);
    }

    function testBroadcastRefusesAPerNetworkSuiteWhoseFirstCloneSeatsTheDeployKey() external {
        DeploySuite memory suite = originOwnedCloneSuite(address(0), address(0xB0B));
        address seating = sDeploy.externalDeployedAddress(suite, 42161);
        vm.expectRevert(abi.encodeWithSelector(SuiteSeatsDeployKey.selector, suite.suite, seating));
        sDeploy.externalBroadcastSuite(suite, new string[](0), 1);
    }

    function testBroadcastOfAPerNetworkSuiteSeatingOthersReachesTheNetworkRefusal() external {
        DeploySuite memory suite = originOwnedCloneSuite(address(0xB0B), address(0xCAFE));
        vm.expectRevert(abi.encodeWithSelector(LibRainDeploy.NoNetworks.selector));
        sDeploy.externalBroadcastSuite(suite, new string[](0), 1);
    }

    /// A release recording Arbitrum One alone takes Base from its candidate, whose Base clone seats the deploy key at
    /// the address the release's factory, implementation and salt derive for the candidate's data there.
    function testBroadcastRefusesAReleaseWhoseCandidateAddsANetworkSeatingTheDeployKey() external {
        DeploySuite memory release = onlyArbitrum(originOwnedCloneSuite(address(0xB0B), address(0xB0B)));
        CloneNetworks memory clones = abi.decode(LibRainDeployCloneMechanism.payload(release), (CloneNetworks));
        address seating = LibRainDeployClone.cloneDeployedAddress(
            CloneTarget({
                factory: clones.factory,
                implementation: clones.implementation,
                data: abi.encode(address(0)),
                salt: clones.salt
            })
        );
        vm.expectRevert(abi.encodeWithSelector(SuiteSeatsDeployKey.selector, release.suite, seating));
        sDeploy.externalBroadcastSuite(release, new string[](0), 1);
    }

    function testSeatCheckReadsAOneNetworkCloneSuiteOnlyUnderItsOwnNetwork() external {
        DeploySuite memory suite = onlyArbitrum(originOwnedCloneSuite(address(0xB0B), address(0xB0B)));
        sDeploy.externalCheckSeatsNoDeployKey(suite, onlyChainId(42161), vm.addr(1));
    }

    /// Each network's clone is initialized under that network's chain id alone: an implementation refusing any
    /// other chain id passes the check under both.
    function testSeatCheckInitializesEachPerNetworkCloneOnlyUnderItsOwnChainId() external {
        sDeploy.externalCheckSeatsNoDeployKey(chainGatedCloneSuite(), arbitrumAndBaseIds(), vm.addr(1));
    }

    /// The local derivation initializes each network's clone under that network's chain id, leaves both, and
    /// restores the caller's chain id.
    function testDeployLocallyInitializesEachPerNetworkCloneUnderItsOwnChainId() external {
        DeploySuite memory suite = chainGatedCloneSuite();
        vm.chainId(1);
        address[] memory deployed = sDeploy.externalDeployLocally(vm, suite);
        assertEq(block.chainid, 1);
        assertEq(deployed.length, 2);
        assertEq(deployed[0], sDeploy.externalDeployedAddress(suite, 42161));
        assertEq(deployed[1], sDeploy.externalDeployedAddress(suite, 8453));
        assertEq(deployed[0].code, suite.storedRuntimeCode);
        assertEq(deployed[1].code, suite.storedRuntimeCode);
    }

    /// The origin-owned per-network suite over `MockChainGatedCloneable`, each network's init data naming its own
    /// chain id.
    function chainGatedCloneSuite() internal pure returns (DeploySuite memory) {
        DeploySuite memory suite = originOwnedCloneSuite(address(0xB0B), address(0xB0B));
        CloneNetworks memory clones = abi.decode(LibRainDeployCloneMechanism.payload(suite), (CloneNetworks));
        address implementation = LibRainDeploy.zoltuAddress(type(MockChainGatedCloneable).creationCode);
        clones.implementation = implementation;
        clones.networks[0].data = abi.encode(uint256(42161));
        clones.networks[1].data = abi.encode(uint256(8453));
        for (uint256 i = 0; i < clones.networks.length; i++) {
            clones.networks[i].deployedAddress =
                LibRainDeployClone.cloneDeployedAddress(LibRainDeployClone.cloneNetworkTarget(clones, i));
        }
        suite = LibRainDeployCloneMechanism.withPayload(suite, abi.encode(clones));
        suite.creationCode = LibRainDeployClone.cloneCreationCode(implementation);
        suite.storedRuntimeCode = LibRainDeployClone.cloneRuntimeCode(implementation);
        suite.storedBytecodeHash = keccak256(suite.storedRuntimeCode);
        suite.dependencies[1] =
            DeployDependency({deployedAddress: implementation, runtimeCode: type(MockChainGatedCloneable).runtimeCode});
        return suite;
    }

    /// The origin-owned clone at one address on every network, seating `named`, or the initialization's origin
    /// when `named` is zero.
    function singleOriginOwnedCloneSuite(address named) internal pure returns (DeploySuite memory) {
        (address factory, address implementation, DeployDependency[] memory dependencies) = originOwnedCloneSetup();
        CloneTarget memory target = CloneTarget({
            factory: factory, implementation: implementation, data: abi.encode(named), salt: bytes32(uint256(7))
        });
        bytes memory runtimeCode = LibRainDeployClone.cloneRuntimeCode(implementation);
        return DeploySuite({
            suite: "origin-owned-single-clone@0_0_1",
            creationCode: LibRainDeployClone.cloneCreationCode(implementation),
            storedDeployedAddress: LibRainDeployClone.cloneDeployedAddress(target),
            storedBytecodeHash: keccak256(runtimeCode),
            storedRuntimeCode: runtimeCode,
            artifactPath: CLONE_ARTIFACT_PATH,
            dependencies: dependencies,
            mechanismData: abi.encode(CLONE_MECHANISM, abi.encode(target)),
            networks: originOwnedCloneNetworks()
        });
    }

    function testBroadcastRefusesASingleCloneSuiteThatSeatsTheDeployKey() external {
        DeploySuite memory suite = singleOriginOwnedCloneSuite(address(0));
        vm.expectRevert(abi.encodeWithSelector(SuiteSeatsDeployKey.selector, suite.suite, suite.storedDeployedAddress));
        sDeploy.externalBroadcastSuite(suite, new string[](0), 1);
    }

    function testBroadcastOfASingleCloneSuiteSeatingAnotherReachesTheNetworkRefusal() external {
        DeploySuite memory suite = singleOriginOwnedCloneSuite(address(0xB0B));
        vm.expectRevert(abi.encodeWithSelector(LibRainDeploy.NoNetworks.selector));
        sDeploy.externalBroadcastSuite(suite, new string[](0), 1);
    }

    function testSeatCheckOfASingleCloneSuiteLeavesNothingDeployed() external {
        DeploySuite memory suite = singleOriginOwnedCloneSuite(address(0xB0B));
        sDeploy.externalCheckSeatsNoDeployKey(suite, arbitrumAndBaseIds(), vm.addr(1));
        assertEq(suite.storedDeployedAddress.code.length, 0);
        assertEq(suite.dependencies[0].deployedAddress.code.length, 0);
        assertEq(suite.dependencies[1].deployedAddress.code.length, 0);
        assertEq(block.chainid, 31337);
    }
}
