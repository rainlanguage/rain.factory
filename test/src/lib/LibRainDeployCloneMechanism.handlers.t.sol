// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {DeployDeclaration} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.29/src/lib/LibRainDeployDeclaration.sol";
import {
    BEACON_PROXY_MECHANISM,
    BEACON_PROXY_PER_NETWORK_MECHANISM,
    CLONE_MECHANISM,
    CLONE_PER_NETWORK_MECHANISM,
    LibRainDeployCloneMechanism
} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {LibRainDeployCloneSnapshot} from "../../../src/lib/LibRainDeployCloneSnapshot.sol";

/// @title LibRainDeployCloneMechanismHandlersTest
/// @notice The handlers `extend` and `handler` add.
contract LibRainDeployCloneMechanismHandlersTest is Test {
    string constant FACTORY_IMPORT_ROOT = "rain-factory-0.2.5/src/";

    function releasedImportOf(DeployDeclaration memory d, bytes32 id) internal pure returns (string memory) {
        return LibRainDeployDeclaration.mechanismById(d, id, "").releasedImport(d, "");
    }

    function expectedImport(string memory constantName) internal pure returns (string memory) {
        return string.concat(
            "import {",
            constantName,
            "} from \"",
            FACTORY_IMPORT_ROOT,
            LibRainDeployCloneSnapshot.CLONE_MECHANISM_SOURCE_SUBPATH,
            "\";\n"
        );
    }

    function testEachHandlersReleasedImportNamesItsOwnMechanism() external view {
        DeployDeclaration memory d;
        LibRainDeployCloneMechanism.extend(d);
        LibRainDeployCloneMechanism.setFactoryImportRoot(d, FACTORY_IMPORT_ROOT);
        assertEq(releasedImportOf(d, CLONE_MECHANISM), expectedImport("CLONE_MECHANISM"));
        assertEq(releasedImportOf(d, CLONE_PER_NETWORK_MECHANISM), expectedImport("CLONE_PER_NETWORK_MECHANISM"));
        assertEq(releasedImportOf(d, BEACON_PROXY_MECHANISM), expectedImport("BEACON_PROXY_MECHANISM"));
        assertEq(
            releasedImportOf(d, BEACON_PROXY_PER_NETWORK_MECHANISM),
            expectedImport("BEACON_PROXY_PER_NETWORK_MECHANISM")
        );
    }

    function testLayerConfigSettersReachACloneHandlerThatIsTheOnlyMechanism() external view {
        DeployDeclaration memory d;
        LibRainDeployDeclaration.addMechanism(d, LibRainDeployCloneMechanism.handler());
        LibRainDeployCloneMechanism.setFactoryImportRoot(d, FACTORY_IMPORT_ROOT);
        assertEq(LibRainDeployCloneMechanism.layerConfig(d).factoryImportRoot, FACTORY_IMPORT_ROOT);
    }
}
