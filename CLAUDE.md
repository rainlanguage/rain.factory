# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

rain.factory is a Solidity **library** repo for Rain's proxy factories (EIP1167
clones and minimal ERC-1967 beacon proxies): the `ICloneable*` interface surface
and the `LibICloneableFactoryV4` and `LibICloneableFactoryV5` libraries that
implement it. It is the library half of the library/deploy split
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

## Testing

Nix + Foundry (`nix develop`; run `rainix-sol-prelude` first). Tests exercise
the libraries through `TestCloneFactory`, a pure-delegation concrete, with OZ
`Clones` as foreign EIP1167 oracle and OZ `BeaconProxy` as behavioural oracle
for the beacon proxy.

## Architecture

- `src/interface/ICloneableFactoryV5.sol` is the current factory interface; its
  NatSpec is the full spec, with every derivation pinned to exact bytes behind a
  distinct string-derived domain tag so the images are disjoint by construction.
- `src/lib/LibICloneableFactoryV4.sol` / `LibICloneableFactoryV5.sol` are the
  whole factory as internal library logic (no external cloning dependency);
  `msg.sender` and `address(this)` are read inside the library.
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
- Dependencies (Soldeer, vendored under `dependencies/`) are test-harness only:
  forge-std, plus `@openzeppelin-contracts` as the equivalence oracle for the
  EIP1167 construction and the beacon proxy. `rain-deploy` and
  `rain-sol-codegen` belong to the deploy half and must not be added here:
  needing one means deploy-pin code has landed in a library repo.
