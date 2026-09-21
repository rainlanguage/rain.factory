---
paths:
  - "test/**"
---

# Test layout

Tests of `src/` mirror its path under `test/src/`, one file per behaviour:
`LibICloneableFactoryV4.<function>.t.sol` where the behaviour is one function,
`LibICloneableFactoryV4.t.sol` where it spans several.

Contracts the suite deploys as fixtures — `TestCloneFactory`, `TestCloneable*` —
live in `test/concrete/` by their own kind, never in the mirror tree.
