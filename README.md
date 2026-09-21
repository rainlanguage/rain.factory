# rain.factory

Docs at https://rainprotocol.github.io/rain.factory

This repo is the **library** half of the library/deploy split
([#46](https://github.com/rainlanguage/rain.factory/issues/46)): the
`ICloneable*` interface surface and the `LibICloneableFactoryV4` library that
implements it. It publishes to Soldeer as `rain-factory`.

Soldeer `rain-factory` 0.1.5 and earlier are the pre-split package, carrying the
concrete `CloneFactory` and its deploy pins; 0.1.6 dropped them. The `v0.1.0`,
`v0.1.1`, `sol-v0.1.2`, `sol-v0.1.3` and `sol-v0.1.5` tags here are those
pre-split releases, and the reports under `audit/protofire/` audit them, not the
current tree.

## Concrete implementations

`CloneFactory` — the concrete that implements these interfaces, letting any
compatible `ICloneableV2` contract be cloned as an EIP1167 proxy and initialized
— lives in
[`rain.factory.deploy`](https://github.com/rainlanguage/rain.factory.deploy),
together with its deployed address + codehash pins, its frozen per-release
deploy-pin snapshots and its deploy script. That repo publishes as
`rain-factory-deploy`.

Depend on `rain-factory` if you need the interfaces or the library. Depend on
`rain-factory-deploy` if you need the deployed address or codehash of a live
`CloneFactory`.

## Library

`src/lib/LibICloneableFactoryV4.sol` is the executable form of
`ICloneableFactoryV4` as internal library logic. The two `CREATE2` salt
derivations the interface pins to exact bytes — the `msg.sender`-namespaced one
and the open-salt one — are pure functions that import the domain tags from the
interface, so the tags have a single source of truth and a factory, an indexer
or a consumer predicting a clone address computes the salt from one place. On
top of them sit the implementation-code guard, the EIP1167 creation code and its
CREATE2 address prediction (constructed from the standard's own bytes, so the
published `src/` depends on no external cloning code), and the atomic
clone-initialize-verify flow with its typed errors and the `NewClone` event.
`msg.sender` and `address(this)` are read inside the library, so a concrete
factory is one delegation per entry point. The tests live here under
`test/src/lib/`: they recompute both salt formulas independently to pin them to
the interface's spec byte for byte, and pin the EIP1167 construction against
OpenZeppelin `Clones` as a foreign implementation of the same standard.

## Interfaces

Contains interfaces for working with Rain factories.

The current interfaces in this repository are for

- `ICloneableFactoryV4`, the current factory interface. Extends
  `ICloneableFactoryV3` — nothing was dropped this time, so it inherits rather
  than restates — and adds a second deterministic derivation,
  `cloneDeterministicOpenSalt` + `predictDeterministicAddressOpenSalt`, whose
  `CREATE2` salt hashes the caller-supplied salt together with the
  initialization data and nothing about the caller. The two derivations differ
  in what the clone's address commits to, and neither dominates: the V3 pair
  namespaces the salt by `msg.sender`, so the address commits to WHO deployed
  and not to WHAT — nobody else can reach the caller's address, but the
  deploying account is baked into it forever and the deployer alone decides the
  initial state. The open-salt pair commits to WHAT and not to WHO — every
  account reaches the same address, and so can anyone, but everyone who reaches
  it deploys the same contract initialized with the same bytes, because varying
  either input lands somewhere else. Its cost is that the address is not
  knowable until the data is final. The residual the address cannot fix —
  implementations MUST NOT read `tx.origin` — and the address-registry pairing
  it is intended for are spelled out in the NatSpec on
  `ICloneableFactoryV4.cloneDeterministicOpenSalt`
- A small interface `ICloneableV2` designed for cloneable proxy contracts to
  expose an `initialize` function that the factory can call to act like a
  constructor

### Legacy

Every interface that is not the newest version of itself is deprecated and lives
in `src/interface/deprecated/`. They are still published for consumers pinned to
them. New work uses the current interfaces above.

#### `ICloneableFactoryV3`

Deterministic-only (`cloneDeterministic` + `predictDeterministicAddress`,
CREATE2 with the salt namespaced by `msg.sender`). Superseded by
`ICloneableFactoryV4`, which extends it, so the namespaced pair and `NewClone`
are still declared in `ICloneableFactoryV3` and inherited from there. Standalone
rather than extending `ICloneableFactoryV2`, because the non-deterministic
`clone()` was intentionally dropped.

#### `ICloneableFactoryV2`

Clones proxies from a reference implementation with a non-deterministic
`clone()`. Superseded by `ICloneableFactoryV4`.

#### `ICloneableV1`

This version of `ICloneable` did not have any explicit return value on success
of initialize. It is possible for contracts that do not implement `ICloneableV1`
to silently fail to initialize when cloned by an `ICloneableFactoryV1`.

Newer versions of the interface include an explicit success value and check.

#### `IFactory`

The legacy factory model was much more restricted in that each factory
implementation was 1:1 with the thing it was deploying. If you needed a new
contract you also needed to implement a new factory.

This was suboptimal for several reasons:

- Increased surface area for things to go wrong
- More Rain-isms creeping in
- Redundant work to maintain a growing list of factories

The legacy interface is available as `IFactory` but it is NOT RECOMMENDED for
new contracts.
