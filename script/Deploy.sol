// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Script} from "forge-std/Script.sol";
import {CloneFactory} from "src/concrete/CloneFactory.sol";

/// @title Deploy
/// @notice A script that deploys a CloneFactory.
contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYMENT_KEY");

        LibRainDeploy.deployAndBroadcastToSupportedNetworks(
            vm,
            LibRainDeploy.supportedNetworks(),
            deployerPrivateKey,
            type(CloneFactory).creationCode,
            "",
            LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_ADDRESS,
            LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_CODEHASH,
            new address[](0)
        );

        // vm.startBroadcast(deployerPrivateKey);
        // CloneFactory cloneFactory = new CloneFactory();
        // (cloneFactory);
        // vm.stopBroadcast();
    }
}
