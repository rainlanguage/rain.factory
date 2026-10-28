// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Vm} from "forge-std-1.17.0/src/Vm.sol";
import {
    DeployDeclaration,
    DeploySuite,
    RainDeploySuitesBase
} from "rain-deploy-0.1.27/src/abstract/RainDeploySuitesBase.sol";
import {RainDeployVerifyChain} from "rain-deploy-0.1.27/src/abstract/RainDeployVerifyChain.sol";
import {LibRainDeploy} from "rain-deploy-0.1.27/src/lib/LibRainDeploy.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.27/src/lib/LibRainDeployDeclaration.sol";
import {LibRainDeployZoltuMechanism} from "rain-deploy-0.1.27/src/lib/LibRainDeployZoltuMechanism.sol";
import {CloneDeploy} from "../../../src/lib/LibRainDeployClone.sol";
import {ChainBeacon} from "../../../src/lib/LibRainDeployBeacon.sol";
import {ChainDeploy, LibRainDeployExtendedNetworks} from "../../../src/lib/LibRainDeployExtendedNetworks.sol";
import {
    ExtendedNetworkAddressMismatch,
    ExtendedNetworkUnfrozen,
    LibRainDeployCloneMechanism
} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {
    PER_NETWORK_CLONE_POLYGON_CHAIN_ID,
    PerNetworkCloneDeploys,
    etchPerNetworkCloneRelease,
    onlyFirstRecordedNetworkSuites,
    perNetworkClone,
    perNetworkCloneInitData,
    perNetworkCloneNetworks,
    perNetworkCloneReleaseAddress,
    perNetworkCloneReleaseAddressAt,
    perNetworkCloneReleaseAddresses,
    perNetworkCloneReleased
} from "../../abstract/PerNetworkCloneDeploys.sol";
import {LibCloneCandidates} from "../../lib/LibCloneCandidates.sol";
import {LocalForkVm} from "../../concrete/LocalForkVm.sol";
import {LibExtendedNetworksFixture} from "../../lib/LibExtendedNetworksFixture.sol";

/// @dev Polygon's admin after the candidate moved it.
address constant MOVED_POLYGON_ADMIN = address(0xC4c4c4C4C4c4C4c4c4C4c4c4c4c4c4C4c4c4c4C4);

/// The per-network init data with Polygon's admin moved.
/// @param chainId The network's chain id.
/// @return The init data on that network.
function movedInitData(uint256 chainId) pure returns (bytes memory) {
    if (chainId == PER_NETWORK_CLONE_POLYGON_CHAIN_ID) {
        return abi.encode(MOVED_POLYGON_ADMIN);
    }
    return perNetworkCloneInitData(chainId);
}

/// The address the release derives on Polygon at the moved init data.
/// @return The address.
function movedReleaseAddress() pure returns (address) {
    return perNetworkCloneReleaseAddressAt(movedInitData(PER_NETWORK_CLONE_POLYGON_CHAIN_ID));
}

