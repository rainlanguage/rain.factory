// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {Script} from "forge-std/Script.sol";
import {CloneFactory} from "src/concrete/CloneFactory.sol";

/// @title Deploy
/// @notice A script that deploys a CloneFactory.
contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYMENT_KEY");

        vm.startBroadcast(deployerPrivateKey);
        CloneFactory cloneFactory = new CloneFactory();
        (cloneFactory);
        vm.stopBroadcast();
    }
}
