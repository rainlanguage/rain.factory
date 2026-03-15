# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

rain.factory is a Solidity library providing EIP1167 minimal proxy (clone) factory contracts for the Rain ecosystem. The core contract `CloneFactory` clones any contract implementing `ICloneableV2` and atomically initializes it.

License: LicenseRef-DCL-1.0 (Dark Matter Council License). All source files must include SPDX headers.

## Build & Test Commands

This project uses **Nix + Foundry (Forge)**. Enter the dev shell first:

```bash
nix develop
```

Then use rainix tasks:

```bash
# Run all tests
nix develop -c rainix-sol-test

# Static analysis (Slither)
nix develop -c rainix-sol-static

# License/legal checks (REUSE compliance)
nix develop -c rainix-sol-legal

# Prelude (dependency setup, run before other tasks)
nix develop -c rainix-sol-prelude
```

Direct Forge commands also work inside the nix shell:

```bash
# Run all tests
forge test

# Run a specific test
forge test --match-test testCloneFactory

# Run tests in a specific file
forge test --match-path test/src/CloneFactory.t.sol

# Build
forge build
```

## Architecture

- `src/interface/ICloneableV2.sol` — Interface for cloneable contracts. `initialize(bytes)` must return `ICLONEABLE_V2_SUCCESS` (keccak256 hash) on success.
- `src/interface/ICloneableFactoryV2.sol` — Factory interface with `clone(address, bytes)` and `NewClone` event.
- `src/concrete/CloneFactory.sol` — The single concrete implementation. Uses OpenZeppelin `Clones.clone()`.
- `src/lib/LibCloneFactoryDeploy.sol` — Deterministic deployment address and codehash constants.
- `src/interface/deprecated/` — Legacy interfaces (`ICloneableV1`, `ICloneableFactoryV1`, `IFactory`). Do not use for new work.

## Solidity Conventions

- Solidity version: `=0.8.25` (exact, not caret)
- EVM target: Cancun
- Optimizer: enabled, 100,000 runs
- No CBOR metadata (`cbor_metadata = false`, `bytecode_hash = "none"`)
- Dependencies are git submodules in `lib/` (forge-std, openzeppelin-contracts, rain.deploy, rain.extrospection)

## Deployment

Deployed via deterministic Zoltu deployer (from `rain.deploy`). The canonical deployment address and codehash are committed in `LibCloneFactoryDeploy.sol`. Deployment scripts are in `script/Deploy.sol` targeting Arbitrum, Base, Flare, and Polygon.

## CI

GitHub Actions runs three parallel jobs on every push: `rainix-sol-test`, `rainix-sol-static`, `rainix-sol-legal`. Fork tests require RPC URL secrets.
