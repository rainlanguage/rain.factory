# rain.factory

This repo is the **library** half of the library/deploy split: the `ICloneable*`
interface surface and the `LibICloneableFactoryV5` library that implements it.
It publishes to Soldeer as `rain-factory`.

Releases from before the split carried the concrete `CloneFactory` and its
deploy pins, and the reports under `audit/protofire/` audit those, not the
current tree.

The release that adds `ICloneableFactoryV5` moves `ICloneableFactoryV4` and its
domain-tag constants from `src/interface/ICloneableFactoryV4.sol` to
`src/interface/deprecated/ICloneableFactoryV4.sol`. Consumers importing the old
path, such as `rain.factory.deploy`, rewrite the import when they bump.

## Install

```sh
forge soldeer install rain-factory~<version>
```

## Development

`dependencies/` and `remappings.txt` are gitignored, so fetch them after cloning
or when `soldeer.lock` changes:

```sh
nix develop -c forge soldeer install
nix develop -c forge build
nix develop -c forge test
```

## Concrete implementations

`CloneFactory` — the concrete that implements these interfaces — lives in
[`rain.factory.deploy`](https://github.com/rainlanguage/rain.factory.deploy),
together with its deployed address + codehash pins, its frozen per-release
deploy-pin snapshots and its deploy script. That repo publishes as
`rain-factory-deploy`.

Depend on `rain-factory` for the interfaces and the library; on
`rain-factory-deploy` for a live `CloneFactory`'s address or codehash. A live
`CloneFactory` embeds the `rain-factory` revision that repo pins.

## Library

`src/lib/LibICloneableFactoryV5.sol` is the executable form of
`ICloneableFactoryV5` as internal library logic. The two clone `CREATE2` salt
derivations the interfaces pin to exact bytes — the `msg.sender`-namespaced one
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

The same library holds the beacon-proxy derivation: its effective salt, the
OpenZeppelin `BeaconProxy` creation code, the beacon guard and the two entry
points, on the shared `deployChild` and `initializeChild`, emitting
`NewBeaconProxy` in place of `NewClone`. The creation code is the
`BEACON_PROXY_CREATION_CODE` constant in `src/generated/BeaconProxy.sol`, which
`script/Build.sol` writes and CI regenerates and diffs; a test pins it to
`type(BeaconProxy).creationCode`.

## Interfaces

Contains interfaces for working with Rain factories.

The current interfaces in this repository are for

- `ICloneableFactoryV5`, the current factory interface. Extends
  `ICloneableFactoryV4` and adds `beaconProxyDeterministicOpenSalt` +
  `predictBeaconProxyAddressOpenSalt`: a `CREATE2` OpenZeppelin `BeaconProxy`,
  initialized atomically, whose address commits to the beacon and the
  initialization data and nothing about the caller, behind a third domain tag.
  The address does not commit to the implementation the beacon serves, so the
  beacon owner is the trust point for the proxy's behaviour and initial state.
  Each deploy emits `NewBeaconProxy`, not `NewClone`.
- A small interface `ICloneableV2` designed for cloneable proxy contracts to
  expose an `initialize` function that the factory can call to act like a
  constructor. `initialize` MUST return `ICLONEABLE_V2_SUCCESS`; an
  `ICloneableFactoryV5` reverts the deploy if it does not

### Legacy

Every interface that is not the newest version of itself is deprecated and lives
in `src/interface/deprecated/`. They are still published for consumers pinned to
them. New work uses the current interfaces above.

#### `ICloneableFactoryV4`

Extends `ICloneableFactoryV3` — nothing was dropped this time, so it inherits
rather than restates — and adds a second deterministic derivation,
`cloneDeterministicOpenSalt` + `predictDeterministicAddressOpenSalt`, whose
`CREATE2` salt hashes the caller-supplied salt together with the initialization
data and nothing about the caller. What each derivation's address commits to,
what the open-salt address does not fix, and the MUSTs that places on
implementations are the NatSpec on `ICloneableFactoryV4` and
`cloneDeterministicOpenSalt`. Superseded by `ICloneableFactoryV5`, which extends
it, so both clone derivations, their domain tags and their spec are still
declared in `ICloneableFactoryV4`.

#### `ICloneableFactoryV3`

Deterministic-only (`cloneDeterministic` + `predictDeterministicAddress`,
CREATE2 with the salt namespaced by `msg.sender`). Superseded by
`ICloneableFactoryV5`, which extends it through `ICloneableFactoryV4`, so the
namespaced pair and `NewClone` are still declared in `ICloneableFactoryV3` and
inherited from there. Standalone rather than extending `ICloneableFactoryV2`,
because the non-deterministic `clone()` was intentionally dropped.

#### `ICloneableFactoryV2`

Clones proxies from a reference implementation with a non-deterministic
`clone()`. Superseded by `ICloneableFactoryV5`.

#### `ICloneableFactoryV1`

The same non-deterministic `clone()` against `ICloneableV1` rather than
`ICloneableV2`. Superseded by `ICloneableFactoryV5`.

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
