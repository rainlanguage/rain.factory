import {
  afterEach,
  assert,
  clearStore,
  describe,
  newMockEvent,
  test,
} from "matchstick-as";
import { Address, Bytes, ethereum } from "@graphprotocol/graph-ts";
import {
  NewClone as NewCloneV5,
  NewBeaconProxy as NewBeaconProxyV5,
} from "../generated/CloneFactoryV5/CloneFactoryV5";
import { NewRegistryBeaconProxy as NewRegistryBeaconProxyV6 } from "../generated/CloneFactoryV6/CloneFactoryV6";
import {
  NewClone as NewCloneV7,
  NewRegistryBeaconProxy as NewRegistryBeaconProxyV7,
} from "../generated/CloneFactoryV7/CloneFactoryV7";
import {
  handleCloneFactoryV5NewBeaconProxy,
  handleCloneFactoryV5NewClone,
  handleCloneFactoryV6NewRegistryBeaconProxy,
  handleCloneFactoryV7NewClone,
  handleCloneFactoryV7NewRegistryBeaconProxy,
} from "../src/cloneFactory";

const FACTORY = Address.fromString("0xda3f8841b3f6640ab623050fbba9badc0ccd11b0");
const SENDER = Address.fromString("0x00000000000000000000000000000000000000ca");
const A = Address.fromString("0x00000000000000000000000000000000000000a1");
const B = Address.fromString("0x00000000000000000000000000000000000000b2");
const C = Address.fromString("0x00000000000000000000000000000000000000c3");
const D = Address.fromString("0x00000000000000000000000000000000000000d4");
const SALT = Bytes.fromHexString(
  "0x0000000000000000000000000000000000000000000000000000000000000011",
);
const NAME = Bytes.fromHexString(
  "0x0000000000000000000000000000000000000000000000000000000000000022",
);
const DATA = Bytes.fromHexString("0xdeadbeef");

function param(name: string, value: ethereum.Value): ethereum.EventParam {
  return new ethereum.EventParam(name, value);
}

function addr(a: Address): ethereum.Value {
  return ethereum.Value.fromAddress(a);
}

function mock(params: ethereum.EventParam[]): ethereum.Event {
  let event = newMockEvent();
  event.address = FACTORY;
  event.parameters = params;
  return event;
}

function id(event: ethereum.Event): string {
  return event.transaction.hash.concatI32(event.logIndex.toI32()).toHexString();
}

function cloneEvent(): ethereum.Event {
  return mock([
    param("sender", addr(SENDER)),
    param("implementation", addr(A)),
    param("clone", addr(B)),
    param("salt", ethereum.Value.fromFixedBytes(SALT)),
    param("data", ethereum.Value.fromBytes(DATA)),
  ]);
}

function registryEvent(): ethereum.Event {
  return mock([
    param("sender", addr(SENDER)),
    param("registry", addr(A)),
    param("authority", addr(B)),
    param("beaconName", ethereum.Value.fromFixedBytes(NAME)),
    param("beacon", addr(C)),
    param("proxy", addr(D)),
    param("salt", ethereum.Value.fromFixedBytes(SALT)),
    param("data", ethereum.Value.fromBytes(DATA)),
  ]);
}

describe("clone factory events", () => {
  afterEach(() => {
    clearStore();
  });

  test("V5 NewClone records the clone against a V5 factory", () => {
    let event = cloneEvent();
    handleCloneFactoryV5NewClone(changetype<NewCloneV5>(event));
    let key = id(event);
    assert.fieldEquals("NewClone", key, "factory", FACTORY.toHexString());
    assert.fieldEquals("NewClone", key, "sender", SENDER.toHexString());
    assert.fieldEquals("NewClone", key, "implementation", A.toHexString());
    assert.fieldEquals("NewClone", key, "clone", B.toHexString());
    assert.fieldEquals("NewClone", key, "salt", SALT.toHexString());
    assert.fieldEquals("NewClone", key, "data", DATA.toHexString());
    assert.fieldEquals("Factory", FACTORY.toHexString(), "version", "V5");
  });

  test("V5 NewBeaconProxy records beacon and proxy", () => {
    let event = mock([
      param("sender", addr(SENDER)),
      param("beacon", addr(C)),
      param("proxy", addr(D)),
      param("salt", ethereum.Value.fromFixedBytes(SALT)),
      param("data", ethereum.Value.fromBytes(DATA)),
    ]);
    handleCloneFactoryV5NewBeaconProxy(changetype<NewBeaconProxyV5>(event));
    let key = id(event);
    assert.fieldEquals("NewBeaconProxy", key, "beacon", C.toHexString());
    assert.fieldEquals("NewBeaconProxy", key, "proxy", D.toHexString());
    assert.fieldEquals("NewBeaconProxy", key, "salt", SALT.toHexString());
    assert.fieldEquals("NewBeaconProxy", key, "data", DATA.toHexString());
  });

  test("V6 NewRegistryBeaconProxy records every field", () => {
    let event = registryEvent();
    handleCloneFactoryV6NewRegistryBeaconProxy(
      changetype<NewRegistryBeaconProxyV6>(event),
    );
    let key = id(event);
    let e = "NewRegistryBeaconProxy";
    assert.fieldEquals(e, key, "sender", SENDER.toHexString());
    assert.fieldEquals(e, key, "registry", A.toHexString());
    assert.fieldEquals(e, key, "authority", B.toHexString());
    assert.fieldEquals(e, key, "beaconName", NAME.toHexString());
    assert.fieldEquals(e, key, "beacon", C.toHexString());
    assert.fieldEquals(e, key, "proxy", D.toHexString());
    assert.fieldEquals(e, key, "salt", SALT.toHexString());
    assert.fieldEquals(e, key, "data", DATA.toHexString());
    assert.fieldEquals("Factory", FACTORY.toHexString(), "version", "V6");
  });

  test("V7 NewRegistryBeaconProxy tags the factory V7", () => {
    handleCloneFactoryV7NewRegistryBeaconProxy(
      changetype<NewRegistryBeaconProxyV7>(registryEvent()),
    );
    assert.fieldEquals("Factory", FACTORY.toHexString(), "version", "V7");
  });

  test("the first event fixes a factory's version", () => {
    handleCloneFactoryV7NewClone(changetype<NewCloneV7>(cloneEvent()));
    handleCloneFactoryV5NewClone(changetype<NewCloneV5>(cloneEvent()));
    assert.entityCount("Factory", 1);
    assert.fieldEquals("Factory", FACTORY.toHexString(), "version", "V7");
  });
});
