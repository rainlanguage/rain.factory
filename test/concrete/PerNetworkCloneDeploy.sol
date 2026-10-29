// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {StdConstants} from "forge-std-1.17.0/src/StdConstants.sol";
import {DeployDeclaration, RainDeploySuitesBase} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.29/src/lib/LibRainDeployDeclaration.sol";
import {LibRainDeployZoltuMechanism} from "rain-deploy-0.1.29/src/lib/LibRainDeployZoltuMechanism.sol";
import {ChainDeploy, LibRainDeployExtendedNetworks} from "../../src/lib/LibRainDeployExtendedNetworks.sol";
import {ExtendedNetworksDeclaration, LibRainDeployCloneMechanism} from "../../src/lib/LibRainDeployCloneMechanism.sol";
import {ExternalDeployBroadcast} from "../abstract/ExternalDeployBroadcast.sol";
import {
    PerNetworkCloneDeploys,
    perNetworkCloneDeploys,
    perNetworkCloneNetworks,
    perNetworkCloneReleased
} from "../abstract/PerNetworkCloneDeploys.sol";
import {LibCloneCandidates} from "../../src/lib/LibCloneCandidates.sol";
import {LibExtendedNetworksFixture} from "../lib/LibExtendedNetworksFixture.sol";

/// @title PerNetworkCloneDeploy
/// @notice `PerNetworkCloneDeploys` as a broadcast script whose clone layer declares the extended networks a test
/// sets, under a record root of that test's own.
contract PerNetworkCloneDeploy is PerNetworkCloneDeploys, ExternalDeployBroadcast {
    /// The suite `sExtendedNetworks` is declared for.
    string internal sExtendedSuite;

    /// The networks declared for `sExtendedSuite`. Empty by default.
    ChainDeploy[] internal sExtendedNetworks;

    /// The record root the clone layer reads under once `declareExtendedNetworks` has run.
    string internal sExtendedRoot;

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
        extendCloneLayer(d);
        LibRainDeployDeclaration.addReleased(d, perNetworkCloneReleased());
        LibCloneCandidates.addClones(d, perNetworkCloneDeploys());
        return d;
    }

    /// Extends `d` with the clone layer under the record root `declareExtendedNetworks` set, and its one declaration
    /// once it has run.
    function extendCloneLayer(DeployDeclaration memory d) internal view {
        LibRainDeployCloneMechanism.extend(d);
        if (bytes(sExtendedSuite).length == 0) {
            return;
        }
        LibRainDeployCloneMechanism.setExtendedNetworksRoot(d, sExtendedRoot);
        ExtendedNetworksDeclaration[] memory extended = new ExtendedNetworksDeclaration[](1);
        extended[0] = ExtendedNetworksDeclaration({suite: sExtendedSuite, networks: sExtendedNetworks});
        LibRainDeployCloneMechanism.setExtendedNetworks(d, extended);
    }

    /// Declares `networks` for `suite`, and records them as the build would under the fixture root, after removing
    /// whatever an earlier run left there.
    /// @param label The fixture root's directory under `fixture-lib/extended-networks`, one per test.
    /// @param suite The release's suite key.
    /// @param networks The networks it declares for that release.
    function setExtendedNetworks(string memory label, string memory suite, ChainDeploy[] memory networks) external {
        declareExtendedNetworks(label, suite, networks);
        LibRainDeployExtendedNetworks.writeExtendedNetworks(StdConstants.VM, sExtendedRoot, suite, networks);
    }

    /// `setExtendedNetworks` without the record: the fixture root holds none.
    /// @param label The fixture root's directory under `fixture-lib/extended-networks`, one per test.
    /// @param suite The release's suite key.
    /// @param networks The networks it declares for that release.
    function declareExtendedNetworks(string memory label, string memory suite, ChainDeploy[] memory networks) public {
        sExtendedRoot =
            LibExtendedNetworksFixture.freshRoot(StdConstants.VM, "fixture-lib/extended-networks", label, suite);
        sExtendedSuite = suite;
        delete sExtendedNetworks;
        for (uint256 i = 0; i < networks.length; i++) {
            sExtendedNetworks.push(networks[i]);
        }
    }
}
