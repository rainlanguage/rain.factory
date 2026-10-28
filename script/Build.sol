// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Script} from "forge-std-1.17.0/src/Script.sol";
import {BeaconProxy} from "@openzeppelin-contracts-5.7.0/proxy/beacon/BeaconProxy.sol";
import {RegistryBeaconProxy} from "./RegistryBeaconProxy.sol";
import {LibCodeGen} from "rain-sol-codegen-0.1.39/src/lib/LibCodeGen.sol";
import {LibFs} from "rain-sol-codegen-0.1.39/src/lib/LibFs.sol";
import {LibRainDeploy} from "rain-deploy-0.1.27/src/lib/LibRainDeploy.sol";
import {LibRainDeployConfig} from "rain-deploy-0.1.27/src/lib/LibRainDeployConfig.sol";

/// @title Build
/// @notice Writes `src/generated/BeaconProxy.sol`: OpenZeppelin `BeaconProxy`'s
/// creation code as compiled under this repo's `foundry.toml`, which
/// `LibICloneableFactoryV5` deploys. Also stages `foundry.toml` with its
/// `[rpc_endpoints]` block generated from rain-deploy's network catalogue, which
/// the chain tests fork by name; `rainix-copy-artifacts` installs it, because
/// foundry refuses a cheatcode write to `foundry.toml`.
contract Build is Script {
    function run() external {
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.writeFile(
            LibFs.pathForContract("BeaconProxy"),
            string.concat(
                LibCodeGen.filePrefix(),
                LibCodeGen.bytesConstantString(
                    vm,
                    "/// @dev OpenZeppelin `BeaconProxy` creation code, without constructor arguments. Needs Cancun: it uses `MCOPY`.",
                    "BEACON_PROXY_CREATION_CODE",
                    type(BeaconProxy).creationCode
                )
            )
        );
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.writeFile(
            LibFs.pathForContract("RegistryBeaconProxy"),
            string.concat(
                LibCodeGen.filePrefix(),
                LibCodeGen.bytesConstantString(
                    vm,
                    "/// @dev `RegistryBeaconProxy` creation code. It takes no constructor arguments, so it is the same on every chain.",
                    "REGISTRY_BEACON_PROXY_CREATION_CODE",
                    type(RegistryBeaconProxy).creationCode
                )
            )
        );
        stageRpcEndpoints();
    }

    function stageRpcEndpoints() internal {
        string memory root = LibRainDeployConfig.CONFIG_ROOT;
        string memory path = LibRainDeployConfig.configPath(root);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.createDir(LibRainDeployConfig.stagedDir(root), true);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.writeFile(
            LibRainDeployConfig.stagedPath(root, LibRainDeployConfig.CONFIG_NAME),
            LibRainDeployConfig.spliceBlock(
                vm,
                path,
                vm.readFile(path),
                LibRainDeployConfig.RPC_ENDPOINTS_BLOCK,
                LibRainDeployConfig.rpcEndpointsSection(vm, LibRainDeploy.supportedNetworkConfigs())
            )
        );
    }
}
