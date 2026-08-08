# rain.factory

Docs at https://rainprotocol.github.io/rain.factory

## Concrete implementations

`CloneFactory` implements `ICloneableFactoryV4` allowing any
compatible `ICloneableV2` contract to be cloned as an EIP1167 proxy and
initialized.

It offers two deterministic (`CREATE2`) entry points that differ only in how the
salt is derived:

- `cloneDeterministic` namespaces the caller-supplied salt by `msg.sender`, so
  nobody else can reach the caller's address.
- `cloneDeterministicOpenSalt` uses the caller-supplied salt verbatim, so the
  address is a function of `(implementation, salt)` and the factory alone —
  every account reaches the same address, but so can anyone. That also makes it
  the same address across chains, but only where both the factory and the
  implementation are themselves at the same address on each chain: `CREATE2`
  hashes the factory, and the EIP1167 creation code it hashes contains the
  implementation. It is ONLY safe for implementations whose `initialize` takes
  no caller-controlled authority; read the NatSpec on
  `ICloneableFactoryV4.cloneDeterministicOpenSalt` before using it.

## Interfaces

Contains interfaces for working with Rain factories.

Rain tooling/ecosystem generally tries to be as agnostic and low friction as
possible on the implementation side.

The ideal would be that "any" contract can call an interpreter and magically be
supported but there's a lot that can go wrong, for example:

- Contracts can self destruct or even [redeployed with new bytecode](https://0age.medium.com/the-promise-and-the-peril-of-metamorphic-contracts-9eb8b8413c5e)
- Proxies can point to new implementations and "upgrade"
- Discoverability of ABIs and other metadata subject to indexer limitations

Falling short of the ideal, we want to support:

- Ability to (dis)trust contracts at the bytecode level NOT the human/key level
- Support existing patterns such as EIP1167 for clones, etc.
- Avoid introducing Rain-isms as much as possible

The onchain tooling for analysis is found at https://github.com/rainprotocol/rain.extrospection

The current interfaces in this repository are for

- `ICloneableFactoryV4` that is expected to clone proxies from a reference
  implementation, deterministically, with or without the deployer in the address
  derivation. It extends `ICloneableFactoryV3` (deterministic-only, deployer
  always in the derivation), which is still published for consumers pinned to it
- `ICloneableFactoryV2` that clones via a nonce-dependent `CREATE`. Superseded
  for `CloneFactory`, still published for other consumers
- A small interface `ICloneableV2` designed for cloneable proxy contracts to
  expose an `initialize` function that the factory can call to act like a
  constructor

### Legacy

#### `ICloneableV1`

This version of `ICloneable` did not have any explicit return value on success of
initialize. It is possible for contracts that do not implement `ICloneableV1` to
silently fail to initialize when cloned by an `ICloneableFactoryV1`.

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