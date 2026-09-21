---
paths:
  - "src/**"
  - "test/**"
---

# Import paths

`src/` files import each other RELATIVE (`../interface/X.sol`,
`./ICloneableFactoryV3.sol`). A root-rooted `src/...` import compiles here but
binds the CONSUMER's `src/` once published.

Tests use the root-rooted form, `src/...` and `test/...`.

Dependency imports carry the pinned version — `forge-std-1.16.1/src/Test.sol`,
`@openzeppelin-contracts-5.6.1/proxy/Clones.sol`. A version bump in
`foundry.toml` must be mirrored into every import path that names the old one.
