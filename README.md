# rain.factory

Docs at https://rainprotocol.github.io/rain.factory

This repo is the **library** half of the library/deploy split
([#46](https://github.com/rainlanguage/rain.factory/issues/46)): the
`ICloneable*` interface surface and the `LibICloneableFactoryV4` salt-derivation
library. It publishes to Soldeer as `rain-factory`.

## Concrete implementations

`CloneFactory` — the concrete that implements these interfaces, letting any
compatible `ICloneableV2` contract be cloned as an EIP1167 proxy and initialized
— lives in
[`rain.factory.deploy`](https://github.com/rainlanguage/rain.factory.deploy),
together with its deployed address + codehash pins, its frozen per-release
deploy-pin snapshots and its deploy script. That repo publishes as
`rain-factory-deploy`.

Depend on `rain-factory` if you need only the interfaces. Depend on
`rain-factory-deploy` if you need the deployed address or codehash of a live
`CloneFactory`.

## Derivation library

`src/lib/LibICloneableFactoryV4.sol` is the executable form of the two `CREATE2`
salt derivations `ICloneableFactoryV4` pins to exact bytes — the
`msg.sender`-namespaced one and the open-salt one — as pure `internal`
functions. It imports the domain tags from the interface, so the tags have a
single source of truth, and its tests recompute both formulas independently to
pin them to the interface's spec byte for byte. A factory, an indexer or a
consumer predicting a clone address computes the salt from one place. The tests
live here under `test/src/lib/`.

## Interfaces

Contains interfaces for working with Rain factories.

Rain tooling/ecosystem generally tries to be as agnostic and low friction as
possible on the implementation side.

The ideal would be that "any" contract can call an interpreter and magically be
supported but there's a lot that can go wrong, for example:

- Contracts can self-destruct or even be
  [redeployed with new bytecode](https://0age.medium.com/the-promise-and-the-peril-of-metamorphic-contracts-9eb8b8413c5e)
- Proxies can point to new implementations and "upgrade"
- Discoverability of ABIs and other metadata subject to indexer limitations

Falling short of the ideal, we want to support:

- Ability to (dis)trust contracts at the bytecode level NOT the human/key level
- Support existing patterns such as EIP1167 for clones, etc.
- Avoid introducing Rain-isms as much as possible

The onchain tooling for analysis is found at
https://github.com/rainprotocol/rain.extrospection

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
- `ICloneableFactoryV3`, deterministic-only (`cloneDeterministic` +
  `predictDeterministicAddress`, CREATE2 with the salt namespaced by
  `msg.sender`). Superseded by `ICloneableFactoryV4`, still published for
  consumers pinned to it. Standalone rather than extending
  `ICloneableFactoryV2`, because the non-deterministic `clone()` was
  intentionally dropped
- `ICloneableFactoryV2` that is expected to clone proxies from a reference
  implementation. Superseded by `ICloneableFactoryV3` for the concrete factory,
  still published for other consumers
- A small interface `ICloneableV2` designed for cloneable proxy contracts to
  expose an `initialize` function that the factory can call to act like a
  constructor

### Legacy

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
