// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {BuildScript, GeneratedContract} from "rain-deploy-0.1.30/src/abstract/BuildScript.sol";
import {DeployDeclaration, DeploySuite, SnapshotFile} from "rain-deploy-0.1.30/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeploy} from "rain-deploy-0.1.30/src/lib/LibRainDeploy.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.30/src/lib/LibRainDeployDeclaration.sol";
import {LibRainDeploySnapshot} from "rain-deploy-0.1.30/src/lib/LibRainDeploySnapshot.sol";
import {LibRainDeployZoltuMechanism} from "rain-deploy-0.1.30/src/lib/LibRainDeployZoltuMechanism.sol";
import {RAIN_COPYRIGHT_TEXT, RAIN_SPDX_LICENSE_IDENTIFIER} from "rain-sol-codegen-0.1.39/src/lib/LibCodeGen.sol";
import {LibRainDeployCloneBuild} from "../../src/lib/LibRainDeployCloneBuild.sol";
import {ExtendedNetworksDeclaration, LibRainDeployCloneMechanism} from "../../src/lib/LibRainDeployCloneMechanism.sol";
import {ChainDeploy} from "../../src/lib/LibRainDeployExtendedNetworks.sol";
import {CloneDeploy} from "../../src/lib/LibRainDeployClone.sol";
import {LibCloneCandidates} from "../../src/lib/LibCloneCandidates.sol";
import {
    EXAMPLE_CLONE_RECORD_CONTRACT,
    exampleCloneDeploys,
    exampleCloneRelease,
    exampleCloneReleased
} from "../abstract/ExampleCloneDeploys.sol";

/// @title CloneBuildScriptHarness
/// @notice A clone deploy repo's build script over a fixture record root, its extended networks declared through
/// the clone layer config.
contract CloneBuildScriptHarness is BuildScript {
    string internal sRoot;

    string internal sLibDir;

    /// The networks the clone layer declares for the release. Empty by default.
    ChainDeploy[] internal sExtendedNetworks;

    /// @param root The record root to regenerate and cut into, and the config root.
    /// @param libDirectory The directory the released-suites lib is written to.
    constructor(string memory root, string memory libDirectory) {
        sRoot = root;
        sLibDir = libDirectory;
    }

    function declaration() internal view override returns (DeployDeclaration memory) {
        DeployDeclaration memory d;
        LibRainDeployDeclaration.extend(d);
        string[] memory networks = new string[](1);
        networks[0] = LibRainDeploy.ARBITRUM_ONE;
        LibRainDeployDeclaration.setNetworks(d, networks);
        LibRainDeployZoltuMechanism.extend(d);
        ExtendedNetworksDeclaration[] memory extended = new ExtendedNetworksDeclaration[](1);
        extended[0] = ExtendedNetworksDeclaration({suite: "example-clone@0_0_1", networks: sExtendedNetworks});
        LibRainDeployCloneMechanism.extend(d);
        LibRainDeployCloneMechanism.setExtendedNetworksRoot(d, sRoot);
        LibRainDeployCloneMechanism.setExtendedNetworks(d, extended);
        LibRainDeployDeclaration.addReleased(d, exampleCloneReleased());
        CloneDeploy[] memory clones = new CloneDeploy[](1);
        clones[0] = exampleCloneDeploys()[0];
        LibCloneCandidates.addClones(d, clones);
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
    function generatedContracts(DeployDeclaration memory d)
        internal
        pure
        override
        returns (GeneratedContract[] memory)
    {
        GeneratedContract[] memory generated = new GeneratedContract[](1);
        generated[0] = GeneratedContract(EXAMPLE_CLONE_RECORD_CONTRACT, "", declaredCandidate(d, "example-clone"));
        return generated;
    }

    /// @inheritdoc BuildScript
    function libDir() internal view override returns (string memory) {
        return sLibDir;
    }

    /// @inheritdoc BuildScript
    function regenerateSnapshots() internal override {
        DeployDeclaration memory d = declaration();
        DeploySuite memory snapshot =
        LibRainDeployCloneMechanism.cloneCandidate(exampleCloneRelease(), new uint256[](0)).snapshot;
        snapshot.networks = d.networks;
        writeSuiteSnapshot(
            d,
            vm,
            SnapshotFile(
                recordRoot(),
                LibRainDeploySnapshot.CANDIDATE,
                EXAMPLE_CLONE_RECORD_CONTRACT,
                RAIN_SPDX_LICENSE_IDENTIFIER,
                RAIN_COPYRIGHT_TEXT
            ),
            snapshot
        );
        LibRainDeployCloneBuild.regenerateExtendedNetworks(vm, d);
    }

    /// @inheritdoc BuildScript
    function buildGeneratedPaths() internal view override returns (string[] memory) {
        return LibRainDeployCloneBuild.extendedNetworksPaths(declaration());
    }

    /// Sets what the clone layer declares for the release.
    /// @param networks The networks.
    function setExtendedNetworks(ChainDeploy[] memory networks) external {
        delete sExtendedNetworks;
        for (uint256 i = 0; i < networks.length; i++) {
            sExtendedNetworks.push(networks[i]);
        }
    }

    /// External wrapper for `regenerateExtendedNetworks` over the current declaration.
    function externalRegenerateExtendedNetworks() external {
        LibRainDeployCloneBuild.regenerateExtendedNetworks(vm, declaration());
    }

    /// @return The rolling snapshot's path.
    function rollingPath() external view returns (string memory) {
        return LibRainDeploySnapshot.pathForSnapshot(
            recordRoot(), LibRainDeploySnapshot.CANDIDATE, EXAMPLE_CLONE_RECORD_CONTRACT
        );
    }

    /// @return The path `cutRelease()` freezes the rolling snapshot to.
    function frozenPath() external view returns (string memory) {
        return LibRainDeploySnapshot.pathForSnapshot(
            recordRoot(), LibRainDeploySnapshot.deployTag(vm), EXAMPLE_CLONE_RECORD_CONTRACT
        );
    }

    /// @return The released-suites lib's path.
    function releasedLibPath() external view returns (string memory) {
        return LibRainDeploySnapshot.pathForLib(
            sLibDir, LibRainDeploySnapshot.releasedLibraryName(EXAMPLE_CLONE_RECORD_CONTRACT)
        );
    }
}
