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

## Mutant V05: an open-salt preimage hashed with `abi.encodePacked`

- **Where:** `src/lib/LibICloneableFactoryV4.sol`, `effectiveOpenSalt`, and
  `src/lib/LibICloneableFactoryV5.sol`, `effectiveBeaconProxyOpenSalt`.
- **Mutation:** `keccak256(abi.encode(DOMAIN, salt, keccak256(data)))` becomes
  `keccak256(abi.encodePacked(DOMAIN, salt, keccak256(data)))`.
- **Why it is equivalent:** all three arguments are `bytes32`. `abi.encode`
  writes each static 32-byte value as one word with no padding, and
  `abi.encodePacked` writes each `bytes32` as its 32 bytes, so both produce the
  same 96 bytes and the same hash.
- **Resolved:** mutation scans of PR #271 (2026-10-20).

## Mutant V28/V5-25: `checkBeacon` bubbles only non-empty revert data

- **Where:** `src/lib/LibICloneableFactoryV5.sol`, `checkBeacon`, the
  `if (!success)` branch after the `implementation()` static call.
- **Mutation:** `if (!success)` becomes
  `if (!success && returnData.length > 0)`.
- **Why it is equivalent:** the two differ only when the beacon reverts with
  empty data. The mutant then falls through to
  `abi.decode(returnData, (address))` on 0 bytes, which reverts with empty data.
  The baseline bubbles the beacon's empty revert data. Both revert with the same
  empty bytes and no state change, so no test can tell them apart.
- **Resolved:** rain-marvin audit of PR #271 (2026-10-20).
