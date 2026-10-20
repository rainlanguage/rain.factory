// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Script} from "forge-std-1.17.0/src/Script.sol";
import {BeaconProxy} from "@openzeppelin-contracts-5.6.1/proxy/beacon/BeaconProxy.sol";
import {LibCodeGen} from "rain-sol-codegen-0.1.39/src/lib/LibCodeGen.sol";
import {LibFs} from "rain-sol-codegen-0.1.39/src/lib/LibFs.sol";

/// @title Build
/// @notice Writes `src/generated/BeaconProxy.sol`: OpenZeppelin `BeaconProxy`'s
/// creation code as compiled under this repo's `foundry.toml`, which
/// `LibICloneableFactoryV5` deploys.
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
    }
}
