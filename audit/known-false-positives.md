# Known false positives

Audit findings that were triaged and are not defects, recorded so later audits
do not re-raise them.

## Mutant T20: `deployChild` returns `predicted` instead of `child`

- **Where:** `src/lib/LibICloneableFactoryV4.sol`, `deployChild`.
- **Mutation:** `return child;` becomes `return predicted;`.
- **Why it is equivalent:** the return is reached only when `CREATE2` returned a
  non-zero address. EIP-1014 fixes that address as
  `keccak256(0xff ++ address(this) ++ derivedSalt ++ keccak256(creationCode))`,
  which is exactly what `predictCreate2Address` computes for `predicted`. So
  `child == predicted` on every path that returns, and no test can tell them
  apart.
- **Resolved:** mutation scans of PR #271 (2026-10-20).
