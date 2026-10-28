// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {BuildScript} from "rain-deploy-0.1.27/src/abstract/BuildScript.sol";
import {DeployDeclaration, DeploySuite, SnapshotFile} from "rain-deploy-0.1.27/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeployConfig} from "rain-deploy-0.1.27/src/lib/LibRainDeployConfig.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.27/src/lib/LibRainDeployDeclaration.sol";
import {LibRainDeploySnapshot} from "rain-deploy-0.1.27/src/lib/LibRainDeploySnapshot.sol";
import {LibRainDeployZoltuMechanism} from "rain-deploy-0.1.27/src/lib/LibRainDeployZoltuMechanism.sol";
import {RAIN_COPYRIGHT_TEXT, RAIN_SPDX_LICENSE_IDENTIFIER} from "rain-sol-codegen-0.1.39/src/lib/LibCodeGen.sol";
import {ChainBeacon} from "../../src/lib/LibRainDeployBeacon.sol";
import {LibRainDeployCloneBuild} from "../../src/lib/LibRainDeployCloneBuild.sol";
import {
    CloneLayerConfig,
    ExtendedNetworksDeclaration,
    LibRainDeployCloneMechanism
} from "../../src/lib/LibRainDeployCloneMechanism.sol";
import {ChainDeploy} from "../../src/lib/LibRainDeployExtendedNetworks.sol";
import {LibCloneCandidates} from "../lib/LibCloneCandidates.sol";
import {
    PER_NETWORK_CLONE_RECORD_CONTRACT,
    perNetworkCloneChainIds,
    perNetworkCloneDeploys,
    perNetworkCloneNetworks,
    perNetworkCloneRelease,
    perNetworkCloneReleased
} from "../abstract/PerNetworkCloneDeploys.sol";

