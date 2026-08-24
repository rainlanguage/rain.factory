// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.16.1/src/Test.sol";

import {ICloneableFactoryV3} from "src/interface/ICloneableFactoryV3.sol";
import {ICloneableFactoryV2} from "src/interface/ICloneableFactoryV2.sol";
import {LibPublishedAbi} from "test/src/lib/LibPublishedAbi.sol";
import {TestCloneFactory} from "test/src/concrete/TestCloneFactory.sol";
import {TestCloneable} from "test/src/concrete/TestCloneable.sol";

/// @title ICloneableFactoryV3DeclarationTest
/// @notice Pins the PUBLISHED declaration of `ICloneableFactoryV3` — the
/// `NewClone` event and the two function signatures — as a consumer sees it.
///
/// The flow tests already assert `topics[0]` and the whole log data blob, and
/// that is enough for anything the EVM can see. It is NOT enough for the
/// event's actual contract, which is that "an indexer can reconstruct the
/// deploy from the event alone": an indexer decodes the five fields BY NAME
/// from the ABI. Swapping two of the three `address` parameters in the
/// declaration leaves every topic and every data byte identical while telling
/// every consumer that the deployer is the clone — so it is the artifact, not
/// the log, that has to be pinned.
contract ICloneableFactoryV3DeclarationTest is Test {
    /// `NewClone`'s wire identity: the five-parameter signature, hashed. This
    /// is what an indexer subscribes to, and it is deliberately restated from
    /// the literal string rather than read back off the event.
    function testNewCloneTopicZeroPinned() external pure {
        assertEq(ICloneableFactoryV3.NewClone.selector, keccak256("NewClone(address,address,address,bytes32,bytes)"));
    }

    /// `ICloneableFactoryV3.NewClone` and `ICloneableFactoryV2.NewClone` share
    /// a NAME across the published interface family and are DIFFERENT events:
    /// five parameters against three, and therefore different `topics[0]`.
    /// Pinned as a fact of the published surface — an indexer keyed on
    /// `topics[0]` separates them, one keyed on the name alone does not.
    function testNewCloneNameIsSharedAcrossTheInterfaceFamily() external pure {
        assertTrue(ICloneableFactoryV3.NewClone.selector != ICloneableFactoryV2.NewClone.selector);
        assertEq(ICloneableFactoryV2.NewClone.selector, keccak256("NewClone(address,address,address)"));
    }

    /// The two function selectors of the V3 surface.
    function testFunctionSelectorsPinned() external pure {
        assertEq(
            ICloneableFactoryV3.cloneDeterministic.selector,
            bytes4(keccak256("cloneDeterministic(address,bytes,bytes32)"))
        );
        assertEq(
            ICloneableFactoryV3.predictDeterministicAddress.selector,
            bytes4(keccak256("predictDeterministicAddress(address,bytes32,address)"))
        );
    }

    /// THE DECLARATION ITSELF. The five parameters in order, each with its
    /// published name and type, none of them `indexed`, and the event not
    /// anonymous. Written out as the ABI a consumer downloads, so a reorder or
    /// a rename — neither of which any log assertion can see — fails here.
    function testNewCloneAbiPinned() external view {
        assertTrue(
            vm.contains(
                LibPublishedAbi.artifactJson("ICloneableFactoryV3", "ICloneableFactoryV3"),
                "{\"type\":\"event\",\"name\":\"NewClone\",\"inputs\":["
                "{\"name\":\"sender\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},"
                "{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},"
                "{\"name\":\"clone\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},"
                "{\"name\":\"salt\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},"
                "{\"name\":\"data\",\"type\":\"bytes\",\"indexed\":false,\"internalType\":\"bytes\"}"
                "],\"anonymous\":false}"
            ),
            "NewClone: sender, implementation, clone, salt, data - in that order, none indexed"
        );
    }

    /// The V3 function declarations, as published.
    function testFunctionAbiPinned() external view {
        string memory json = LibPublishedAbi.artifactJson("ICloneableFactoryV3", "ICloneableFactoryV3");
        assertTrue(
            vm.contains(
                json,
                "{\"type\":\"function\",\"name\":\"cloneDeterministic\",\"inputs\":["
                "{\"name\":\"implementation\",\"type\":\"address\",\"internalType\":\"address\"},"
                "{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"},"
                "{\"name\":\"salt\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}"
                "],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],"
                "\"stateMutability\":\"nonpayable\"}"
            ),
            "cloneDeterministic(implementation, data, salt) returns address"
        );
        assertTrue(
            vm.contains(
                json,
                "{\"type\":\"function\",\"name\":\"predictDeterministicAddress\",\"inputs\":["
                "{\"name\":\"implementation\",\"type\":\"address\",\"internalType\":\"address\"},"
                "{\"name\":\"salt\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},"
                "{\"name\":\"deployer\",\"type\":\"address\",\"internalType\":\"address\"}"
                "],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],"
                "\"stateMutability\":\"view\"}"
            ),
            "predictDeterministicAddress(implementation, salt, deployer) returns address, view"
        );
    }

    /// `NewClone` is SHARED IDENTICALLY by both entry points, not merely
    /// emitted by each: the same `topics[0]`, the same topic count, and the
    /// same data layout come out of `cloneDeterministic` and
    /// `cloneDeterministicOpenSalt` for the same caller, implementation, salt
    /// and data. Asserted against each other in one test, so a change that
    /// forked the two would fail here even if it kept each entry point
    /// self-consistent.
    function testNewCloneSharedByBothEntryPoints(bytes32 salt, bytes memory data) external {
        TestCloneFactory factory = new TestCloneFactory();
        TestCloneable implementation = new TestCloneable();

        uint256 snapshot = vm.snapshotState();

        vm.recordLogs();
        address namespacedChild = factory.cloneDeterministic(address(implementation), data, salt);
        Vm.Log[] memory namespacedLogs = vm.getRecordedLogs();

        vm.revertToState(snapshot);

        vm.recordLogs();
        address openChild = factory.cloneDeterministicOpenSalt(address(implementation), data, salt);
        Vm.Log[] memory openLogs = vm.getRecordedLogs();

        assertEq(namespacedLogs.length, 1);
        assertEq(openLogs.length, 1);
        assertEq(namespacedLogs[0].topics.length, 1);
        assertEq(openLogs[0].topics.length, 1);
        assertEq(namespacedLogs[0].topics[0], openLogs[0].topics[0]);
        assertEq(namespacedLogs[0].topics[0], ICloneableFactoryV3.NewClone.selector);

        // The two derivations put the clone at different addresses, so the
        // blobs differ in exactly that one field and nowhere else.
        assertTrue(namespacedChild != openChild);
        assertEq(
            namespacedLogs[0].data, abi.encode(address(this), address(implementation), namespacedChild, salt, data)
        );
        assertEq(openLogs[0].data, abi.encode(address(this), address(implementation), openChild, salt, data));
    }
}
