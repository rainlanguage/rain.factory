// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.17.0/src/Test.sol";
import {BeaconProxy} from "@openzeppelin-contracts-5.6.1/proxy/beacon/BeaconProxy.sol";
import {RegistryBeaconProxy} from "../../script/RegistryBeaconProxy.sol";
import {Build} from "../../script/Build.sol";

contract BuildTest is Test {
    /// `Build.run` rewrites the committed `src/generated/BeaconProxy.sol` byte
    /// for byte, with OZ `BeaconProxy`'s creation code, and writes no other
    /// file. The committed file is restored before any assertion, even if the
    /// script reverts.
    function testBuildRewritesCommittedBeaconProxy() external {
        string memory path = "src/generated/BeaconProxy.sol";
        string memory committed = vm.readFile(path);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.writeFile(path, "// Build.t.sol was interrupted: run forge script script/Build.sol\n");
        bool ran;
        try new Build().run() {
            ran = true;
        } catch {}
        string memory written = vm.readFile(path);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.writeFile(path, committed);

        assertTrue(ran);
        assertEq(written, committed);
        assertTrue(
            vm.indexOf(written, vm.replace(vm.toString(type(BeaconProxy).creationCode), "0x", "")) != type(uint256).max
        );
        Vm.DirEntry[] memory entries = vm.readDir("src/generated");
        assertEq(entries.length, 2);
    }

    /// The script writes exactly the committed `RegistryBeaconProxy` snapshot.
    function testBuildRewritesCommittedRegistryBeaconProxy() external {
        string memory path = "src/generated/RegistryBeaconProxy.sol";
        string memory committed = vm.readFile(path);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.writeFile(path, "// Build.t.sol was interrupted: run forge script script/Build.sol\n");
        bool ran;
        try new Build().run() {
            ran = true;
        } catch {}
        string memory written = vm.readFile(path);
        //forge-lint: disable-next-line(unsafe-cheatcode)
        vm.writeFile(path, committed);
        assertTrue(ran);
        assertEq(written, committed);
        assertTrue(
            vm.indexOf(written, vm.replace(vm.toString(type(RegistryBeaconProxy).creationCode), "0x", ""))
                != type(uint256).max
        );
    }
}
