# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

rain.factory is a Solidity **library** repo for Rain's proxy factories (EIP1167
clones and OZ `BeaconProxy`s): the `ICloneable*` interface surface and the
`LibICloneableFactoryV5` library that implements it. It is the library half of
the library/deploy split (rainlanguage/rain.factory#46) — no concrete contract,
no deploy pins, no deploy script.

The concrete `CloneFactory`, its deployed address + codehash pins
(`LibCloneFactoryDeploy`), the frozen deploy-pin snapshots and
`script/Deploy.sol` all live in
[`rain.factory.deploy`](https://github.com/rainlanguage/rain.factory.deploy),
publishing as `rain-factory-deploy`. Depend on `rain-factory` for the interfaces
and library; on `rain-factory-deploy` for the deployed pins, which embed the
`rain-factory` revision that repo pins.

License: LicenseRef-DCL-1.0 (DecentraLicense). All source files must include
SPDX headers.

## Testing

Nix + Foundry (`nix develop`; run `rainix-sol-prelude` first). Checks:
`rainix-sol-test`, `rainix-sol-static` (Slither), `rainix-sol-legal` (REUSE).
Regenerate `src/generated/` with `forge script script/Build.sol && forge fmt`;
CI's `Git is clean` job does the same and fails on any tracked diff, and
`test/script/Build.t.sol` fails if the script stops writing exactly the
committed file. Tests exercise the libraries through `TestCloneFactory`, a
pure-delegation concrete, with OZ `Clones` as foreign EIP1167 oracle.

## Architecture

- `src/interface/ICloneableFactoryV5.sol` is the current factory interface.
  Every derivation is pinned to exact bytes behind a distinct string-derived
  domain tag, so the images are disjoint by construction.
- `src/interface/ICloneableV2.sol` is the cloneable interface:
  `initialize(bytes)` must return `ICLONEABLE_V2_SUCCESS`.
- `src/lib/LibICloneableFactoryV5.sol` is the whole factory as internal library
  logic (no external cloning dependency); `msg.sender` and `address(this)` are
  read inside the library.
- `src/interface/deprecated/` — Every interface that is not the newest version
  of itself (`ICloneableV1`, `IFactory`, `ICloneableFactoryV1`–`V4`). Still
  published for consumers pinned to them; do not use for new work. When a new
  version lands, the one it supersedes moves here.

No `src/` file imports from outside this repo — intra-repo inheritance is
allowed (`ICloneableFactoryV5` extends `ICloneableFactoryV4`), which is what
makes this half a standalone publish.

## Solidity Conventions

- Versions: interfaces float `^0.8.18` so downstream soldeer consumers on a
  different `0.8.x` still compile them; the library and `src/generated/` float
  `^0.8.25`; tests and `script/` pin `=0.8.25`, as do the concretes and scripts
  in rain.factory.deploy.
- No named return values.
- NatSpec is terse: what an item does and non-obvious invariants only. rainix
  `comment-loc-cap` (comment lines at most 2x code lines across `src`) binds;
  cut prose to fit, never exempt.
- Compiler (`foundry.toml`): Cancun EVM, optimizer at 100,000 runs, no CBOR
  metadata (`cbor_metadata = false`, `bytecode_hash = "none"`).
- Dependencies (Soldeer) are test/build only: forge-std, OZ (the EIP1167 oracle,
  and the `BeaconProxy` whose creation code `script/Build.sol` writes to
  `src/generated/` with `rain-sol-codegen`; never hand-edit it). The OZ pin and
  the compiler settings above are frozen: they fix the `BeaconProxy` creation
  code in the `ICloneableFactoryV5` address derivation, so changing either needs
  a new interface version. `rain-deploy` belongs to the deploy half: needing it
  means deploy-pin code has landed in a library repo.