/// @title PerNetworkCloneBuildScriptHarness
/// @notice A per-network clone deploy repo's build script over a fixture record root, its extended networks declared
/// through the clone layer config.
contract PerNetworkCloneBuildScriptHarness is BuildScript {
    string internal sRoot;

    string internal sLibDir;

    /// The networks the clone layer declares for the release. Empty by default.
    ChainDeploy[] internal sExtendedNetworks;

    /// The licence the extended networks records declare once `setExtendedNetworksLicence` has run.
    string internal sSpdxLicenseIdentifier;

    string internal sCopyrightText;

    /// @param root The record root to regenerate and cut into, and the config root.
    /// @param libDir The directory the released-suites lib is written to.
    constructor(string memory root, string memory libDir) {
        sRoot = root;
        sLibDir = libDir;
    }

    /// @return The releases the declaration holds.
    function released() internal pure virtual returns (DeploySuite[] memory) {
        return perNetworkCloneReleased();
    }

    /// @return The extended networks the clone layer declares, keyed by release.
    function extended() internal view virtual returns (ExtendedNetworksDeclaration[] memory) {
        ExtendedNetworksDeclaration[] memory declared = new ExtendedNetworksDeclaration[](1);
        declared[0] = ExtendedNetworksDeclaration({suite: "per-network-clone@0_0_1", networks: sExtendedNetworks});
        return declared;
    }

    function declaration() internal view override returns (DeployDeclaration memory) {
        DeployDeclaration memory d;
        LibRainDeployDeclaration.extend(d);
        LibRainDeployDeclaration.setNetworks(d, perNetworkCloneNetworks());
        LibRainDeployZoltuMechanism.extend(d);
        LibRainDeployCloneMechanism.extend(
            d, CloneLayerConfig({beacons: new ChainBeacon[](0), extendedNetworksRoot: sRoot, extended: extended()})
        );
        LibRainDeployDeclaration.addReleased(d, released());
        LibCloneCandidates.addClones(d, perNetworkCloneDeploys());
        return d;
    }

    /// @inheritdoc BuildScript
    function recordRoot() internal view override returns (string memory) {
        return sRoot;
    }

    /// @inheritdoc BuildScript
    function configRoot() internal view override returns (string memory) {
        return sRoot;
    }

    /// @inheritdoc BuildScript
    function snapshotContractNames() internal pure override returns (string[] memory) {
        string[] memory names = new string[](1);
        names[0] = PER_NETWORK_CLONE_RECORD_CONTRACT;
        return names;
    }

    /// @inheritdoc BuildScript
    function regenerateSnapshots() internal override {
        writeSuiteSnapshot(
            declaration(),
            vm,
            SnapshotFile(
                recordRoot(),
                LibRainDeploySnapshot.CANDIDATE,
                PER_NETWORK_CLONE_RECORD_CONTRACT,
                RAIN_SPDX_LICENSE_IDENTIFIER,
                RAIN_COPYRIGHT_TEXT
            ),
            LibRainDeployCloneMechanism.cloneCandidate(perNetworkCloneRelease(), perNetworkCloneChainIds()).snapshot
        );
    }

    /// @inheritdoc BuildScript
    function regenerateLibs(DeployDeclaration memory d) internal override {
        LibRainDeploySnapshot.writeReleasedSuitesLib(
            vm, sLibDir, recordRoot(), PER_NETWORK_CLONE_RECORD_CONTRACT, d.candidates[0].snapshot, d
        );
        regenerateExtendedNetworks(d);
    }

    /// @inheritdoc BuildScript
    function buildGeneratedPaths() internal view override returns (string[] memory) {
        return LibRainDeployCloneBuild.extendedNetworksPaths(declaration());
    }

    function regenerateExtendedNetworks(DeployDeclaration memory d) internal {
        LibRainDeployCloneBuild.regenerateExtendedNetworks(
            vm,
            d,
            bytes(sSpdxLicenseIdentifier).length == 0 ? RAIN_SPDX_LICENSE_IDENTIFIER : sSpdxLicenseIdentifier,
            bytes(sCopyrightText).length == 0 ? RAIN_COPYRIGHT_TEXT : sCopyrightText
        );
    }

    /// Sets what the clone layer declares for the release.
    /// @param networks The networks.
    function setExtendedNetworks(ChainDeploy[] memory networks) external {
        delete sExtendedNetworks;
        for (uint256 i = 0; i < networks.length; i++) {
            sExtendedNetworks.push(networks[i]);
        }
    }

    /// Sets the licence the extended networks records declare.
    /// @param spdxLicenseIdentifier The SPDX licence identifier.
    /// @param copyrightText The copyright text.
    function setExtendedNetworksLicence(string memory spdxLicenseIdentifier, string memory copyrightText) external {
        sSpdxLicenseIdentifier = spdxLicenseIdentifier;
        sCopyrightText = copyrightText;
    }

    /// Writes the config fixtures `run()` splices into, under the config root.
    function seedConfig() external {
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.createDir(sRoot, true);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.writeFile(
            LibRainDeployConfig.configPath(configRoot()),
            string.concat(
                "# hand written\n",
                "# rain-deploy:generated:rpc_endpoints:begin\n",
                "STALE\n",
                "# rain-deploy:generated:rpc_endpoints:end\n",
                "# rain-deploy:generated:etherscan:begin\n",
                "STALE\n",
                "# rain-deploy:generated:etherscan:end\n"
            )
        );
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.writeFile(
            LibRainDeployConfig.envExamplePath(configRoot()),
            string.concat(
                "# hand written\n",
                "# rain-deploy:generated:env:begin\n",
                "STALE=1\n",
                "# rain-deploy:generated:env:end\n"
            )
        );
    }

    /// External wrapper for `regenerateExtendedNetworks` over the current declaration.
    function externalRegenerateExtendedNetworks() external {
        regenerateExtendedNetworks(declaration());
    }

    /// @return The paths `run()` declares.
    function externalGeneratedPaths() external view returns (string[] memory) {
        return generatedPaths();
    }

    /// @return The rolling snapshot's path.
    function rollingPath() external view returns (string memory) {
        return LibRainDeploySnapshot.pathForSnapshot(
            recordRoot(), LibRainDeploySnapshot.CANDIDATE, PER_NETWORK_CLONE_RECORD_CONTRACT
        );
    }

    /// @return The path `cutRelease()` freezes the rolling snapshot to.
    function frozenPath() external view returns (string memory) {
        return LibRainDeploySnapshot.pathForSnapshot(
            recordRoot(), LibRainDeploySnapshot.deployTag(vm), PER_NETWORK_CLONE_RECORD_CONTRACT
        );
    }

    /// @return The released-suites lib's path.
    function releasedLibPath() external view returns (string memory) {
        return LibRainDeploySnapshot.pathForLib(
            sLibDir, LibRainDeploySnapshot.releasedLibraryName(PER_NETWORK_CLONE_RECORD_CONTRACT)
        );
    }
}
