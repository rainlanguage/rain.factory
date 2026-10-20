# Known false positives

Audit findings that were triaged and are not defects, recorded so later audits
do not re-raise them.

## Mutant V5-25: `checkBeacon`'s `if (!success)` guarded on non-empty revert data

- **Where:** `src/lib/LibICloneableFactoryV5.sol`, `checkBeacon`, the
  `if (!success)` branch after `beacon.staticcall(implementation())`.
- **Mutation:** `if (!success)` becomes
  `if (!success && returnData.length > 0)`.
- **Why it is equivalent:** the mutant differs only when the beacon reverts with
  empty data. The mutated branch then falls through to
  `abi.decode(returnData, (address))` on 0 bytes, which reverts with empty
  revert data. The baseline bubbles the beacon's empty revert data. Both revert
  with the same empty bytes and no state change, so no test can tell them apart.
- **Resolved:** rain-marvin audit of PR #271 (2026-10-20) classified V5-25 as
  equivalent.

## Mutant V05: the beacon-proxy effective salt hashed with `abi.encodePacked`

- **Where:** `src/lib/LibICloneableFactoryV5.sol`,
  `effectiveBeaconProxyOpenSalt`.
- **Why it is equivalent:** the preimage is three `bytes32` words. `abi.encode`
  and `abi.encodePacked` produce the same 96 bytes for them, so the hash is the
  same.
- **Resolved:** mutation scans of PR #271 (2026-10-20).
