// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Script} from "forge-std/Script.sol";
import {CloneFactory} from "src/concrete/CloneFactory.sol";

/// @title DeployCloneFactory
/// @notice A script that deploys a CloneFactory. This is intended to be run on
/// every commit by CI to a testnet such as mumbai, then cross chain deployed to
/// whatever mainnet is required, by users.
contract DeployCloneFactory is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYMENT_KEY");

        vm.startBroadcast(deployerPrivateKey);
        CloneFactory cloneFactory = new CloneFactory();
        (cloneFactory);
        vm.stopBroadcast();
    }
}
