# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

rain.factory is a Solidity **library** repo for EIP1167 minimal proxy (clone)
factories in the Rain ecosystem: the `ICloneable*` interface surface and the
`LibICloneableFactoryV4` and `LibICloneableFactoryV5` libraries that implement
it. It is the library half of the library/deploy split
(rainlanguage/rain.factory#46) — no concrete contract, no deploy pins, no deploy
script.

The concrete `CloneFactory`, its deployed address + codehash pins
(`LibCloneFactoryDeploy`), the frozen deploy-pin snapshots and
`script/Deploy.sol` all live in
[`rain.factory.deploy`](https://github.com/rainlanguage/rain.factory.deploy),
publishing as `rain-factory-deploy`. Depend on `rain-factory` for the interfaces
and library; on `rain-factory-deploy` for the deployed pins, which embed the
`rain-factory` revision that repo pins.

License: LicenseRef-DCL-1.0 (DecentraLicense). All source files must include
SPDX headers.

## Build & Test Commands

Nix + Foundry. Enter the shell with `nix develop`, then run rainix tasks:
`rainix-sol-static` (Slither), `rainix-sol-legal` (REUSE), `rainix-sol-prelude`
(deps, run first), `rainix-sol-test`, and `forge build` / `forge test` directly.
Tests exercise the libraries through `TestCloneFactory`, a pure-delegation
concrete, with OZ `Clones` as foreign EIP1167 oracle and OZ `BeaconProxy` as
behavioural oracle for the beacon proxy.

## Architecture

- `src/interface/ICloneableV2.sol` — Cloneable contracts. `initialize(bytes)`
  must return `ICLONEABLE_V2_SUCCESS` on success.
- `src/interface/ICloneableFactoryV5.sol` — Current factory interface. Extends
  the deprecated `ICloneableFactoryV4` and defines the open-salt beacon-proxy
  pair `beaconProxyDeterministicOpenSalt` / `predictBeaconProxyAddressOpenSalt`:
  a minimal ERC-1967 beacon proxy whose address commits to the beacon and the
  init data, behind a third domain tag. Its NatSpec names the beacon owner as
  the trust point.
- `src/interface/deprecated/ICloneableFactoryV4.sol` — Extends
  `ICloneableFactoryV3` and defines the open-salt pair
  `cloneDeterministicOpenSalt` / `predictDeterministicAddressOpenSalt`. Both
  derivations are pinned to exact bytes, each `keccak256`-ing a 96-byte preimage
  led by a distinct string-derived domain tag, so the two images are disjoint by
  construction. The full spec is the NatSpec on the interface.
- `src/lib/LibICloneableFactoryV4.sol` — The V4 factory as internal library
  logic: both effective-salt derivations (pure, importing the domain tags from
  the interface), the implementation-code guard, EIP1167 creation code + CREATE2
  prediction (no external cloning dependency), and the atomic
  clone-initialize-verify flow with the typed errors and `NewClone`.
  `msg.sender` and `address(this)` are read inside the library.
- `src/lib/LibICloneableFactoryV5.sol` — The beacon-proxy pair: its effective
  salt, the proxy creation code, the beacon guard, and the entry points, reusing
  `LibICloneableFactoryV4`'s deploy-and-initialize tail.
- `src/interface/deprecated/` — Every interface that is not the newest version
  of itself (`ICloneableV1`, `IFactory`, `ICloneableFactoryV1`–`V4`). Still
  published for consumers pinned to them; do not use for new work. When a new
  version lands, the one it supersedes moves here.

No `src/` file imports from outside this repo — intra-repo inheritance is
allowed (`ICloneableFactoryV5` extends `ICloneableFactoryV4`), which is what
makes this half a standalone publish.

## Solidity Conventions

- Versions: interfaces float `^0.8.18` so downstream soldeer consumers on a
  different `0.8.x` still compile them; the library floats `^0.8.25`; tests pin
  `=0.8.25`, as do the concretes and scripts in rain.factory.deploy.
- No named return values.
- Compiler (`foundry.toml`): Cancun EVM, optimizer at 100,000 runs, no CBOR
  metadata (`cbor_metadata = false`, `bytecode_hash = "none"`).
- Dependencies are managed with Soldeer (`[dependencies]` in `foundry.toml` +
  `soldeer.lock`, vendored under `dependencies/`). Everything there is
  test-harness only: forge-std, plus `@openzeppelin-contracts` as the
  equivalence oracle for the EIP1167 construction and the beacon proxy.
  `rain-deploy` and `rain-sol-codegen` belong to the deploy half and must not be
  added here: needing one means deploy-pin code has landed in a library repo.
