# Audit Triage — 2026-03-15-01

| ID | Pass | Severity | Title | Status |
|----|------|----------|-------|--------|
| A01-1 | 4 | LOW | Bare `src/` import paths in Deploy.sol | FIXED |
| A01-2 | 5 | LOW | Empty `contractPath` produces malformed verification command | FIXED |
| A02-1 | 2 | LOW | Bare `vm.expectRevert()` in `testCloneUninitializableFails` | DOCUMENTED |
| A02-2 | 2 | LOW | No test for `initialize` revert propagation | DISMISSED |
| A02-3 | 3 | LOW | Stale NatSpec reference to `DeployerDiscoverableMetaV2` | FIXED |
| A02-4 | 4 | LOW | Stale NatSpec reference to `DeployerDiscoverableMetaV2` (dup of A02-3) | DISMISSED |
| P0-1 | 0 | LOW | Incorrect test file path in CLAUDE.md example | FIXED |
| P0-2 | 0 | LOW | CLAUDE.md not listed in REUSE.toml annotations | FIXED |
| R-1 | 3 | LOW | README uses unversioned interface names | FIXED |
| R-2 | 3 | LOW | README claims CloneFactory implements deployer discoverability | FIXED |
| R-3 | 3 | LOW | Empty `## Implementations` section in README | FIXED |
| T01-1 | 4 | LOW | Bare `src/` import paths in CloneFactory.t.sol | FIXED |
| T01-2 | 4 | LOW | Inconsistent function visibility (`public` vs `external`) in test | FIXED |
| T01-3 | 4 | LOW | Bare `vm.expectRevert()` without selector (dup of A02-1) | DISMISSED |
| T02-1 | 4 | LOW | Bare `src/` import paths in LibCloneFactoryDeploy.t.sol | FIXED |

## Notes

- **A02-4** dismissed as duplicate of A02-3 (same stale NatSpec finding reported in pass 3 and pass 4).
- **T01-3** dismissed as duplicate of A02-1 (same bare `vm.expectRevert()` finding reported in pass 2 and pass 4).
