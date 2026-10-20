// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.17.0/src/Test.sol";

import {Create2} from "@openzeppelin-contracts-5.6.1/utils/Create2.sol";
import {BeaconProxy} from "@openzeppelin-contracts-5.6.1/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.6.1/proxy/beacon/UpgradeableBeacon.sol";
import {ERC1967Utils} from "@openzeppelin-contracts-5.6.1/proxy/ERC1967/ERC1967Utils.sol";
import {LibTestBeaconProxy} from "../../lib/LibTestBeaconProxy.sol";
import {ICLONEABLE_V2_SUCCESS} from "../../../src/interface/ICloneableV2.sol";
import {
    ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN,
    ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN
} from "../../../src/interface/deprecated/ICloneableFactoryV4.sol";
import {ICLONEABLE_FACTORY_V5_BEACON_PROXY_OPEN_SALT_DOMAIN} from "../../../src/interface/ICloneableFactoryV5.sol";
import {
    CloneAddressOccupied,
    CloneDeploymentFailed,
    DelegatedImplementation,
    InitializationFailed,
    ZeroImplementationCodeSize
} from "../../../src/lib/LibICloneableFactoryV4.sol";
import {LibICloneableFactoryV5, ZeroBeaconCodeSize} from "../../../src/lib/LibICloneableFactoryV5.sol";
import {TestBeaconDivergent} from "../../concrete/TestBeaconDivergent.sol";
import {TestBeaconRawAnswer} from "../../concrete/TestBeaconRawAnswer.sol";
import {TestBeaconStrictCalldata} from "../../concrete/TestBeaconStrictCalldata.sol";
import {TestCloneFactory} from "../../concrete/TestCloneFactory.sol";
import {TestCloneable, TestCloneableAlreadyInitialized} from "../../concrete/TestCloneable.sol";
import {TestCloneableCallRecorder} from "../../concrete/TestCloneableCallRecorder.sol";
import {TestCloneableFailure} from "../../concrete/TestCloneableFailure.sol";
import {TestCloneableRawAnswer} from "../../concrete/TestCloneableRawAnswer.sol";
import {TestCloneableRevert, TestCloneableRevertInitialize} from "../../concrete/TestCloneableRevert.sol";

