# rain.factory

Docs at https://rainprotocol.github.io/rain.factory

## Concrete implementations

`CloneFactory` implements `ICloneableFactoryV2` allowing any
compatible `ICloneableV2` contract to be cloned as an EIP1167 proxy and
initialized.

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

- `ICloneableFactoryV2` that is expected to clone proxies from a reference
  implementation
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