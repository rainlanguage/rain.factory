// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {DeployDeclaration} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {
    ChainDeploy,
    ExtendedNetworksUnrecorded,
    LibRainDeployExtendedNetworks
} from "../../../src/lib/LibRainDeployExtendedNetworks.sol";
import {
    ExtendedNetworksDeclaration,
    LibRainDeployCloneMechanism
} from "../../../src/lib/LibRainDeployCloneMechanism.sol";
import {LibRainDeployCloneOnChainChecks} from "../../../src/lib/LibRainDeployCloneOnChainChecks.sol";
import {LibExtendedNetworksFixture} from "../../lib/LibExtendedNetworksFixture.sol";

/// @title LibRainDeployCloneOnChainChecksDeclarationPerNetworkTest
/// @notice `checkDeclarationPerNetwork` refuses any release whose declared extended networks are not its record.
contract LibRainDeployCloneOnChainChecksDeclarationPerNetworkTest is Test {
    string constant FIRST = "first-per-network-clone@0_0_1";
    string constant SECOND = "second-per-network-clone@0_0_1";

    function oneNetwork(uint256 chainId, bytes memory data, address deployedAddress)
        internal
        pure
        returns (ChainDeploy[] memory)
    {
        ChainDeploy[] memory networks = new ChainDeploy[](1);
        networks[0] = ChainDeploy({chainId: chainId, data: data, deployedAddress: deployedAddress});
        return networks;
    }

    function checkDeclarationPerNetwork(string memory label, bool firstRecorded, bool secondRecorded) external {
        string memory root = LibExtendedNetworksFixture.freshRoot(vm, "fixture-lib/extended-networks", label, FIRST);
        LibExtendedNetworksFixture.freshRoot(vm, "fixture-lib/extended-networks", label, SECOND);
        ExtendedNetworksDeclaration[] memory extended = new ExtendedNetworksDeclaration[](2);
        extended[0] = ExtendedNetworksDeclaration({
            suite: FIRST, networks: oneNetwork(137, hex"00aa", address(0x1111111111111111111111111111111111111111))
        });
        extended[1] = ExtendedNetworksDeclaration({
            suite: SECOND, networks: oneNetwork(8453, hex"", address(0xC4c4c4C4C4c4C4c4c4C4c4c4c4c4c4C4c4c4c4C4))
        });
        if (firstRecorded) {
            LibRainDeployExtendedNetworks.writeExtendedNetworks(vm, root, FIRST, extended[0].networks);
        }
        if (secondRecorded) {
            LibRainDeployExtendedNetworks.writeExtendedNetworks(vm, root, SECOND, extended[1].networks);
        }
        DeployDeclaration memory d;
        LibRainDeployCloneMechanism.extend(d);
        LibRainDeployCloneMechanism.setExtendedNetworksRoot(d, root);
        LibRainDeployCloneMechanism.setExtendedNetworks(d, extended);
        LibRainDeployCloneOnChainChecks.checkDeclarationPerNetwork(d);
    }

    function testCheckDeclarationPerNetworkPassesWhenEveryReleaseIsRecorded() external {
        this.checkDeclarationPerNetwork("declaration-all-recorded", true, true);
    }

    function testCheckDeclarationPerNetworkRefusesTheFirstReleaseUnrecorded() external {
        vm.expectRevert(abi.encodeWithSelector(ExtendedNetworksUnrecorded.selector, FIRST));
        this.checkDeclarationPerNetwork("declaration-first-unrecorded", false, true);
    }

    function testCheckDeclarationPerNetworkRefusesTheLastReleaseUnrecorded() external {
        vm.expectRevert(abi.encodeWithSelector(ExtendedNetworksUnrecorded.selector, SECOND));
        this.checkDeclarationPerNetwork("declaration-last-unrecorded", true, false);
    }
}
