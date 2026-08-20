# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

rain.factory is a Solidity **library** repo for EIP1167 minimal proxy (clone)
factories in the Rain ecosystem: the `ICloneable*` interface surface and the
`LibICloneableFactoryV4` salt-derivation library. It is the library half of the
library/deploy split (rainlanguage/rain.factory#46) — no concrete contract, no
deploy pins, no deploy script.

The concrete `CloneFactory` that implements these interfaces, its deployed
address + codehash pins (`LibCloneFactoryDeploy`), the frozen
`src/generated/<tag>/` deploy-pin snapshots and `script/Deploy.sol` all live in
[`rain.factory.deploy`](https://github.com/rainlanguage/rain.factory.deploy) and
publish as the `rain-factory-deploy` Soldeer package. Consumers that need only
the interfaces depend on `rain-factory`; consumers that need the deployed
address/codehash pins depend on `rain-factory-deploy`.

License: LicenseRef-DCL-1.0 (DecentraLicense). All source files must include
SPDX headers.

## Build & Test Commands

Nix + Foundry. Enter the shell with `nix develop`, then run rainix tasks:
`rainix-sol-static` (Slither), `rainix-sol-legal` (REUSE), `rainix-sol-prelude`
(deps, run first), `rainix-sol-test`, and `forge build` directly.
`rainix-sol-test` runs the derivation library's tests, which live here; the
interfaces have no behaviour to test.

## Architecture

- `src/interface/ICloneableV2.sol` — Interface for cloneable contracts.
  `initialize(bytes)` must return `ICLONEABLE_V2_SUCCESS` (keccak256 hash) on
  success.
- `src/interface/ICloneableFactoryV2.sol` — Legacy factory interface: the
  nonce-dependent `clone(address, bytes)` and `NewClone` event. The concrete
  factory in rain.factory.deploy implements `ICloneableFactoryV4`, not this;
  still published for other consumers.
- `src/interface/ICloneableFactoryV3.sol` — Deterministic-only factory
  interface: `cloneDeterministic(address, bytes, bytes32)` +
  `predictDeterministicAddress(address, bytes32, address)` (CREATE2, salt
  namespaced by `msg.sender`) and its own `NewClone` event. Standalone — does
  NOT extend `ICloneableFactoryV2` and has no non-deterministic `clone()`. Still
  published for consumers pinned to it.
- `src/interface/ICloneableFactoryV4.sol` — Current factory interface. Extends
  `ICloneableFactoryV3` and defines the open-salt pair
  `cloneDeterministicOpenSalt` / `predictDeterministicAddressOpenSalt`. Both
  derivations are pinned to exact bytes, each `keccak256`-ing a 96-byte preimage
  led by a distinct string-derived domain tag, so the two images are disjoint by
  construction. The full spec is the NatSpec on the interface.
- `src/lib/LibICloneableFactoryV4.sol` — Pure `internal` library, the executable
  form of the two `ICloneableFactoryV4` salt derivations; imports the domain
  tags from the interface. Tested under `test/src/lib/`.
- `src/interface/deprecated/` — Legacy interfaces (`ICloneableV1`,
  `ICloneableFactoryV1`, `IFactory`). Do not use for new work.

No `src/` file imports from outside this repo — intra-repo inheritance is
allowed (`ICloneableFactoryV4` extends `ICloneableFactoryV3`), which is what
makes this half a standalone publish.

## Solidity Conventions

- Solidity version: the interfaces and the derivation library float `^`
  (`^0.8.18`) so downstream soldeer consumers on a different `0.8.x` can still
  compile them; the tests here pin `=0.8.25`, as do the concrete contracts and
  scripts in rain.factory.deploy.
- Compiler (`foundry.toml`): Cancun EVM, optimizer at 100,000 runs, no CBOR
  metadata (`cbor_metadata = false`, `bytecode_hash = "none"`).
- Dependencies are managed with Soldeer (`[dependencies]` in `foundry.toml` +
  `soldeer.lock`, vendored under `dependencies/`). The only external entry is
  forge-std. `@openzeppelin-contracts`, `rain-extrospection`, `rain-deploy` and
  `rain-sol-codegen` belong to the deploy half and must not be added here:
  adding one means concrete code has landed in a library repo.
