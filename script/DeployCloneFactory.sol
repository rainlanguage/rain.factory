// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {CloneFactory} from "src/concrete/CloneFactory.sol";
import {
    DeployerDiscoverableMetaV3,
    DeployerDiscoverableMetaV3ConstructionConfig
} from "rain.interpreter/src/abstract/DeployerDiscoverableMetaV3.sol";

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
        // hardcoded from CI https://github.com/rainprotocol/rain.interpreter/actions/runs/6945028339/job/18893471403
        address i9rDeployer = 0x5c67221f721D1EEa73d99551b271DfDBB16902CF;

        console2.log("meta hash:");
        console2.logBytes32(keccak256(meta));

        vm.startBroadcast(deployerPrivateKey);
        CloneFactory cloneFactory = new CloneFactory(DeployerDiscoverableMetaV3ConstructionConfig (
            i9rDeployer,
            meta
        ));
        (cloneFactory);
        vm.stopBroadcast();
    }
}
