// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {LibRainDeployCloneBuild} from "../../../src/lib/LibRainDeployCloneBuild.sol";
import {ChainDeploy} from "../../../src/lib/LibRainDeployExtendedNetworks.sol";

/// @title LibRainDeployCloneBuildAppendedToTest
/// @notice `appendedTo` is what a declaration adds after a release's extended networks record: the suffix of a
/// declaration holding the record unchanged as its prefix, else none.
contract LibRainDeployCloneBuildAppendedToTest is Test {
    uint256 constant MAX_NETWORKS = 8;

    /// `length` networks on consecutive chain ids from `firstChainId`, their data and addresses drawn from `seed`.
    function networks(uint256 seed, uint256 length, uint256 firstChainId) internal pure returns (ChainDeploy[] memory) {
        ChainDeploy[] memory result = new ChainDeploy[](length);
        for (uint256 i = 0; i < length; i++) {
            bytes32 entropy = keccak256(abi.encode(seed, i));
            result[i] = ChainDeploy({
                chainId: firstChainId + i,
                data: uint8(entropy[0]) % 2 == 0 ? bytes("") : abi.encodePacked(entropy),
                deployedAddress: address(uint160(uint256(entropy)))
            });
        }
        return result;
    }

    function concat(ChainDeploy[] memory a, ChainDeploy[] memory b) internal pure returns (ChainDeploy[] memory) {
        ChainDeploy[] memory result = new ChainDeploy[](a.length + b.length);
        for (uint256 i = 0; i < a.length; i++) {
            result[i] = a[i];
        }
        for (uint256 i = 0; i < b.length; i++) {
            result[a.length + i] = b[i];
        }
        return result;
    }

    /// A record of up to `MAX_NETWORKS` networks and up to `MAX_NETWORKS` more on chain ids it does not hold.
    function recordAndAppended(uint256 seed, uint256 recordedLength, uint256 appendedLength)
        internal
        pure
        returns (ChainDeploy[] memory, ChainDeploy[] memory)
    {
        ChainDeploy[] memory recorded = networks(seed, recordedLength, 1);
        ChainDeploy[] memory appended = networks(~seed, appendedLength, 1 + recordedLength);
        return (recorded, appended);
    }

    function testAppendedToIsTheSuffixAfterTheRecord(uint256 seed, uint256 recordedLength, uint256 appendedLength)
        external
        pure
    {
        recordedLength = bound(recordedLength, 0, MAX_NETWORKS);
        appendedLength = bound(appendedLength, 0, MAX_NETWORKS);
        (ChainDeploy[] memory recorded, ChainDeploy[] memory appended) =
            recordAndAppended(seed, recordedLength, appendedLength);

        assertEq(
            abi.encode(LibRainDeployCloneBuild.appendedTo(recorded, concat(recorded, appended))), abi.encode(appended)
        );
    }

    function testAppendedToIsNoneWhenARecordedNetworkIsDropped(
        uint256 seed,
        uint256 recordedLength,
        uint256 appendedLength,
        uint256 dropped
    ) external pure {
        recordedLength = bound(recordedLength, 1, MAX_NETWORKS);
        appendedLength = bound(appendedLength, 0, MAX_NETWORKS);
        dropped = bound(dropped, 0, recordedLength - 1);
        (ChainDeploy[] memory recorded, ChainDeploy[] memory appended) =
            recordAndAppended(seed, recordedLength, appendedLength);
        ChainDeploy[] memory kept = new ChainDeploy[](recordedLength - 1);
        for (uint256 i = 0; i < kept.length; i++) {
            kept[i] = recorded[i < dropped ? i : i + 1];
        }

        assertEq(LibRainDeployCloneBuild.appendedTo(recorded, concat(kept, appended)).length, 0);
    }

    function testAppendedToIsNoneWhenARecordedNetworkIsChanged(
        uint256 seed,
        uint256 recordedLength,
        uint256 appendedLength,
        uint256 changedIndex,
        uint256 field
    ) external pure {
        recordedLength = bound(recordedLength, 1, MAX_NETWORKS);
        appendedLength = bound(appendedLength, 0, MAX_NETWORKS);
        changedIndex = bound(changedIndex, 0, recordedLength - 1);
        (ChainDeploy[] memory recorded, ChainDeploy[] memory appended) =
            recordAndAppended(seed, recordedLength, appendedLength);
        ChainDeploy[] memory changed = networks(seed, recordedLength, 1);
        field = bound(field, 0, 2);
        if (field == 0) {
            changed[changedIndex].chainId += MAX_NETWORKS * 2 + 1;
        } else if (field == 1) {
            changed[changedIndex].data = abi.encodePacked(changed[changedIndex].data, bytes1(0));
        } else {
            changed[changedIndex].deployedAddress = address(uint160(changed[changedIndex].deployedAddress) ^ 1);
        }

        assertEq(LibRainDeployCloneBuild.appendedTo(recorded, concat(changed, appended)).length, 0);
    }

    function testAppendedToIsNoneWhenRecordedNetworksAreReordered(
        uint256 seed,
        uint256 recordedLength,
        uint256 appendedLength,
        uint256 first,
        uint256 second
    ) external pure {
        recordedLength = bound(recordedLength, 2, MAX_NETWORKS);
        appendedLength = bound(appendedLength, 0, MAX_NETWORKS);
        second = bound(second, 1, recordedLength - 1);
        first = bound(first, 0, second - 1);
        (ChainDeploy[] memory recorded, ChainDeploy[] memory appended) =
            recordAndAppended(seed, recordedLength, appendedLength);
        ChainDeploy[] memory reordered = networks(seed, recordedLength, 1);
        (reordered[first], reordered[second]) = (reordered[second], reordered[first]);

        assertEq(LibRainDeployCloneBuild.appendedTo(recorded, concat(reordered, appended)).length, 0);
    }
}
