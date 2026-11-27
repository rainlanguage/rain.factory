// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Vm} from "forge-std-1.17.0/src/Vm.sol";
import {DeployDeclaration, DeploySuite} from "rain-deploy-0.1.43/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeploy} from "rain-deploy-0.1.43/src/lib/LibRainDeploy.sol";
import {DeploySuiteIndex} from "rain-deploy-0.1.43/src/lib/LibRainDeployDeclaration.sol";
import {
    LibRainDeployZoltuMechanism,
    ZOLTU_MECHANISM_ID
} from "rain-deploy-0.1.43/src/lib/LibRainDeployZoltuMechanism.sol";
import {ChainBeacon} from "../../../src/lib/LibRainDeployBeacon.sol";
import {LibRainDeployBeaconResolution, ResolvedBeacon} from "../../../src/lib/LibRainDeployBeaconResolution.sol";
import {LibBeaconDeclarations} from "../../lib/LibBeaconDeclarations.sol";
import {LibSuiteIndexPointers} from "../../lib/LibSuiteIndexPointers.sol";
import {BeaconVerifyFixture} from "../../abstract/BeaconVerifyFixture.sol";

/// The index one local deploy was handed, as it found and left it.
struct IndexSighting {
    bool onChain;
    uint256 index;
    bool builtBefore;
    bool builtAfter;
    uint256 suites;
    uint256 recorded;
}

/// Every local deploy's sighting, in order.
struct IndexSightings {
    uint256 count;
    IndexSighting[] list;
}

/// @title LibRainDeployBeaconResolutionSharedIndexTest
/// @notice Every derivation and seat probe across a resolution's beacons and networks shares one index, built once.
contract LibRainDeployBeaconResolutionSharedIndexTest is BeaconVerifyFixture {
    using LibBeaconDeclarations for ChainBeacon[];
    using LibSuiteIndexPointers for DeploySuiteIndex;
    using LibSuiteIndexPointers for DeploySuite[];
    using LibSuiteIndexPointers for address[][];

    /// The memory address of the `IndexSightings`, which the derivations' state reverts leave in place.
    uint256 internal sSightings;

    /// The fixture's declaration, its Zoltu local deploys sighting the index they are handed.
    function declaration() internal view override returns (DeployDeclaration memory) {
        DeployDeclaration memory d = super.declaration();
        for (uint256 i = 0; i < d.mechanisms.length; i++) {
            if (d.mechanisms[i].id == ZOLTU_MECHANISM_ID) {
                d.mechanisms[i].deployLocally = sightedDeployLocally;
                d.mechanisms[i].deployLocallyOnChain = sightedDeployLocallyOnChain;
            }
        }
        return d;
    }

    function sightings() internal view returns (IndexSightings memory) {
        uint256 at = sSightings;
        IndexSightings memory s;
        assembly ("memory-safe") {
            s := at
        }
        return s;
    }

    function sight(bool onChain, DeploySuiteIndex memory index, bool builtBefore) internal view {
        IndexSightings memory s = sightings();
        s.list[s.count++] = IndexSighting({
            onChain: onChain,
            index: index.pointer(),
            builtBefore: builtBefore,
            builtAfter: index.built,
            suites: index.suites.pointer(),
            recorded: index.recorded.pointer()
        });
    }

    function sightedDeployLocally(
        DeployDeclaration memory d,
        DeploySuiteIndex memory index,
        Vm localVm,
        DeploySuite memory suite
    ) internal returns (address[] memory) {
        bool builtBefore = index.built;
        address[] memory deployed = LibRainDeployZoltuMechanism.deployLocally(d, index, localVm, suite);
        sight(false, index, builtBefore);
        return deployed;
    }

    function sightedDeployLocallyOnChain(
        DeployDeclaration memory d,
        DeploySuiteIndex memory index,
        Vm localVm,
        DeploySuite memory suite
    ) internal {
        bool builtBefore = index.built;
        LibRainDeployZoltuMechanism.deployLocallyOnChain(d, index, localVm, suite);
        sight(true, index, builtBefore);
    }

    function testResolvingBeaconsAcrossNetworksBuildsOneSharedIndexOnce() external {
        sBeacons.declare(42161, bySuite("beacon@0_0_1", OWNER));
        sBeacons.declare(42161, declared("beacon-implementation@0_0_1", OWNER));
        sBeacons.declare(8453, bySuite("beacon@0_0_1", OWNER));
        sBeacons.declare(8453, declared("beacon-implementation@0_0_1", OWNER));
        IndexSightings memory s = IndexSightings({count: 0, list: new IndexSighting[](16)});
        uint256 at;
        assembly ("memory-safe") {
            at := s
        }
        sSightings = at;

        ResolvedBeacon[] memory resolved = LibRainDeployBeaconResolution.resolveBeacons(
            declaration(), networksNamed(LibRainDeploy.ARBITRUM_ONE, LibRainDeploy.BASE)
        );

        assertEq(resolved.length, 4);
        // Suite-named beacons: suite, implementation, seat probe; address-named: implementation.
        assertEq(s.count, 8);
        IndexSighting memory build = s.list[0];
        assertFalse(build.builtBefore);
        assertTrue(build.builtAfter);
        uint256 probes = 0;
        for (uint256 i = 1; i < s.count; i++) {
            IndexSighting memory later = s.list[i];
            assertEq(later.index, build.index);
            assertTrue(later.builtBefore);
            assertEq(later.suites, build.suites);
            assertEq(later.recorded, build.recorded);
            if (later.onChain) {
                probes++;
            }
        }
        assertEq(probes, 2);
    }
}