/// @title LibICloneableFactoryV5BeaconProxyDeterministicOpenSaltTest
/// @notice Tests `LibICloneableFactoryV5.beaconProxyDeterministicOpenSalt` /
/// `predictBeaconProxyAddressOpenSalt` through `TestCloneFactory`. The address
/// is pinned against OpenZeppelin `Create2` over an independently derived salt
/// and OpenZeppelin `BeaconProxy`'s creation code; the deploy is
/// checked for the guards, the event and the atomic initialize it shares with
/// `cloneDeterministicOpenSalt`.
contract LibICloneableFactoryV5BeaconProxyDeterministicOpenSaltTest is Test {
    /// The `TestCloneFactory` instance under test.
    TestCloneFactory internal immutable iCloneFactory;

    constructor() {
        iCloneFactory = new TestCloneFactory();
    }

    /// An OZ beacon serving a fresh `TestCloneable`, owned by this test.
    function newBeacon() internal returns (UpgradeableBeacon) {
        return new UpgradeableBeacon(address(new TestCloneable()), address(this));
    }

    /// The hash of OZ `BeaconProxy`'s creation code with `(beacon, "")` as
    /// constructor arguments.
    function ozCreationCodeHash(address beacon) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(type(BeaconProxy).creationCode, abi.encode(beacon, bytes(""))));
    }

    /// The derivation `ICloneableFactoryV5` fixes, computed without the
    /// library: OZ `Create2` over
    /// `keccak256(abi.encode(keccak256("rain.factory.beaconproxy.opensalt"), salt, keccak256(data)))`
    /// and `ozCreationCodeHash`.
    function expectedAddress(address beacon, bytes memory data, bytes32 salt) internal view returns (address) {
        bytes32 effectiveSalt =
            keccak256(abi.encode(keccak256("rain.factory.beaconproxy.opensalt"), salt, keccak256(data)));
        return Create2.computeAddress(effectiveSalt, ozCreationCodeHash(beacon), address(iCloneFactory));
    }

    /// The domain tag is the string it documents, and differs from both V4
    /// tags.
    function testBeaconProxyDomainTag() external pure {
        assertEq(ICLONEABLE_FACTORY_V5_BEACON_PROXY_OPEN_SALT_DOMAIN, keccak256("rain.factory.beaconproxy.opensalt"));
        assertTrue(ICLONEABLE_FACTORY_V5_BEACON_PROXY_OPEN_SALT_DOMAIN != ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN);
        assertTrue(ICLONEABLE_FACTORY_V5_BEACON_PROXY_OPEN_SALT_DOMAIN != ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN);
    }

    /// The effective salt is the documented 96-byte domain-tagged hash.
    function testEffectiveBeaconProxyOpenSalt(bytes32 salt, bytes memory data) external pure {
        assertEq(
            LibICloneableFactoryV5.effectiveBeaconProxyOpenSalt(salt, data),
            keccak256(abi.encode(keccak256("rain.factory.beaconproxy.opensalt"), salt, keccak256(data)))
        );
    }

    /// Fixed example: the expected value is `cast keccak` over the 96-byte
    /// concatenation of `cast keccak "rain.factory.beaconproxy.opensalt"`,
    /// the salt word and `cast keccak 0xabcdef`.
    function testEffectiveBeaconProxyOpenSaltFixedExample() external pure {
        assertEq(
            LibICloneableFactoryV5.effectiveBeaconProxyOpenSalt(bytes32(uint256(0xff)), hex"abcdef"),
            0xa78b62d74202c9c7a28df91ceee2d4968c81b78a3312893e9837744c4e1c6a7c
        );
    }

    /// The preimage is built past the free pointer without claiming or
    /// overwriting allocated memory.
    function testEffectiveBeaconProxyOpenSaltMemory(bytes32 salt, bytes memory data) external pure {
        bytes memory copy = bytes.concat(data);
        uint256 freeBefore;
        assembly ("memory-safe") {
            freeBefore := mload(0x40)
        }
        LibICloneableFactoryV5.effectiveBeaconProxyOpenSalt(salt, data);
        uint256 freeAfter;
        assembly ("memory-safe") {
            freeAfter := mload(0x40)
        }
        assertEq(freeAfter, freeBefore);
        assertEq(data, copy);
    }

    /// The prediction is the independently derived address, for any beacon,
    /// deployed or not: it reads nothing from the beacon.
    function testPredictBeaconProxyAddressOpenSalt(address beacon, bytes memory data, bytes32 salt) external view {
        assertEq(
            iCloneFactory.predictBeaconProxyAddressOpenSalt(beacon, data, salt), expectedAddress(beacon, data, salt)
        );
    }

    /// `predictBeaconProxyAddress` is `CREATE2` from the given factory, not
    /// the caller.
    function testPredictBeaconProxyAddress(address factory, address beacon, bytes32 derivedSalt) external pure {
        assertEq(
            LibICloneableFactoryV5.predictBeaconProxyAddress(factory, beacon, derivedSalt),
            Create2.computeAddress(derivedSalt, ozCreationCodeHash(beacon), factory)
        );
    }

    /// The proxy lands at the derived address with `BeaconProxy`'s runtime,
    /// the beacon in the ERC-1967 slot, and the data initialized into its
    /// own storage.
    function testBeaconProxyDeterministicOpenSaltDeploys(bytes memory data, bytes32 salt) external {
        UpgradeableBeacon beacon = newBeacon();
        address expected = expectedAddress(address(beacon), data, salt);

        address proxy = iCloneFactory.beaconProxyDeterministicOpenSalt(address(beacon), data, salt);

        assertEq(proxy, expected);
        assertEq(proxy.code, address(new BeaconProxy(address(beacon), "")).code);
        assertEq(vm.load(proxy, ERC1967Utils.BEACON_SLOT), bytes32(uint256(uint160(address(beacon)))));
        assertEq(TestCloneable(proxy).sData(), data);
        assertTrue(TestCloneable(proxy).sInitialized());
        assertFalse(TestCloneable(beacon.implementation()).sInitialized());
    }

    /// The same `(beacon, data, salt)` from two callers lands on the same
    /// address.
    function testBeaconProxyDeterministicOpenSaltCallerIndependent(
        bytes memory data,
        bytes32 salt,
        address alice,
        address bob
    ) external {
        vm.assume(alice != bob);
        UpgradeableBeacon beacon = newBeacon();
        uint256 snapshot = vm.snapshotState();
        vm.prank(alice);
        address proxyAlice = iCloneFactory.beaconProxyDeterministicOpenSalt(address(beacon), data, salt);
        vm.revertToState(snapshot);
        vm.prank(bob);
        address proxyBob = iCloneFactory.beaconProxyDeterministicOpenSalt(address(beacon), data, salt);
        assertEq(proxyAlice, proxyBob);
        assertEq(proxyAlice, expectedAddress(address(beacon), data, salt));
    }

    /// The prediction does not vary with the caller.
    function testPredictBeaconProxyAddressOpenSaltCallerIndependent(
        address beacon,
        bytes memory data,
        bytes32 salt,
        address alice
    ) external {
        address expected = expectedAddress(beacon, data, salt);
        vm.prank(alice);
        assertEq(iCloneFactory.predictBeaconProxyAddressOpenSalt(beacon, data, salt), expected);
    }

    /// `data`, `salt` and the beacon each move the address.
    function testBeaconProxyDeterministicOpenSaltInputsInDerivation(
        bytes memory dataA,
        bytes memory dataB,
        bytes32 saltA,
        bytes32 saltB
    ) external {
        vm.assume(keccak256(dataA) != keccak256(dataB));
        vm.assume(saltA != saltB);
        UpgradeableBeacon beaconA = newBeacon();
        UpgradeableBeacon beaconB = newBeacon();

        address proxy = iCloneFactory.beaconProxyDeterministicOpenSalt(address(beaconA), dataA, saltA);
        address otherData = iCloneFactory.beaconProxyDeterministicOpenSalt(address(beaconA), dataB, saltA);
        address otherSalt = iCloneFactory.beaconProxyDeterministicOpenSalt(address(beaconA), dataA, saltB);
        address otherBeacon = iCloneFactory.beaconProxyDeterministicOpenSalt(address(beaconB), dataA, saltA);

        assertTrue(proxy != otherData);
        assertTrue(proxy != otherSalt);
        assertTrue(proxy != otherBeacon);
        assertEq(TestCloneable(proxy).sData(), dataA);
        assertEq(TestCloneable(otherData).sData(), dataB);
    }

    /// The tag is what separates the beacon-proxy effective salt from the V4
    /// ones on the same caller-chosen words; the deploys land apart and
    /// neither V4 entry point consumes the beacon-proxy address.
    function testBeaconProxyDisjointFromV4(bytes memory data, address attacker) external {
        UpgradeableBeacon beacon = newBeacon();
        address implementation = beacon.implementation();
        bytes32 salt = bytes32(uint256(uint160(attacker)));

        bytes32 beaconSalt = LibICloneableFactoryV5.effectiveBeaconProxyOpenSalt(salt, data);
        assertTrue(beaconSalt != keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data))));
        assertTrue(
            beaconSalt != keccak256(abi.encode(ICLONEABLE_FACTORY_V4_NAMESPACED_DOMAIN, attacker, keccak256(data)))
        );

        address predicted = iCloneFactory.predictBeaconProxyAddressOpenSalt(address(beacon), data, salt);
        address openClone = iCloneFactory.cloneDeterministicOpenSalt(implementation, data, salt);
        vm.prank(attacker);
        address namespacedClone = iCloneFactory.cloneDeterministic(implementation, data, keccak256(data));
        assertTrue(openClone != predicted);
        assertTrue(namespacedClone != predicted);
        assertEq(predicted.code.length, 0);

        assertEq(iCloneFactory.beaconProxyDeterministicOpenSalt(address(beacon), data, salt), predicted);
    }

    /// The proxy emits `BeaconUpgraded(beacon)` while constructing, then the
    /// factory emits `NewClone` with the caller, the beacon as
    /// `implementation`, the proxy, the raw salt and the data.
    function testBeaconProxyDeterministicOpenSaltEvents(bytes memory data, bytes32 salt) external {
        UpgradeableBeacon beacon = newBeacon();
        vm.recordLogs();
        address proxy = iCloneFactory.beaconProxyDeterministicOpenSalt(address(beacon), data, salt);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 2);
        LibTestBeaconProxy.checkBeaconUpgradedLog(vm, logs[0], proxy, address(beacon));
        assertEq(logs[1].emitter, address(iCloneFactory));
        assertEq(logs[1].topics.length, 1);
        assertEq(logs[1].topics[0], keccak256("NewClone(address,address,address,bytes32,bytes)"));
        assertEq(logs[1].data, abi.encode(address(this), address(beacon), proxy, salt, data));
    }

    /// `initialize` is the only call the proxy receives, with `data`
    /// verbatim, after `NewClone`.
    function testBeaconProxyDeterministicOpenSaltInitializeOnly(bytes memory data, bytes32 salt) external {
        UpgradeableBeacon beacon = new UpgradeableBeacon(address(new TestCloneableCallRecorder()), address(this));
        vm.recordLogs();
        address proxy = iCloneFactory.beaconProxyDeterministicOpenSalt(address(beacon), data, salt);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bytes4[] memory selectors = TestCloneableCallRecorder(proxy).selectors();
        assertEq(selectors.length, 1);
        assertEq(selectors[0], TestCloneableCallRecorder.initialize.selector);
        assertEq(TestCloneableCallRecorder(proxy).sData(), data);
        assertEq(logs.length, 3);
        assertEq(logs[1].topics[0], keccak256("NewClone(address,address,address,bytes32,bytes)"));
        assertEq(logs[2].emitter, proxy);
        assertEq(logs[2].topics[0], TestCloneableCallRecorder.Initializing.selector);
    }

    /// A second deploy of the same inputs, from anyone, is
    /// `CloneAddressOccupied` and leaves the first proxy's state alone.
    function testBeaconProxyDeterministicOpenSaltSecondDeployReverts(bytes memory data, bytes32 salt, address bob)
        external
    {
        UpgradeableBeacon beacon = newBeacon();
        address proxy = iCloneFactory.beaconProxyDeterministicOpenSalt(address(beacon), data, salt);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(CloneAddressOccupied.selector, proxy));
        iCloneFactory.beaconProxyDeterministicOpenSalt(address(beacon), data, salt);
        assertEq(TestCloneable(proxy).sData(), data);
    }

    /// A codeless proxy address with a nonzero nonce fails the `CREATE2`
    /// itself: `CloneDeploymentFailed`.
    function testBeaconProxyDeterministicOpenSaltNonceOnlyCollisionReverts(bytes memory data, bytes32 salt) external {
        UpgradeableBeacon beacon = newBeacon();
        vm.setNonce(expectedAddress(address(beacon), data, salt), 1);
        vm.expectRevert(abi.encodeWithSelector(CloneDeploymentFailed.selector));
        iCloneFactory.beaconProxyDeterministicOpenSalt(address(beacon), data, salt);
    }

    /// A beacon that passes the factory's check but fails the `BeaconProxy`
    /// constructor's is `CloneDeploymentFailed`, the constructor's revert data
    /// not bubbled, and nothing lands at the predicted address.
    function testBeaconProxyConstructorRevertIsDeploymentFailed(bytes memory data, bytes32 salt) external {
        TestBeaconDivergent beacon = new TestBeaconDivergent(address(iCloneFactory), address(new TestCloneable()));
        address predicted = expectedAddress(address(beacon), data, salt);
        vm.expectRevert(abi.encodeWithSelector(CloneDeploymentFailed.selector));
        iCloneFactory.beaconProxyDeterministicOpenSalt(address(beacon), data, salt);
        assertEq(predicted.code.length, 0);
    }

    /// Prediction never calls the beacon.
    function testPredictBeaconProxyAddressOpenSaltNoBeaconCall(bytes memory data, bytes32 salt) external {
        UpgradeableBeacon beacon = newBeacon();
        vm.expectCall(address(beacon), "", 0);
        assertEq(
            iCloneFactory.predictBeaconProxyAddressOpenSalt(address(beacon), data, salt),
            expectedAddress(address(beacon), data, salt)
        );
    }

    /// An address holding ETH but no code deploys, and the proxy keeps the
    /// ETH.
    function testBeaconProxyDeterministicOpenSaltPrefunded(uint256 balance, bytes memory data, bytes32 salt) external {
        balance = bound(balance, 1, type(uint128).max);
        UpgradeableBeacon beacon = newBeacon();
        address predicted = iCloneFactory.predictBeaconProxyAddressOpenSalt(address(beacon), data, salt);
        vm.deal(predicted, balance);
        assertEq(iCloneFactory.beaconProxyDeterministicOpenSalt(address(beacon), data, salt), predicted);
        assertEq(predicted.balance, balance);
    }

    /// Deploys through a beacon serving `implementation`, expecting `expected`
    /// as the revert, and checks the address stays free.
    function checkReverts(address implementation, bytes memory data, bytes32 salt, bytes memory expected) internal {
        UpgradeableBeacon beacon = new UpgradeableBeacon(implementation, address(this));
        address predicted = iCloneFactory.predictBeaconProxyAddressOpenSalt(address(beacon), data, salt);
        vm.expectRevert(expected);
        iCloneFactory.beaconProxyDeterministicOpenSalt(address(beacon), data, salt);
        assertEq(predicted.code.length, 0);
    }

    /// `initialize` returning anything but the sentinel is
    /// `InitializationFailed`.
    function testBeaconProxyInitializeFailure(bytes32 notSuccess, bytes32 salt) external {
        vm.assume(notSuccess != ICLONEABLE_V2_SUCCESS);
        checkReverts(
            address(new TestCloneableFailure()),
            abi.encode(notSuccess),
            salt,
            abi.encodeWithSelector(InitializationFailed.selector)
        );
    }

    /// `initialize` reverting with data bubbles it verbatim.
    function testBeaconProxyInitializeRevertBubbles(bytes memory data, bytes32 salt) external {
        checkReverts(
            address(new TestCloneableRevert()),
            data,
            salt,
            abi.encodeWithSelector(TestCloneableRevertInitialize.selector, data)
        );
    }

    /// `initialize` reverting without data, returning nothing, or returning
    /// the sentinel with trailing bytes is `InitializationFailed`.
    function testBeaconProxyInitializeRawAnswers(bytes memory trailing, bytes32 salt) external {
        vm.assume(trailing.length > 0);
        address implementation = address(new TestCloneableRawAnswer());
        bytes memory failed = abi.encodeWithSelector(InitializationFailed.selector);
        checkReverts(implementation, abi.encode(true, ""), salt, failed);
        checkReverts(implementation, abi.encode(false, ""), salt, failed);
        checkReverts(implementation, abi.encode(false, abi.encodePacked(ICLONEABLE_V2_SUCCESS, trailing)), salt, failed);
        bytes memory success = abi.encodePacked(ICLONEABLE_V2_SUCCESS);
        checkReverts(implementation, abi.encode(true, success), salt, success);
    }

    /// A codeless beacon is `ZeroBeaconCodeSize`.
    function testBeaconProxyZeroBeaconCodeSize(address beacon, bytes memory data, bytes32 salt) external {
        vm.assume(beacon.code.length == 0);
        vm.expectRevert(abi.encodeWithSelector(ZeroBeaconCodeSize.selector));
        iCloneFactory.beaconProxyDeterministicOpenSalt(beacon, data, salt);
    }

    /// Deploys through a `TestBeaconRawAnswer` answering `(reverts, answer)`,
    /// expecting `expected` as the revert, and checks the address stays free.
    function checkBeaconReverts(bool reverts, bytes memory answer, bytes32 salt, bytes memory expected) internal {
        TestBeaconRawAnswer beacon = new TestBeaconRawAnswer();
        beacon.set(reverts, answer);
        address predicted = iCloneFactory.predictBeaconProxyAddressOpenSalt(address(beacon), "", salt);
        vm.expectRevert(expected);
        iCloneFactory.beaconProxyDeterministicOpenSalt(address(beacon), "", salt);
        assertEq(predicted.code.length, 0);
    }

    /// A beacon naming a codeless implementation is
    /// `ZeroImplementationCodeSize`.
    function testBeaconProxyZeroImplementationCodeSize(address implementation, bytes32 salt) external {
        vm.assume(implementation.code.length == 0);
        checkBeaconReverts(
            false, abi.encode(implementation), salt, abi.encodeWithSelector(ZeroImplementationCodeSize.selector)
        );
    }

    /// A beacon naming an EIP-7702 delegated account is
    /// `DelegatedImplementation`.
    function testBeaconProxyDelegatedImplementation(address delegate, bytes32 salt) external {
        address implementation = makeAddr("delegated-implementation");
        vm.etch(implementation, abi.encodePacked(hex"ef0100", delegate));
        checkBeaconReverts(
            false, abi.encode(implementation), salt, abi.encodeWithSelector(DelegatedImplementation.selector)
        );
    }

    /// A beacon whose `implementation()` reverts has its revert data bubbled
    /// verbatim, empty included.
    function testBeaconProxyBeaconRevertBubbles(bytes memory revertData, bytes32 salt) external {
        checkBeaconReverts(true, revertData, salt, revertData);
    }

    /// A beacon reverting with no data reverts the deploy with no data, rather
    /// than reading past the revert.
    function testBeaconProxyBeaconEmptyRevertBubbles(bytes32 salt) external {
        checkBeaconReverts(true, "", salt, "");
    }

    /// A beacon answering fewer than 32 bytes, or a word that is not an
    /// address, reverts with no data.
    function testBeaconProxyBeaconMalformedAnswer(uint256 length, uint256 highBits, bytes32 salt) external {
        length = bound(length, 0, 31);
        highBits = bound(highBits, 1, type(uint96).max);
        address implementation = address(new TestCloneable());
        bytes memory word = abi.encode(implementation);
        bytes memory short = new bytes(length);
        for (uint256 i = 0; i < length; ++i) {
            short[i] = word[i];
        }
        checkBeaconReverts(false, short, salt, "");
        checkBeaconReverts(false, abi.encode((highBits << 160) | uint256(uint160(implementation))), salt, "");
    }

    /// A beacon answering more than 32 bytes is read by its first word, as
    /// the proxy reads it.
    function testBeaconProxyBeaconLongAnswer(bytes memory trailing, bytes memory data, bytes32 salt) external {
        TestBeaconRawAnswer beacon = new TestBeaconRawAnswer();
        beacon.set(false, abi.encodePacked(abi.encode(address(new TestCloneable())), trailing));
        address proxy = iCloneFactory.beaconProxyDeterministicOpenSalt(address(beacon), data, salt);
        assertEq(TestCloneable(proxy).sData(), data);
    }

    /// THE TRUST POINT. `initialize` runs on whatever the beacon serves at
    /// deploy time, so the beacon owner retargeting before the deploy changes
    /// what initializes the pinned address without moving it; retargeting
    /// after changes what every proxy runs.
    function testBeaconOwnerIsTrustPoint(bytes32 salt) external {
        UpgradeableBeacon beacon = newBeacon();
        bytes memory data = abi.encode(bytes32(0));
        address predicted = iCloneFactory.predictBeaconProxyAddressOpenSalt(address(beacon), data, salt);

        beacon.upgradeTo(address(new TestCloneableFailure()));
        vm.expectRevert(abi.encodeWithSelector(InitializationFailed.selector));
        iCloneFactory.beaconProxyDeterministicOpenSalt(address(beacon), data, salt);
        assertEq(iCloneFactory.predictBeaconProxyAddressOpenSalt(address(beacon), data, salt), predicted);

        beacon.upgradeTo(address(new TestCloneable()));
        address proxy = iCloneFactory.beaconProxyDeterministicOpenSalt(address(beacon), data, salt);
        assertEq(proxy, predicted);
        assertEq(TestCloneable(proxy).sData(), data);

        vm.expectRevert(abi.encodeWithSelector(TestCloneableAlreadyInitialized.selector));
        TestCloneable(proxy).initialize(data);
        beacon.upgradeTo(address(new TestCloneableFailure()));
        assertEq(TestCloneableFailure(proxy).initialize(data), bytes32(0));
    }

    /// Empty data deploys where predicted.
    function testBeaconProxyEmptyData(bytes32 salt) external {
        UpgradeableBeacon beacon = newBeacon();
        address proxy = iCloneFactory.beaconProxyDeterministicOpenSalt(address(beacon), "", salt);
        assertEq(proxy, expectedAddress(address(beacon), "", salt));
        assertEq(TestCloneable(proxy).sData(), "");
    }

    /// The factory's check and the proxy both call the beacon with exactly
    /// the 4-byte `implementation()` calldata.
    function testBeaconProxyStrictBeaconCalldata(bytes memory data, bytes32 salt) external {
        TestBeaconStrictCalldata beacon = new TestBeaconStrictCalldata(address(new TestCloneable()));
        address proxy = iCloneFactory.beaconProxyDeterministicOpenSalt(address(beacon), data, salt);
        assertEq(proxy, expectedAddress(address(beacon), data, salt));
        assertEq(TestCloneable(proxy).sData(), data);
    }

    /// The returned address is the one `CREATE2` deployed: the OZ-derived
    /// address, the emitter of the proxy's constructor event, holding the
    /// `BeaconProxy` runtime code.
    function testBeaconProxyReturnsDeployedAddress(bytes memory data, bytes32 salt) external {
        UpgradeableBeacon beacon = newBeacon();
        address expected = expectedAddress(address(beacon), data, salt);
        vm.recordLogs();
        address proxy = iCloneFactory.beaconProxyDeterministicOpenSalt(address(beacon), data, salt);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(proxy, expected);
        assertEq(logs[0].emitter, expected);
        assertEq(expected.code, address(new BeaconProxy(address(beacon), "")).code);
    }
}
