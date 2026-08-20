# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

rain.factory is a Solidity **library** repo: the `ICloneable*` interface surface
for EIP1167 minimal proxy (clone) factories in the Rain ecosystem, plus the
`Lib*` logic that implements it. It is the library half of the library/deploy
split (rainlanguage/rain.factory#46): the salt derivations, guards and the
clone-initialize-verify flow live here as internal library code, unit tested —
no concrete contract, no deploy pins, no deploy script.

The concrete `CloneFactory` — meant to be a pure delegation into
`LibCloneFactory`, one call per entry point — its deployed address + codehash
pins (`LibCloneFactoryDeploy`), the frozen deploy-pin snapshots and
`script/Deploy.sol` all live in
[`rain.factory.deploy`](https://github.com/rainlanguage/rain.factory.deploy),
publishing as `rain-factory-deploy`. Depend on `rain-factory` for the interfaces
and library; on `rain-factory-deploy` for the deployed pins.

License: LicenseRef-DCL-1.0 (DecentraLicense). All source files must include
SPDX headers.

## Build & Test Commands

Nix + Foundry. Enter the shell with `nix develop`, then run rainix tasks:
`rainix-sol-static` (Slither), `rainix-sol-legal` (REUSE), `rainix-sol-prelude`
(deps, run first), `rainix-sol-test`, and `forge build` / `forge test` directly.
The suite under `test/` unit-tests the library through `TestCloneFactory`, a
pure-delegation concrete, pinning the EIP1167 construction against OZ `Clones`
as a foreign oracle.

## Architecture

- `src/interface/ICloneableV2.sol` — Cloneable contracts. `initialize(bytes)`
  must return `ICLONEABLE_V2_SUCCESS` on success.
- `src/interface/ICloneableFactoryV2.sol` — Legacy factory interface
  (nonce-dependent `clone`). Still published for other consumers.
- `src/interface/ICloneableFactoryV3.sol` — Deterministic-only factory interface
  (CREATE2, salt namespaced by `msg.sender`). Standalone — does NOT extend V2;
  the non-deterministic `clone()` was intentionally dropped. Still published for
  consumers pinned to it.
- `src/interface/ICloneableFactoryV4.sol` — Current factory interface. Extends
  V3 and adds the open-salt pair `cloneDeterministicOpenSalt` /
  `predictDeterministicAddressOpenSalt`. Both derivations are pinned to exact
  bytes, each `keccak256`-ing a 96-byte preimage led by a distinct
  string-derived domain tag, so the two images are disjoint by construction. The
  NatSpec on this interface is the spec for `LibCloneFactory`.
- `src/lib/LibCloneFactory.sol` — The whole factory as internal library logic:
  both effective-salt derivations, the implementation-code guard, EIP1167
  creation code + CREATE2 prediction (no external cloning dependency), and the
  atomic clone-initialize-verify flow with the typed errors and `NewClone`.
  `msg.sender` and `address(this)` are read inside the library, so a delegating
  concrete cannot misroute them.
- `src/interface/deprecated/` — Legacy (`ICloneableV1`, `ICloneableFactoryV1`,
  `IFactory`). Do not use for new work.

The published `src/` imports nothing from outside this repo — which is what
makes this half a standalone publish.

## Solidity Conventions

- Versions: interfaces float `^0.8.18` so downstream soldeer consumers on a
  different `0.8.x` still compile them; libraries float `^0.8.25`; tests pin
  `=0.8.25`, as do concretes and scripts (which live in rain.factory.deploy).
- No named return values.
- Compiler (`foundry.toml`): Cancun EVM, optimizer at 100,000 runs, no CBOR
  metadata (`cbor_metadata = false`, `bytecode_hash = "none"`).
- Dependencies are managed with Soldeer (`[dependencies]` in `foundry.toml` +
  `soldeer.lock`, vendored under `dependencies/`). Everything there is
  test-harness only: forge-std, plus `@openzeppelin-contracts` as the
  equivalence oracle for the EIP1167 construction. `rain-deploy` and
  `rain-sol-codegen` belong to the deploy half and must not be added here:
  needing one means deploy-pin code has landed in a library repo.
