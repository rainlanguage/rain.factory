// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import "../lib/forge-std/src/Script.sol";
import "../src/concrete/CloneFactory.sol";

/// @title DeployCloneFactory
/// @notice A script that deploys a CloneFactory. This is intended to be run on
/// every commit by CI to a testnet such as mumbai, then cross chain deployed to
/// whatever mainnet is required, by users.
contract DeployCloneFactory is Script {
    /// We are avoiding using ffi here, instead forcing the script runner to
    /// provide the built metadata. On CI this is achieved by using the rain cli.
    function run(bytes memory meta) external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYMENT_KEY");
        // @todo pull this from subgraph.
        // hardcoded from CI https://github.com/rainprotocol/rain-protocol/actions/runs/5039345251/jobs/9037426821
        address i9rDeployer = 0xB20DFEdC1b12AA6afA308064998A28531a18C714;

        console2.log("meta hash:");
        console2.logBytes32(keccak256(meta));

        vm.startBroadcast(deployerPrivateKey);
        CloneFactory cloneFactory = new CloneFactory(DeployerDiscoverableMetaV1ConstructionConfig (
            i9rDeployer,
            meta
        ));
        (cloneFactory);
        vm.stopBroadcast();
    }
}
