// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Script} from "forge-std/Script.sol";
import {CloneFactory} from "../src/concrete/CloneFactory.sol";
import {LibRainDeploy} from "rain.deploy/lib/LibRainDeploy.sol";
import {LibCloneFactoryDeploy} from "../src/lib/LibCloneFactoryDeploy.sol";

/// @title Deploy
/// @notice A script that deploys a CloneFactory.
contract Deploy is Script {
    mapping(string => mapping(address => bytes32)) internal sDepCodeHashes;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYMENT_KEY");

        LibRainDeploy.deployAndBroadcast(
            vm,
            LibRainDeploy.supportedNetworks(),
            deployerPrivateKey,
            type(CloneFactory).creationCode,
            "src/concrete/CloneFactory.sol:CloneFactory",
            LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_ADDRESS,
            LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_CODEHASH,
            new address[](0),
            sDepCodeHashes
        );
    }
}
