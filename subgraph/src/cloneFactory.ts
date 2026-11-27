import { Address, ethereum } from "@graphprotocol/graph-ts";
import {
  NewClone as NewCloneV5,
  NewBeaconProxy as NewBeaconProxyV5,
} from "../generated/CloneFactoryV5/CloneFactoryV5";
import {
  NewClone as NewCloneV6,
  NewBeaconProxy as NewBeaconProxyV6,
  NewRegistryBeaconProxy as NewRegistryBeaconProxyV6,
} from "../generated/CloneFactoryV6/CloneFactoryV6";
import {
  NewClone as NewCloneV7,
  NewBeaconProxy as NewBeaconProxyV7,
  NewRegistryBeaconProxy as NewRegistryBeaconProxyV7,
} from "../generated/CloneFactoryV7/CloneFactoryV7";
import {
  Factory,
  NewBeaconProxy,
  NewClone,
  NewRegistryBeaconProxy,
} from "../generated/schema";

function factory(address: Address, version: string): Factory {
  let entity = Factory.load(address);
  if (entity == null) {
    entity = new Factory(address);
    entity.version = version;
    entity.save();
  }
  return entity;
}

function saveNewClone(
  event: ethereum.Event,
  version: string,
  sender: Address,
  implementation: Address,
  clone: Address,
  salt: ethereum.Value,
  data: ethereum.Value,
): void {
  let entity = new NewClone(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  );
  entity.factory = factory(event.address, version).id;
  entity.sender = sender;
  entity.implementation = implementation;
  entity.clone = clone;
  entity.salt = salt.toBytes();
  entity.data = data.toBytes();
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.save();
}

function saveNewBeaconProxy(
  event: ethereum.Event,
  version: string,
  sender: Address,
  beacon: Address,
  proxy: Address,
  salt: ethereum.Value,
  data: ethereum.Value,
): void {
  let entity = new NewBeaconProxy(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  );
  entity.factory = factory(event.address, version).id;
  entity.sender = sender;
  entity.beacon = beacon;
  entity.proxy = proxy;
  entity.salt = salt.toBytes();
  entity.data = data.toBytes();
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.save();
}

function saveNewRegistryBeaconProxy(
  event: ethereum.Event,
  version: string,
): void {
  let p = event.parameters;
  let entity = new NewRegistryBeaconProxy(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  );
  entity.factory = factory(event.address, version).id;
  entity.sender = p[0].value.toAddress();
  entity.registry = p[1].value.toAddress();
  entity.authority = p[2].value.toAddress();
  entity.beaconName = p[3].value.toBytes();
  entity.beacon = p[4].value.toAddress();
  entity.proxy = p[5].value.toAddress();
  entity.salt = p[6].value.toBytes();
  entity.data = p[7].value.toBytes();
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.save();
}

function cloneEvent(event: ethereum.Event, version: string): void {
  let p = event.parameters;
  saveNewClone(
    event,
    version,
    p[0].value.toAddress(),
    p[1].value.toAddress(),
    p[2].value.toAddress(),
    p[3].value,
    p[4].value,
  );
}

function beaconProxyEvent(event: ethereum.Event, version: string): void {
  let p = event.parameters;
  saveNewBeaconProxy(
    event,
    version,
    p[0].value.toAddress(),
    p[1].value.toAddress(),
    p[2].value.toAddress(),
    p[3].value,
    p[4].value,
  );
}

export function handleCloneFactoryV5NewClone(event: NewCloneV5): void {
  cloneEvent(event, "V5");
}

export function handleCloneFactoryV5NewBeaconProxy(
  event: NewBeaconProxyV5,
): void {
  beaconProxyEvent(event, "V5");
}

export function handleCloneFactoryV6NewClone(event: NewCloneV6): void {
  cloneEvent(event, "V6");
}

export function handleCloneFactoryV6NewBeaconProxy(
  event: NewBeaconProxyV6,
): void {
  beaconProxyEvent(event, "V6");
}

export function handleCloneFactoryV6NewRegistryBeaconProxy(
  event: NewRegistryBeaconProxyV6,
): void {
  saveNewRegistryBeaconProxy(event, "V6");
}

export function handleCloneFactoryV7NewClone(event: NewCloneV7): void {
  cloneEvent(event, "V7");
}

export function handleCloneFactoryV7NewBeaconProxy(
  event: NewBeaconProxyV7,
): void {
  beaconProxyEvent(event, "V7");
}

export function handleCloneFactoryV7NewRegistryBeaconProxy(
  event: NewRegistryBeaconProxyV7,
): void {
  saveNewRegistryBeaconProxy(event, "V7");
}
