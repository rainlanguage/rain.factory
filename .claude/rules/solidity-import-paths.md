---
paths:
  - "src/**"
  - "test/**"
  - "script/**"
---

# Import paths

Every first-party import is RELATIVE (`../interface/X.sol`,
`../../src/lib/LibICloneableFactoryV5.sol`). A root-rooted `src/...` import
compiles here but binds the CONSUMER's `src/` once published.

Dependency imports carry the pinned version, e.g.
`forge-std-1.17.0/src/Test.sol` or
`@openzeppelin-contracts-5.6.1/proxy/Clones.sol`. A version bump in
`foundry.toml` must be mirrored into every import path that names the old one.
