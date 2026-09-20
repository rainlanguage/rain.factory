---
paths:
  - "src/**"
  - "test/**"
---

# Import paths

`src/` files import each other RELATIVE (`../interface/X.sol`,
`./ICloneableFactoryV3.sol`). `.soldeerignore` excludes `/remappings.txt`, so
the published package carries no remappings of its own: a root-rooted
`src/...` import inside a `src/` file resolves against the CONSUMER's project
root and binds the consumer's `src/`, not this package's. Both forms compile
here, so nothing local catches it and the break lands downstream.

Tests use the root-rooted form, `src/...` and `test/...`.

Dependency imports carry the pinned version — `forge-std-1.16.1/src/Test.sol`,
`@openzeppelin-contracts-5.6.1/proxy/Clones.sol`. A version bump in
`foundry.toml` must be mirrored into every import path that names the old one.
