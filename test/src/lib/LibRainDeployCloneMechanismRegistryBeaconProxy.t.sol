// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {Vm} from "forge-std-1.17.0/src/Vm.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/UpgradeableBeacon.sol";
import {DeployCandidate, DeploySuite} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {DeployDependency, LibRainDeploy} from "rain-deploy-0.1.29/src/lib/LibRainDeploy.sol";
import {LibRainDeployZoltuMechanism} from "rain-deploy-0.1.29/src/lib/LibRainDeployZoltuMechanism.sol";
import {ICloneableFactoryV7} from "../../../src/interface/ICloneableFactoryV7.sol";
import {CloneTarget, LibRainDeployClone} from "../../../src/lib/LibRainDeployClone.sol";
import {LibRainDeployBeaconProxy} from "../../../src/lib/LibRainDeployBeaconProxy.sol";
import {ChainDeploy} from "../../../src/lib/LibRainDeployExtendedNetworks.sol";
import {
    LibRainDeployRegistryBeaconProxy,
    REGISTRY_BEACON_PROXY_ARTIFACT_PATH,
    REGISTRY_BEACON_PROXY_UNANCHORABLE_REASON,
    RegistryBeaconProxyDeploy,
    RegistryBeaconProxyTarget
} from "../../../src/lib/LibRainDeployRegistryBeaconProxy.sol";
import {
    BEACON_PROXY_MECHANISM,
    BEACON_PROXY_PER_NETWORK_MECHANISM,
    CLONE_MECHANISM,
    CLONE_PER_NETWORK_MECHANISM,
    CloneCreationCodeMismatch,
    ExtendedNetworksUnexpected,
    LibRainDeployCloneMechanism,
    REGISTRY_BEACON_PROXY_MECHANISM
} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {ExampleCloneDeploy} from "../../concrete/ExampleCloneDeploy.sol";
import {LocalForkVm} from "../../concrete/LocalForkVm.sol";
import {MockCloneableV2} from "../../concrete/MockCloneableV2.sol";
import {perNetworkCloneChainIds, perNetworkCloneNetworks} from "../../abstract/PerNetworkCloneDeploys.sol";
import {LibRegistryBeaconProxyTest} from "../../lib/LibRegistryBeaconProxyTest.sol";

