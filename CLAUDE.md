# CLAUDE.md

## What this repo is, and the boundary that must hold

rain.factory is the **library** half of the library/deploy split
(rainlanguage/rain.factory#46): `ICloneable*` interfaces only. The concrete
`CloneFactory`, its address/codehash pins, the `src/generated/<tag>/` snapshots,
`script/Deploy.sol` and every test live in
[`rain.factory.deploy`](https://github.com/rainlanguage/rain.factory.deploy) and
publish as `rain-factory-deploy`; this repo publishes as `rain-factory`.

- No concrete, no deploy pins, no deploy script, no tests belong here — an
  interface declares no behaviour, so there is nothing here to test. Adding any
  of them means the split has been undone.
- No dependency outside forge-std belongs here. `@openzeppelin-contracts`,
  `rain-extrospection`, `rain-deploy` and `rain-sol-codegen` went with the
  deploy half: adding one back means concrete code has landed in a library repo.
- Nothing here is deployed, tag-released or snapshot-frozen — that lifecycle is
  the deploy half's.

## Conventions that are not recoverable from the code

- Interfaces float the `^` pragma (`^0.8.18`) so a downstream soldeer consumer
  on a different `0.8.x` can still compile them. The `=0.8.25` exact-pin rule is
  for concrete contracts, scripts and tests, which are not here.
- Every source file carries an SPDX header; the license is LicenseRef-DCL-1.0
  (REUSE / `rainix-sol-legal` enforces it).
- Release is `rainix-autopublish`: `[package].version` in `foundry.toml` is the
  NEXT, unpublished version, and a content change on merge publishes that
  version and bumps to the next.
