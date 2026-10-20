// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.17.0/src/Test.sol";
import {BeaconProxy} from "@openzeppelin-contracts-5.6.1/proxy/beacon/BeaconProxy.sol";
import {Build} from "../../script/Build.sol";

contract BuildTest is Test {
    /// `Build.run` rewrites the committed `src/generated/BeaconProxy.sol` byte
    /// for byte, with OZ `BeaconProxy`'s creation code, and writes no other
    /// file.
    function testBuildRewritesCommittedBeaconProxy() external {
        string memory path = "src/generated/BeaconProxy.sol";
        string memory committed = vm.readFile(path);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.writeFile(path, "");
        new Build().run();
        string memory written = vm.readFile(path);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.writeFile(path, committed);

        assertEq(written, committed);
        assertTrue(
            vm.indexOf(written, vm.replace(vm.toString(type(BeaconProxy).creationCode), "0x", "")) != type(uint256).max
        );
        Vm.DirEntry[] memory entries = vm.readDir("src/generated");
        assertEq(entries.length, 1);
    }
}
