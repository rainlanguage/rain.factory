// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {
    DeployDeclaration,
    DeploySuite,
    UnrecordedOnNetwork
} from "rain-deploy-0.1.41/src/abstract/RainDeploySuitesBase.sol";
import {
    BEACON_PROXY_PER_NETWORK_MECHANISM,
    LibRainDeployCloneMechanism
} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {ExampleCloneDeploy} from "../../concrete/ExampleCloneDeploy.sol";
import {exampleCloneReleased} from "../../abstract/ExampleCloneDeploys.sol";
import {
    PER_NETWORK_CLONE_ARBITRUM_ONE_CHAIN_ID,
    PER_NETWORK_CLONE_POLYGON_CHAIN_ID,
    onlyFirstRecordedNetwork,
    perNetworkCloneNetworks,
    perNetworkCloneReleaseAddress,
    perNetworkCloneReleased
} from "../../abstract/PerNetworkCloneDeploys.sol";

/// @title LibRainDeployCloneMechanismRecordedAddressTest
/// @notice A per-network suite records an address only on the chains its payload has an entry for; any other clone
/// or beacon proxy suite records its stored address on every chain.
contract LibRainDeployCloneMechanismRecordedAddressTest is Test {
    function noDeclaration() internal pure returns (DeployDeclaration memory) {
        DeployDeclaration memory d;
        return d;
    }

    /// The per-network clone release recording Arbitrum One alone, on Arbitrum One and Polygon.
    function arbitrumOnlyRelease() internal pure returns (DeploySuite memory) {
        DeploySuite memory suite = onlyFirstRecordedNetwork(perNetworkCloneReleased()[0]);
        suite.networks = perNetworkCloneNetworks();
        return suite;
    }

    /// `suite` as a per-network beacon proxy over the same payload.
    function asPerNetworkBeaconProxy(DeploySuite memory suite) internal pure returns (DeploySuite memory) {
        suite.mechanismData = abi.encode(BEACON_PROXY_PER_NETWORK_MECHANISM, LibRainDeployCloneMechanism.payload(suite));
        return suite;
    }

    function testPerNetworkSuiteRecordsItsEntryAddress() external pure {
        DeploySuite[2] memory suites = [arbitrumOnlyRelease(), asPerNetworkBeaconProxy(arbitrumOnlyRelease())];
        for (uint256 i = 0; i < suites.length; i++) {
            (bool recorded, address recordedAt) = LibRainDeployCloneMechanism.recordedAddress(
                noDeclaration(), suites[i], PER_NETWORK_CLONE_ARBITRUM_ONE_CHAIN_ID
            );
            assertTrue(recorded);
            assertEq(recordedAt, perNetworkCloneReleaseAddress(PER_NETWORK_CLONE_ARBITRUM_ONE_CHAIN_ID));
        }
    }

    /// A chain with no entry is answered unrecorded at zero rather than refused.
    function testPerNetworkSuiteRecordsNothingOnAChainWithNoEntry(uint256 chainId) external pure {
        vm.assume(chainId != PER_NETWORK_CLONE_ARBITRUM_ONE_CHAIN_ID);
        DeploySuite[2] memory suites = [arbitrumOnlyRelease(), asPerNetworkBeaconProxy(arbitrumOnlyRelease())];
        for (uint256 i = 0; i < suites.length; i++) {
            (bool recorded, address recordedAt) =
                LibRainDeployCloneMechanism.recordedAddress(noDeclaration(), suites[i], chainId);
            assertFalse(recorded);
            assertEq(recordedAt, address(0));
        }
    }

    function testOneAddressSuiteRecordsItsStoredAddressOnEveryChain(uint256 chainId) external pure {
        DeploySuite memory suite = exampleCloneReleased()[0];
        assertNotEq(suite.storedDeployedAddress, address(0));
        (bool recorded, address recordedAt) =
            LibRainDeployCloneMechanism.recordedAddress(noDeclaration(), suite, chainId);
        assertTrue(recorded);
        assertEq(recordedAt, suite.storedDeployedAddress);
    }

    /// Through the declaration a listed network with no entry is reported unrecorded, and a reader needing its
    /// address is refused naming the suite and chain.
    function testDeclarationReportsAListedNetworkWithNoEntryAsUnrecorded() external {
        ExampleCloneDeploy deploy = new ExampleCloneDeploy();
        DeploySuite memory suite = arbitrumOnlyRelease();

        (bool[] memory recorded, address[] memory addresses) = deploy.externalRecordedAddresses(suite);
        assertEq(recorded.length, 2);
        assertTrue(recorded[0]);
        assertFalse(recorded[1]);
        assertEq(addresses[0], perNetworkCloneReleaseAddress(PER_NETWORK_CLONE_ARBITRUM_ONE_CHAIN_ID));
        assertEq(addresses[1], address(0));

        assertEq(
            deploy.externalRecordedAddress(suite, PER_NETWORK_CLONE_ARBITRUM_ONE_CHAIN_ID),
            perNetworkCloneReleaseAddress(PER_NETWORK_CLONE_ARBITRUM_ONE_CHAIN_ID)
        );
        vm.expectRevert(
            abi.encodeWithSelector(UnrecordedOnNetwork.selector, suite.suite, PER_NETWORK_CLONE_POLYGON_CHAIN_ID)
        );
        deploy.externalRecordedAddress(suite, PER_NETWORK_CLONE_POLYGON_CHAIN_ID);
    }
}
