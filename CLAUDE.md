# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

rain.factory is a Solidity **library** repo for Rain's proxy factories (EIP1167
clones and OZ `BeaconProxy`s): the `ICloneable*` interface surface and the
`LibICloneableFactoryV5` library that implements it. It is the library half of
the library/deploy split (rainlanguage/rain.factory#46) — no deployed concrete,
deploy pin or deploy script in `src/`.

The concrete `CloneFactory`, its deployed address + codehash pins
(`LibCloneFactoryDeploy`), the frozen deploy-pin snapshots and
`script/Deploy.sol` all live in
[`rain.factory.deploy`](https://github.com/rainlanguage/rain.factory.deploy),
publishing as `rain-factory-deploy`. Depend on `rain-factory` for the interfaces
and library; on `rain-factory-deploy` for the deployed pins, which embed the
`rain-factory` revision that repo pins.

License: LicenseRef-DCL-1.0 (DecentraLicense). Every `.sol` copies the two SPDX
header lines its siblings carry.

## Testing

Regenerate `src/generated/` with `forge script script/Build.sol && forge fmt`;
CI's `Git is clean` job does the same and fails on any tracked diff, and
`test/script/Build.t.sol` fails if the script stops writing exactly the
committed file. Tests call the library directly, and through `TestCloneFactory`
where `msg.sender`/`address(this)` must be real. OZ `Clones` is the foreign
EIP1167 oracle.

## Architecture

- `src/interface/ICloneableFactoryV7.sol` is the current factory interface: V5
  plus beacon proxies resolved from a config registry. Every derivation is
  pinned to exact bytes behind a distinct string-derived domain tag, so the
  images are disjoint by construction.
- `src/interface/ICloneableV2.sol` is the cloneable interface:
  `initialize(bytes)` must return `ICLONEABLE_V2_SUCCESS`.
- `src/lib/LibICloneableFactoryV5.sol` and `LibICloneableFactoryV7.sol` are the
  whole factory as internal library logic (no external cloning dependency);
  `msg.sender` and `address(this)` are read inside the library.
- `src/interface/deprecated/` — Every interface that is not the newest version
  of itself (`ICloneableV1`, `IFactory`, `ICloneableFactoryV1`–`V6`). Still
  published for consumers pinned to them, so FROZEN: never edit one. Do not use
  for new work. When a new version lands, the one it supersedes moves here.
- `src/test/` — the fixtures rain.factory.deploy's suite imports
  (`TestCloneable`, `TestCloneableFailure`, `TestCloneFactory`), published so
  that suite runs against these rather than a copy (#169). Fixtures that no
  downstream consumer imports stay in the unpublished `test/`.

No `src/` file imports from outside this repo — intra-repo inheritance is
allowed (`ICloneableFactoryV5` extends `ICloneableFactoryV4`), which is what
makes this half a standalone publish.

## Solidity Conventions

- No named return values in implementations.
- NatSpec is terse: what an item does and non-obvious invariants only. rainix
  `comment-loc-cap` (comment lines at most 2x code lines across `src`) binds;
  cut prose to fit, never exempt.
- The OZ pin and the `foundry.toml` compiler settings are frozen: they fix the
  `BeaconProxy` and `RegistryBeaconProxy` creation code in the V5 and V7 address
  derivations, so changing either needs a new interface version.
- `rain-deploy` is a dependency for the clone and beacon-proxy deploy mechanisms
  (`RainDeployCloneSuitesBase` and its per-role `RainDeployClone*` bases);
  deploy pins and deploy scripts still live in `rain.factory.deploy`.
