// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {DeployDependency, DeploySuite} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {DerivedDeploy, NoDerivedDeployment} from "rain-deploy-0.1.29/src/abstract/RainDeployVerifyBase.sol";
import {LibRainDeploy, SupportedNetwork} from "rain-deploy-0.1.29/src/lib/LibRainDeploy.sol";
import {ChainBeacon} from "../../../src/lib/LibRainDeployBeacon.sol";
import {LibRainDeployBeaconResolution} from "../../../src/lib/LibRainDeployBeaconResolution.sol";
import {CLONE_ARTIFACT_PATH, CloneNetworks, LibRainDeployClone} from "../../../src/lib/LibRainDeployClone.sol";
import {CLONE_PER_NETWORK_MECHANISM} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {ChainDeploy} from "../../../src/lib/LibRainDeployExtendedNetworks.sol";
import {MockCloneFactory} from "../../concrete/MockCloneFactory.sol";
import {MockChainGatedCloneable, MockChainGatedCloneableWrongChain} from "../../concrete/MockChainGatedCloneable.sol";
import {LibBeaconDeclarations} from "../../lib/LibBeaconDeclarations.sol";
import {BeaconVerifyFixture} from "../../abstract/BeaconVerifyFixture.sol";

/// @title LibRainDeployBeaconResolutionChainGatedPerNetworkCloneTest
/// @notice A per-network clone suite whose clones initialize only under their own network's chain id derives every
/// network and resolves as a beacon on each.
contract LibRainDeployBeaconResolutionChainGatedPerNetworkCloneTest is BeaconVerifyFixture {
    using LibBeaconDeclarations for ChainBeacon[];

    function chainGatedClones(bytes memory baseData) internal pure returns (CloneNetworks memory) {
        CloneNetworks memory clones = CloneNetworks({
            factory: LibRainDeploy.zoltuAddress(type(MockCloneFactory).creationCode),
            implementation: LibRainDeploy.zoltuAddress(type(MockChainGatedCloneable).creationCode),
            salt: bytes32(uint256(7)),
            networks: new ChainDeploy[](2)
        });
        clones.networks[0] =
            ChainDeploy({chainId: 42161, data: abi.encode(uint256(42161)), deployedAddress: address(0)});
        clones.networks[1] = ChainDeploy({chainId: 8453, data: baseData, deployedAddress: address(0)});
        return clones;
    }

    function chainGatedSuite() internal pure returns (DeploySuite memory) {
        return chainGatedSuite(chainGatedClones(abi.encode(uint256(8453))));
    }

    function chainGatedSuite(CloneNetworks memory clones) internal pure returns (DeploySuite memory) {
        DeployDependency[] memory dependencies = new DeployDependency[](2);
        dependencies[0] =
            DeployDependency({deployedAddress: clones.factory, runtimeCode: type(MockCloneFactory).runtimeCode});
        dependencies[1] = DeployDependency({
            deployedAddress: clones.implementation, runtimeCode: type(MockChainGatedCloneable).runtimeCode
        });
        string[] memory networks = new string[](2);
        networks[0] = LibRainDeploy.ARBITRUM_ONE;
        networks[1] = LibRainDeploy.BASE;
        bytes memory runtimeCode = LibRainDeployClone.cloneRuntimeCode(clones.implementation);
        return DeploySuite({
            suite: "chain-gated-clone-beacon@0_0_1",
            creationCode: LibRainDeployClone.cloneCreationCode(clones.implementation),
            storedDeployedAddress: address(0),
            storedBytecodeHash: keccak256(runtimeCode),
            storedRuntimeCode: runtimeCode,
            artifactPath: CLONE_ARTIFACT_PATH,
            dependencies: dependencies,
            mechanismData: abi.encode(CLONE_PER_NETWORK_MECHANISM, abi.encode(clones)),
            networks: networks
        });
    }

    function releasedSuites() internal pure override returns (DeploySuite[] memory) {
        DeploySuite[] memory fixture = super.releasedSuites();
        DeploySuite[] memory released = new DeploySuite[](fixture.length + 1);
        for (uint256 i = 0; i < fixture.length; i++) {
            released[i] = fixture[i];
        }
        released[fixture.length] = chainGatedSuite();
        return released;
    }

    function externalResolvedCount(SupportedNetwork[] memory networks) external returns (uint256) {
        return LibRainDeployBeaconResolution.resolveBeacons(declaration(), networks).length;
    }

    function externalDeriveDeployment(DeploySuite memory suite) external returns (DerivedDeploy memory) {
        return LibRainDeployBeaconResolution.deriveDeployment(declaration(), suite);
    }

    function testChainGatedPerNetworkCloneBeaconSuiteResolvesOnArbitrum() external {
        sBeacons.declare(42161, bySuite("chain-gated-clone-beacon@0_0_1", address(0)));
        assertEq(this.externalResolvedCount(arbitrum()), 1);
    }

    function testChainGatedPerNetworkCloneBeaconSuiteResolvesOnBase() external {
        sBeacons.declare(8453, bySuite("chain-gated-clone-beacon@0_0_1", address(0)));
        assertEq(this.externalResolvedCount(networksNamed(LibRainDeploy.BASE, "")), 1);
    }

    function testChainGatedPerNetworkCloneSuiteDerivesEveryNetwork() external {
        CloneNetworks memory clones = chainGatedClones(abi.encode(uint256(8453)));
        DeploySuite memory suite = chainGatedSuite(clones);
        address arbitrumClone =
            LibRainDeployClone.cloneDeployedAddress(LibRainDeployClone.cloneNetworkTarget(clones, 0));
        address baseClone = LibRainDeployClone.cloneDeployedAddress(LibRainDeployClone.cloneNetworkTarget(clones, 1));
        assertNotEq(arbitrumClone, baseClone);
        uint256 chainId = block.chainid;

        DerivedDeploy memory derived = this.externalDeriveDeployment(suite);

        assertEq(derived.suite, suite.suite);
        assertEq(derived.deployedAddresses.length, 2);
        assertEq(derived.deployedAddresses[0], arbitrumClone);
        assertEq(derived.deployedAddresses[1], baseClone);
        assertEq(derived.bytecodeHash, keccak256(suite.storedRuntimeCode));
        assertEq(block.chainid, chainId);
        assertEq(arbitrumClone.code.length, 0);
        assertEq(baseClone.code.length, 0);
    }

    function testPerNetworkCloneSuiteSharingAnAddressIsRefusedByTheSharingNetworksInit() external {
        CloneNetworks memory clones = chainGatedClones(abi.encode(uint256(42161)));
        assertEq(
            LibRainDeployClone.cloneDeployedAddress(LibRainDeployClone.cloneNetworkTarget(clones, 0)),
            LibRainDeployClone.cloneDeployedAddress(LibRainDeployClone.cloneNetworkTarget(clones, 1))
        );
        DeploySuite memory suite = chainGatedSuite(clones);
        vm.expectRevert(abi.encodeWithSelector(MockChainGatedCloneableWrongChain.selector, 42161, 8453));
        this.externalDeriveDeployment(suite);
    }

    function testPerNetworkCloneSuiteRefusedByALaterNetworksInitIsRefused() external {
        DeploySuite memory suite = chainGatedSuite(chainGatedClones(abi.encode(uint256(42161), uint256(8453))));
        vm.expectRevert(abi.encodeWithSelector(MockChainGatedCloneableWrongChain.selector, 42161, 8453));
        this.externalDeriveDeployment(suite);
    }

    function baseOnlyClones() internal pure returns (CloneNetworks memory) {
        CloneNetworks memory clones = chainGatedClones("");
        clones.networks = new ChainDeploy[](1);
        clones.networks[0] = ChainDeploy({chainId: 8453, data: abi.encode(uint256(8453)), deployedAddress: address(0)});
        return clones;
    }

    function testDerivationSkipsALeadingNetworkTheSuiteRecordsNoCloneOn() external {
        CloneNetworks memory clones = baseOnlyClones();
        DeploySuite memory suite = chainGatedSuite(clones);
        address baseClone = LibRainDeployClone.cloneDeployedAddress(LibRainDeployClone.cloneNetworkTarget(clones, 0));

        DerivedDeploy memory derived = this.externalDeriveDeployment(suite);

        assertEq(derived.deployedAddresses.length, 2);
        assertEq(derived.deployedAddresses[0], address(0));
        assertEq(derived.deployedAddresses[1], baseClone);
        assertEq(derived.bytecodeHash, keccak256(suite.storedRuntimeCode));
    }

    function testDerivationRecordingNoCloneOnAnyOfItsNetworksIsRefused() external {
        DeploySuite memory suite = chainGatedSuite(baseOnlyClones());
        suite.networks = new string[](1);
        suite.networks[0] = LibRainDeploy.ARBITRUM_ONE;
        vm.expectRevert(abi.encodeWithSelector(NoDerivedDeployment.selector, suite.suite));
        this.externalDeriveDeployment(suite);
    }
}