/// @title RainDeployVerifyChainClonePerNetworkExtendedTest
/// @notice The chain matrix, on local forks, over a per-network release recording Arbitrum One alone that was
/// broadcast to Polygon after its cut, in a repo whose candidate has since moved Polygon's init data.
contract RainDeployVerifyChainClonePerNetworkExtendedTest is PerNetworkCloneDeploys, RainDeployVerifyChain {
    /// Whether `extendedNetworks` declares Polygon.
    bool internal sFrozen;

    /// The address `extendedNetworks` declares for Polygon.
    address internal sFrozenAddress;

    /// The fork cheatcodes the matrix runs against.
    LocalForkVm internal sForkVm;

    /// The record root the extended networks record is read from: one nothing writes to until `record` names
    /// another.
    string internal sExtendedRoot = "fixture-lib/extended-networks/verify-extended-none";

    /// The per-network clone layers reading extended networks under `sExtendedRoot`, the committed release and the
    /// candidate with Polygon's init data moved.
    function declaration()
        internal
        view
        override(PerNetworkCloneDeploys, RainDeploySuitesBase)
        returns (DeployDeclaration memory)
    {
        DeployDeclaration memory d;
        LibRainDeployDeclaration.extend(d);
        LibRainDeployDeclaration.setNetworks(d, perNetworkCloneNetworks());
        LibRainDeployZoltuMechanism.extend(d);
        LibRainDeployCloneMechanism.extend(d);
        LibRainDeployCloneMechanism.setExtendedNetworksRoot(d, sExtendedRoot);
        LibRainDeployDeclaration.addReleased(d, perNetworkCloneReleased());
        CloneDeploy[] memory clones = new CloneDeploy[](1);
        clones[0] = perNetworkClone("per-network-clone", bytes32(uint256(4)));
        clones[0].initData = movedInitData;
        LibCloneCandidates.addClones(d, clones);
        return d;
    }

    /// Polygon at its original init data, as it was broadcast, once `sFrozen` is set.
    /// @param suite The release's suite key.
    /// @return The networks.
    function extendedNetworks(string memory suite) internal view returns (ChainDeploy[] memory) {
        if (!sFrozen || keccak256(bytes(suite)) != keccak256("per-network-clone@0_0_1")) {
            return new ChainDeploy[](0);
        }
        ChainDeploy[] memory networks = new ChainDeploy[](1);
        networks[0] = ChainDeploy({
            chainId: PER_NETWORK_CLONE_POLYGON_CHAIN_ID,
            data: perNetworkCloneInitData(PER_NETWORK_CLONE_POLYGON_CHAIN_ID),
            deployedAddress: sFrozenAddress
        });
        return networks;
    }

    /// Records what `extendedNetworks` now declares, as the build would, under a fixture root of its own after
    /// removing whatever an earlier run left there.
    /// @param label The fixture root's directory under `fixture-lib/extended-networks`, one per test.
    function record(string memory label) internal {
        sExtendedRoot =
            LibExtendedNetworksFixture.freshRoot(vm, "fixture-lib/extended-networks", label, "per-network-clone@0_0_1");
        LibRainDeployExtendedNetworks.writeExtendedNetworks(
            vm, sExtendedRoot, "per-network-clone@0_0_1", extendedNetworks("per-network-clone@0_0_1")
        );
    }

    /// Puts the release's dependencies, and its clone at its original address on each network, on every fork.
    function setUp() external {
        etchPerNetworkCloneRelease(vm, declaration().released[0], perNetworkCloneReleaseAddresses());
        sFrozenAddress = perNetworkCloneReleaseAddress(PER_NETWORK_CLONE_POLYGON_CHAIN_ID);
        sForkVm = new LocalForkVm();
    }

    /// The matrix on local forks, over the release recording Arbitrum One alone.
    function externalCheckOnLocalForks() external {
        DeployDeclaration memory d = declaration();
        DeploySuite[] memory suites = onlyFirstRecordedNetworkSuites(d.released[0]);
        checkDeployedOnNetworks(d, Vm(address(sForkVm)), LibRainDeploy.declaredNetworkConfigs(d.networks), suites);
    }

    /// Unfrozen, Polygon takes the candidate's moved init data and is refused as unfrozen, naming the address, whether
    /// or not a clone is live there: nothing is at the moved address while the release is live at its broadcast one.
    function testUnfrozenNetworkLiveAtTheCandidatesDataIsRefused() external {
        address moved = movedReleaseAddress();
        assertNotEq(moved, sFrozenAddress);
        assertEq(moved.code.length, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                ExtendedNetworkUnfrozen.selector, "per-network-clone@0_0_1", LibRainDeploy.POLYGON, moved
            )
        );
        this.externalCheckOnLocalForks();

        vm.etch(moved, declaration().released[0].storedRuntimeCode);
        vm.expectRevert(
            abi.encodeWithSelector(
                ExtendedNetworkUnfrozen.selector, "per-network-clone@0_0_1", LibRainDeploy.POLYGON, moved
            )
        );
        this.externalCheckOnLocalForks();
    }

    /// The matrix on local forks over Polygon alone, over the release recording Arbitrum One alone.
    function externalCheckPolygonOnLocalForks() external {
        DeployDeclaration memory d = declaration();
        DeploySuite[] memory suites = onlyFirstRecordedNetworkSuites(d.released[0]);
        string[] memory networks = new string[](1);
        networks[0] = LibRainDeploy.POLYGON;
        checkDeployedOnNetworks(d, Vm(address(sForkVm)), LibRainDeploy.declaredNetworkConfigs(networks), suites);
    }

    /// Unfrozen, Polygon is refused as unfrozen even when a dependency is missing there: what the network lacks is a
    /// declaration, and the dependency check would describe a release the matrix cannot place on it.
    function testUnfrozenNetworkMissingADependencyIsRefusedAsUnfrozen() external {
        DeploySuite memory release = declaration().released[0];
        assertGt(release.dependencies.length, 0);
        vm.etch(release.dependencies[0].deployedAddress, hex"");
        vm.expectRevert(
            abi.encodeWithSelector(
                ExtendedNetworkUnfrozen.selector,
                "per-network-clone@0_0_1",
                LibRainDeploy.POLYGON,
                movedReleaseAddress()
            )
        );
        this.externalCheckPolygonOnLocalForks();
    }

    /// Frozen, Polygon is checked at the address it was broadcast to, whatever the candidate's init data now is.
    function testFrozenNetworkIsCheckedAtItsFrozenAddress() external {
        sFrozen = true;
        record("verify-extended-frozen");
        this.externalCheckOnLocalForks();

        vm.etch(sFrozenAddress, hex"");
        vm.etch(movedReleaseAddress(), declaration().released[0].storedRuntimeCode);
        vm.expectRevert(
            abi.encodeWithSelector(LibRainDeploy.NotDeployedOnNetwork.selector, LibRainDeploy.POLYGON, sFrozenAddress)
        );
        this.externalCheckOnLocalForks();
    }

    /// A declared network the release's extended networks record does not hold is, to the matrix, unfrozen: the
    /// check reads the record alone, so Polygon takes the candidate's moved init data and is refused before any
    /// fork.
    function testDeclaredNetworkWithoutARecordIsRefused() external {
        sFrozen = true;
        vm.expectCall(address(sForkVm), abi.encodeWithSelector(LocalForkVm.createFork.selector), 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                ExtendedNetworkUnfrozen.selector,
                "per-network-clone@0_0_1",
                LibRainDeploy.POLYGON,
                movedReleaseAddress()
            )
        );
        this.externalCheckOnLocalForks();
    }

    /// A frozen network whose address its init data does not derive is refused before any fork.
    function testFrozenNetworkAtAnotherAddressIsRefused() external {
        sFrozen = true;
        address derived = sFrozenAddress;
        sFrozenAddress = movedReleaseAddress();
        record("verify-extended-misdeclared");
        vm.expectCall(address(sForkVm), abi.encodeWithSelector(LocalForkVm.createFork.selector), 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                ExtendedNetworkAddressMismatch.selector,
                "per-network-clone@0_0_1",
                PER_NETWORK_CLONE_POLYGON_CHAIN_ID,
                derived,
                sFrozenAddress
            )
        );
        this.externalCheckOnLocalForks();
    }
}