/// @title LibRainDeployCloneMechanismRegistryBeaconProxyTest
/// @notice The REGISTRY_BEACON_PROXY mechanism as `LibRainDeployCloneMechanism` reads it, through the example clone
/// declaration.
contract LibRainDeployCloneMechanismRegistryBeaconProxyTest is Test {
    bytes32 constant TEST_SALT = 0x1122334455667788990011223344556677889900112233445566778899001122;

    bytes constant TEST_DATA = hex"deadbeefcafe0102030405060708090a0b0c0d0e0f";

    string constant SUITE = "registry-beacon-proxy";

    ExampleCloneDeploy internal sDeploy;

    function setUp() external {
        sDeploy = new ExampleCloneDeploy();
    }

    function liveTarget() internal returns (RegistryBeaconProxyTarget memory) {
        return LibRegistryBeaconProxyTest.live(vm, address(new MockCloneableV2()), address(this), TEST_DATA, TEST_SALT);
    }

    function suiteOf(RegistryBeaconProxyTarget memory target) internal returns (DeploySuite memory) {
        RegistryBeaconProxyDeploy memory proxy =
            LibRegistryBeaconProxyTest.declared(SUITE, target, LibRegistryBeaconProxyTest.runtimeOf(vm, target));
        DeploySuite memory suite = LibRainDeployCloneMechanism.registryBeaconProxyCandidate(proxy).snapshot;
        suite.networks = perNetworkCloneNetworks();
        return suite;
    }

    function tagged(bytes memory mechanismData) internal pure returns (DeploySuite memory) {
        DeploySuite memory suite;
        suite.mechanismData = mechanismData;
        return suite;
    }

    function externalWithExtendedNetworks(DeploySuite memory suite, ChainDeploy[] memory extended)
        external
        pure
        returns (DeploySuite memory)
    {
        return LibRainDeployCloneMechanism.appendExtendedNetworks(suite, extended);
    }

    function testRegistryBeaconProxyCandidateDerivesEveryFieldFromTheDeclaration(RegistryBeaconProxyDeploy memory proxy)
        external
        pure
    {
        RegistryBeaconProxyTarget memory target = RegistryBeaconProxyTarget({
            factory: proxy.factory,
            registry: proxy.registry,
            authority: proxy.authority,
            beaconName: proxy.beaconName,
            beacon: proxy.beacon,
            data: proxy.data,
            salt: proxy.salt
        });
        DeployCandidate memory candidate = LibRainDeployCloneMechanism.registryBeaconProxyCandidate(proxy);
        DeploySuite memory snapshot = candidate.snapshot;

        assertEq(snapshot.suite, proxy.suite);
        assertEq(snapshot.creationCode, LibRainDeployRegistryBeaconProxy.registryBeaconProxyCreationCode(target));
        assertEq(
            snapshot.storedDeployedAddress, LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(target)
        );
        assertEq(snapshot.storedRuntimeCode, proxy.runtimeCode);
        assertEq(snapshot.storedBytecodeHash, keccak256(proxy.runtimeCode));
        assertEq(snapshot.artifactPath, REGISTRY_BEACON_PROXY_ARTIFACT_PATH);
        assertEq(abi.encode(snapshot.dependencies), abi.encode(proxy.dependencies));
        assertEq(snapshot.mechanismData, abi.encode(REGISTRY_BEACON_PROXY_MECHANISM, abi.encode(target)));
        assertEq(LibRainDeployCloneMechanism.mechanismTag(snapshot.mechanismData), REGISTRY_BEACON_PROXY_MECHANISM);
        assertEq(snapshot.networks.length, 0);
        assertEq(candidate.unanchorableReason, REGISTRY_BEACON_PROXY_UNANCHORABLE_REASON);
        assertNotEq(
            snapshot.storedDeployedAddress,
            LibRainDeployBeaconProxy.beaconProxyDeployedAddress(
                CloneTarget({factory: proxy.factory, implementation: proxy.beacon, data: proxy.data, salt: proxy.salt})
            )
        );
    }

    function testIsRegistryBeaconProxyOnlyForItsTag() external pure {
        DeploySuite memory registry = tagged(abi.encode(REGISTRY_BEACON_PROXY_MECHANISM, bytes("")));
        assertTrue(LibRainDeployCloneMechanism.isRegistryBeaconProxy(registry));
        assertFalse(LibRainDeployCloneMechanism.isPerNetwork(registry));
        assertFalse(LibRainDeployCloneMechanism.isBeaconProxy(registry));

        bytes32[4] memory others =
            [CLONE_MECHANISM, CLONE_PER_NETWORK_MECHANISM, BEACON_PROXY_MECHANISM, BEACON_PROXY_PER_NETWORK_MECHANISM];
        for (uint256 i = 0; i < others.length; i++) {
            assertFalse(LibRainDeployCloneMechanism.isRegistryBeaconProxy(tagged(abi.encode(others[i], bytes("")))));
        }
        assertFalse(
            LibRainDeployCloneMechanism.isRegistryBeaconProxy(tagged(LibRainDeployZoltuMechanism.mechanismData()))
        );
        assertFalse(LibRainDeployCloneMechanism.isRegistryBeaconProxy(tagged("")));
        assertFalse(
            LibRainDeployCloneMechanism.isRegistryBeaconProxy(
                //forge-lint: disable-next-line(unsafe-typecast)
                tagged(abi.encodePacked(bytes31(REGISTRY_BEACON_PROXY_MECHANISM)))
            )
        );
    }

    function testIsRegistryBeaconProxyIsFalseForAnyOtherTag(bytes32 tag, bytes memory data) external pure {
        vm.assume(tag != REGISTRY_BEACON_PROXY_MECHANISM);
        assertFalse(LibRainDeployCloneMechanism.isRegistryBeaconProxy(tagged(abi.encode(tag, data))));
    }

    function testRegistryBeaconProxySuiteResolvesToItsMechanism() external {
        assertEq(sDeploy.externalMechanismOf(suiteOf(liveTarget())), REGISTRY_BEACON_PROXY_MECHANISM);
    }

    function testRegistryBeaconProxyAddressAndStepDataAreTheSameOnEveryNetwork(uint256 chainId) external {
        RegistryBeaconProxyTarget memory target = liveTarget();
        DeploySuite memory suite = suiteOf(target);
        address expected = LibRainDeployRegistryBeaconProxy.registryBeaconProxyDeployedAddress(target);

        uint256[] memory chainIds = new uint256[](3);
        chainIds[0] = 42161;
        chainIds[1] = 137;
        chainIds[2] = chainId;
        for (uint256 i = 0; i < chainIds.length; i++) {
            assertEq(sDeploy.externalDeployedAddress(suite, chainIds[i]), expected);
            assertEq(sDeploy.externalRecordedAddress(suite, chainIds[i]), expected);
            assertEq(sDeploy.externalDeployStepData(suite, chainIds[i]), abi.encode(target));
        }

        address[] memory deployed = sDeploy.externalDeployedAddresses(suite);
        address[] memory recorded = sDeploy.externalRecordedAddresses(suite);
        assertEq(deployed.length, 2);
        assertEq(recorded.length, 2);
        for (uint256 i = 0; i < deployed.length; i++) {
            assertEq(deployed[i], expected);
            assertEq(recorded[i], expected);
        }
        assertEq(LibRainDeployCloneMechanism.addressChainIds(suite).length, 0);
    }

    function testRegistryBeaconProxyDeployedAddressIsDerivedFromItsFactoryCallNotItsStoredAddress(address stored)
        external
    {
        DeploySuite memory suite = suiteOf(liveTarget());
        address expected = suite.storedDeployedAddress;
        vm.assume(stored != expected);
        suite.storedDeployedAddress = stored;
        assertEq(sDeploy.externalDeployedAddress(suite, 42161), expected);
        assertEq(sDeploy.externalRecordedAddress(suite, 42161), stored);
    }

    function testRegistryBeaconProxySuiteDeploysLocallyToItsAddressOnEveryNetwork() external {
        DeploySuite memory suite = suiteOf(liveTarget());
        address[] memory deployed = sDeploy.externalDeployLocally(vm, suite);
        assertEq(deployed, sDeploy.externalDeployedAddresses(suite));
        assertEq(deployed.length, 2);
        for (uint256 i = 0; i < deployed.length; i++) {
            assertEq(deployed[i], suite.storedDeployedAddress);
        }
        assertEq(suite.storedDeployedAddress.code, suite.storedRuntimeCode);
    }

    function testRegistryBeaconProxyLocalDeployEtchesItsStoredRuntimeCodeWithoutCallingFactoryOrRegistry(bytes memory runtimeCode)
        external
    {
        vm.assume(runtimeCode.length > 0);
        vm.assume(runtimeCode[0] != 0xef);
        RegistryBeaconProxyTarget memory target = liveTarget();
        DeploySuite memory suite = suiteOf(target);
        suite.storedRuntimeCode = runtimeCode;
        suite.storedBytecodeHash = keccak256(runtimeCode);
        suite.dependencies[0].runtimeCode = hex"fe";
        suite.dependencies[1].runtimeCode = hex"fe";

        vm.expectCall(target.factory, bytes(""), 0);
        vm.expectCall(target.registry, bytes(""), 0);
        address[] memory deployed = sDeploy.externalDeployLocally(vm, suite);
        assertEq(deployed[0], suite.storedDeployedAddress);
        assertEq(suite.storedDeployedAddress.code, runtimeCode);
    }

    function testRegistryBeaconProxyLocalDeployOnChainEtchesItsStoredRuntimeCodeWithoutCallingFactoryOrRegistry()
        external
    {
        RegistryBeaconProxyTarget memory target = liveTarget();
        DeploySuite memory suite = suiteOf(target);
        suite.dependencies[0].runtimeCode = hex"fe";
        suite.dependencies[1].runtimeCode = hex"fe";

        vm.chainId(137);
        vm.expectCall(target.factory, bytes(""), 0);
        vm.expectCall(target.registry, bytes(""), 0);
        sDeploy.externalDeployLocallyOnChain(vm, suite);
        assertEq(suite.storedDeployedAddress.code, suite.storedRuntimeCode);
    }

    function expectCreationCodeRefused(DeploySuite memory suite, bytes memory creationCode) internal {
        suite.creationCode = creationCode;
        vm.expectRevert(abi.encodeWithSelector(CloneCreationCodeMismatch.selector, SUITE));
        sDeploy.externalDeployLocally(vm, suite);
        vm.expectRevert(abi.encodeWithSelector(CloneCreationCodeMismatch.selector, SUITE));
        sDeploy.externalDeployLocallyOnChain(vm, suite);
    }

    function testRegistryBeaconProxyCreationCodeOverAnotherBindingIsRefused(address otherAddress, bytes32 otherName)
        external
    {
        RegistryBeaconProxyTarget memory target = liveTarget();
        DeploySuite memory suite = suiteOf(target);
        vm.assume(otherAddress != target.registry && otherAddress != target.authority);
        vm.assume(otherName != target.beaconName);

        RegistryBeaconProxyTarget memory other = abi.decode(abi.encode(target), (RegistryBeaconProxyTarget));
        other.registry = otherAddress;
        expectCreationCodeRefused(suite, LibRainDeployRegistryBeaconProxy.registryBeaconProxyCreationCode(other));

        other = abi.decode(abi.encode(target), (RegistryBeaconProxyTarget));
        other.authority = otherAddress;
        expectCreationCodeRefused(suite, LibRainDeployRegistryBeaconProxy.registryBeaconProxyCreationCode(other));

        other = abi.decode(abi.encode(target), (RegistryBeaconProxyTarget));
        other.beaconName = otherName;
        expectCreationCodeRefused(suite, LibRainDeployRegistryBeaconProxy.registryBeaconProxyCreationCode(other));
    }

    function testRegistryBeaconProxyCreationCodeOfAnotherMechanismIsRefused() external {
        RegistryBeaconProxyTarget memory target = liveTarget();
        DeploySuite memory suite = suiteOf(target);
        expectCreationCodeRefused(suite, LibRainDeployBeaconProxy.beaconProxyCreationCode(target.beacon));
        expectCreationCodeRefused(suite, LibRainDeployClone.cloneCreationCode(target.beacon));
        expectCreationCodeRefused(suite, "");
    }

    function testRegistryBeaconProxyDeployStepIsTheRegistryBeaconProxyStep() external {
        RegistryBeaconProxyTarget memory target = liveTarget();
        DeploySuite memory suite = suiteOf(target);
        Vm stepVm = Vm(address(new LocalForkVm()));
        bytes memory data = sDeploy.externalDeployStepData(suite, 42161);

        vm.expectCall(
            target.factory,
            abi.encodeCall(
                ICloneableFactoryV7.registryBeaconProxy,
                (target.registry, target.authority, target.beaconName, target.data, target.salt)
            ),
            1
        );
        address deployed = sDeploy.externalRunDeployStep(stepVm, suite, LibRainDeploy.ARBITRUM_ONE, address(this), data);
        assertEq(deployed, suite.storedDeployedAddress);
        assertEq(deployed.codehash, suite.storedBytecodeHash);
    }

    function testRegistryBeaconProxyDeployStepRefusesABindingToAnotherBeacon() external {
        RegistryBeaconProxyTarget memory target = liveTarget();
        DeploySuite memory suite = suiteOf(target);
        address otherBeacon = address(new UpgradeableBeacon(address(new MockCloneableV2()), address(this)));
        vm.warp(block.timestamp + 1);
        LibRegistryBeaconProxyTest.bind(vm, target.registry, otherBeacon);
        Vm stepVm = Vm(address(new LocalForkVm()));
        bytes memory data = sDeploy.externalDeployStepData(suite, 42161);

        vm.expectRevert(
            abi.encodeWithSelector(
                LibRainDeployRegistryBeaconProxy.RegistryBeaconProxyBeaconMismatch.selector,
                LibRainDeploy.ARBITRUM_ONE,
                target.beacon,
                otherBeacon
            )
        );
        sDeploy.externalRunDeployStep(stepVm, suite, LibRainDeploy.ARBITRUM_ONE, address(this), data);
    }

    function testExtendedNetworksOnARegistryBeaconProxyAreRefused() external {
        DeploySuite memory suite = suiteOf(liveTarget());
        assertEq(this.externalWithExtendedNetworks(suite, new ChainDeploy[](0)).mechanismData, suite.mechanismData);

        ChainDeploy[] memory extended = new ChainDeploy[](1);
        extended[0] = ChainDeploy({chainId: 137, data: TEST_DATA, deployedAddress: suite.storedDeployedAddress});
        vm.expectRevert(abi.encodeWithSelector(ExtendedNetworksUnexpected.selector, SUITE));
        this.externalWithExtendedNetworks(suite, extended);
    }

    function testRegistryBeaconProxySuiteMissingADependencyIsRefused() external {
        RegistryBeaconProxyTarget memory target = liveTarget();
        DeploySuite memory declared = suiteOf(target);
        address[3] memory required = [target.factory, target.registry, target.beacon];

        for (uint256 missing = 0; missing < required.length; missing++) {
            DeploySuite memory suite = abi.decode(abi.encode(declared), (DeploySuite));
            DeployDependency[] memory kept = new DeployDependency[](2);
            uint256 k = 0;
            for (uint256 i = 0; i < declared.dependencies.length; i++) {
                if (declared.dependencies[i].deployedAddress != required[missing]) {
                    kept[k] = declared.dependencies[i];
                    k++;
                }
            }
            assertEq(k, 2);
            suite.dependencies = kept;

            bytes memory refusal =
                abi.encodeWithSelector(LibRainDeployClone.CloneDependencyUndeclared.selector, required[missing]);
            vm.expectRevert(refusal);
            sDeploy.externalDeployedAddress(suite, 42161);
            vm.expectRevert(refusal);
            sDeploy.externalDeployStepData(suite, 42161);
            vm.expectRevert(refusal);
            sDeploy.externalDeployLocally(vm, suite);
            vm.expectRevert(refusal);
            sDeploy.externalDeployLocallyOnChain(vm, suite);
        }
    }
}
