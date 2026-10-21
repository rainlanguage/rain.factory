---
paths:
  - "test/**"
---

# Test layout

Tests of `src/` mirror its path under `test/src/`, one file per behaviour:
`LibICloneableFactoryV5.<function>.t.sol` where the behaviour is one function,
`LibICloneableFactoryV5.t.sol` where it spans several.

Contracts the suite deploys as fixtures (`TestCloneFactory`, `TestCloneable*`,
`TestBeacon*`) live in `test/concrete/`, never in the mirror tree. Shared test
bases live in `test/abstract/`, and shared helper libraries in `test/lib/`.
