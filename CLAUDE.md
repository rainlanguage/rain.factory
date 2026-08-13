# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

rain.factory is a Solidity **library** repo: the `ICloneable*` interface surface
for EIP1167 minimal proxy (clone) factories in the Rain ecosystem. It is the
library half of the library/deploy split (rainlanguage/rain.factory#46) and holds
interfaces only — no concrete contract, no deploy pins, no deploy script, and no
tests.

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

This project uses **Nix + Foundry (Forge)**. Enter the dev shell first:

```bash
nix develop
```

Then use rainix tasks:

```bash
# Static analysis (Slither)
nix develop -c rainix-sol-static

# License/legal checks (REUSE compliance)
nix develop -c rainix-sol-legal

# Prelude (dependency setup, run before other tasks)
nix develop -c rainix-sol-prelude

# Runs, but there is no test suite here: the interfaces have no behaviour to
# test. The tests that exercise them live in rain.factory.deploy, against the
# concrete.
nix develop -c rainix-sol-test
```

Direct Forge commands also work inside the nix shell:

```bash
# Build
forge build
```

## Architecture

- `src/interface/ICloneableV2.sol` — Interface for cloneable contracts.
  `initialize(bytes)` must return `ICLONEABLE_V2_SUCCESS` (keccak256 hash) on
  success.
- `src/interface/ICloneableFactoryV2.sol` — Legacy factory interface: the
  nonce-dependent `clone(address, bytes)` and `NewClone` event. Superseded by
  `ICloneableFactoryV3`/`ICloneableFactoryV4` for the concrete factory in
  rain.factory.deploy; still published for other consumers.
- `src/interface/ICloneableFactoryV3.sol` — Deterministic-only factory
  interface: `cloneDeterministic(address, bytes, bytes32)` +
  `predictDeterministicAddress(address, bytes32, address)` (CREATE2, salt
  namespaced by `msg.sender`) and its own `NewClone` event. Standalone — does
  NOT extend `ICloneableFactoryV2`, because the non-deterministic `clone()` was
  intentionally dropped. Still published for consumers pinned to it.
- `src/interface/ICloneableFactoryV4.sol` — Current factory interface. Extends
  `ICloneableFactoryV3` (nothing was dropped this time, so it inherits rather
  than restates) and adds the open-salt variant:
  `cloneDeterministicOpenSalt(address, bytes, bytes32)` +
  `predictDeterministicAddressOpenSalt(address, bytes32)`, which use the
  caller-supplied salt verbatim so the deployer is not in the address
  derivation. Only safe for implementations whose `initialize` takes no
  caller-controlled authority — the NatSpec on the function is the spec for
  that, and it is the deliverable of this interface as much as the two
  signatures are.
- `src/interface/deprecated/` — Legacy interfaces (`ICloneableV1`,
  `ICloneableFactoryV1`, `IFactory`). Do not use for new work.

`src/` holds nothing else. No interface here imports anything outside this repo
— no third-party library, no concrete contract — which is what makes this half a
standalone publish. Interface-to-interface inheritance within `src/interface/`
is allowed and `ICloneableFactoryV4` uses it (`is ICloneableFactoryV3`, via a
relative import).

## Solidity Conventions

- Solidity version: every file here is an interface and floats `^` (the
  interfaces use `^0.8.18`) so downstream soldeer consumers on a different
  `0.8.x` can still compile them. The `=0.8.25` exact-pin rule applies to
  concrete contracts, scripts and tests, which live in rain.factory.deploy.
- EVM target: Cancun
- Optimizer: enabled, 100,000 runs
- No CBOR metadata (`cbor_metadata = false`, `bytecode_hash = "none"`)
- Dependencies are managed with Soldeer (`[dependencies]` in `foundry.toml` +
  `soldeer.lock`, vendored under `dependencies/`). The interfaces import nothing
  from outside this repo, so the only entry is forge-std.
  `@openzeppelin-contracts`, `rain-extrospection`,
  `rain-deploy` and `rain-sol-codegen` went with the deploy half and must not
  come back: adding one here means concrete code has landed in a library repo.

## Deployment

Nothing in this repo is deployed. The deterministic Zoltu deploy of the concrete
`CloneFactory`, its canonical address and codehash, and the deploy scripts
targeting Arbitrum, Base, Base Sepolia, Flare and Polygon are all in
rain.factory.deploy.

## Releases

Library repo, so `package-release.yaml` runs `rainix-autopublish`:
`[package].version` in `foundry.toml` is the NEXT, unpublished version, and a
content change on merge publishes it and bumps to the next. Nothing here is
tag-released, and no snapshot is frozen — that lifecycle belongs to the deploy
half.

## CI

GitHub Actions runs three parallel jobs on every push: `rainix-sol-test`,
`rainix-sol-static`, `rainix-sol-legal`. There are no fork tests and no RPC
secrets are needed.
