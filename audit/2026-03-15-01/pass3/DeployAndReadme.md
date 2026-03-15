# Pass 3 - Documentation: Deploy.sol, LibCloneFactoryDeploy.sol, README.md

## Evidence of Thorough Reading

### A01: `script/Deploy.sol`

- **Contract:** `Deploy` (inherits `Script`), line 12
- **Functions:**
  - `run()` external, line 13
- **Imports:**
  - `Script` from `forge-std/Script.sol`, line 5
  - `CloneFactory` from `src/concrete/CloneFactory.sol`, line 6
  - `LibRainDeploy` from `rain.deploy/lib/LibRainDeploy.sol`, line 7
  - `LibCloneFactoryDeploy` from `src/lib/LibCloneFactoryDeploy.sol`, line 8
- **Constants/Errors/Events:** None defined in this file
- **NatSpec:**
  - Contract-level: `@title Deploy`, `@notice A script that deploys a CloneFactory.` (lines 10-11)
  - `run()`: No NatSpec

### A08: `src/lib/LibCloneFactoryDeploy.sol`

- **Library:** `LibCloneFactoryDeploy`, line 11
- **Functions:** None
- **Constants:**
  - `CLONE_FACTORY_DEPLOYED_ADDRESS` (address), line 14
  - `CLONE_FACTORY_DEPLOYED_CODEHASH` (bytes32), lines 20-21
- **Errors/Events:** None
- **NatSpec:**
  - Library-level: `@title LibCloneFactoryDeploy` + description (lines 5-10)
  - `CLONE_FACTORY_DEPLOYED_ADDRESS`: NatSpec comment (lines 12-13)
  - `CLONE_FACTORY_DEPLOYED_CODEHASH`: NatSpec comment (lines 16-19)

### README.md

- 68 lines total
- Sections: Concrete implementations (line 5), Interfaces (line 13), Legacy (line 43), ICloneableV1 (line 45), IFactory (line 53), Implementations (line 68, empty)

### Cross-reference: Interfaces

- `ICloneableFactoryV2` (src/interface/ICloneableFactoryV2.sol): event `NewClone`, function `clone`
- `ICloneableV2` (src/interface/ICloneableV2.sol): error `InitializeSignatureFn`, function `initialize`, constant `ICLONEABLE_V2_SUCCESS`
- `CloneFactory` (src/concrete/CloneFactory.sol): inherits only `ICloneableFactoryV2`; does NOT inherit `DeployerDiscoverableMetaV2`

---

## Findings

### R-1 [LOW] README uses unversioned interface names `ICloneableFactory` and `ICloneable`

**File:** `README.md`, lines 7-8

**Description:**
Line 7 refers to `ICloneableFactory` and line 8 refers to `ICloneable`, but the actual interface names in the codebase are `ICloneableFactoryV2` and `ICloneableV2`. These unversioned names do not correspond to any interface in the repository. While the README later correctly uses the V2-suffixed names (lines 37-39), the opening section is inconsistent and could mislead readers into thinking there is an unversioned interface.

**Lines:**
```
7: `CloneFactory` implements the latest version of `ICloneableFactory` allowing any
8: compatible `ICloneable` contract to be cloned as an EIP1167 proxy and
```

**Expected:**
```
7: `CloneFactory` implements `ICloneableFactoryV2` allowing any
8: compatible `ICloneableV2` contract to be cloned as an EIP1167 proxy and
```

### R-2 [LOW] README claims CloneFactory implements interpreter deployer discoverability, but it does not

**File:** `README.md`, line 11

**Description:**
The README states: `CloneFactory implements interpreter deployer discoverability.` However, the actual `CloneFactory` contract (src/concrete/CloneFactory.sol) only inherits `ICloneableFactoryV2`. It does not inherit `DeployerDiscoverableMetaV2` or any other discoverability contract. There are no imports or inheritance related to discoverability in the contract.

Note: The NatSpec in `CloneFactory.sol` line 17 also references `DeployerDiscoverableMetaV2` in its description, but this is a stale reference from a previous version of the contract that no longer implements it. This makes both the README and the contract NatSpec inaccurate.

**Line:**
```
11: `CloneFactory` implements interpreter deployer discoverability.
```

**Expected:** This line should be removed, or updated to reflect actual functionality.

### R-3 [LOW] Empty `## Implementations` section at end of README

**File:** `README.md`, line 68

**Description:**
The README ends with an `## Implementations` heading but no content beneath it. This is a dangling section header that suggests incomplete documentation. It should either be populated with relevant content or removed.

### A01-1 [INFO] `run()` function in Deploy script lacks NatSpec

**File:** `script/Deploy.sol`, line 13

**Description:**
The `run()` function has no NatSpec documentation. While the contract-level `@notice` provides a general description, the `run()` function itself could benefit from documenting what it does (deploys CloneFactory using deterministic deployment via the Zoltu deployer) and what environment variable it requires (`DEPLOYMENT_KEY`).

This is INFO rather than LOW because deployment scripts are operational tooling rather than library/interface code, and the contract-level NatSpec adequately describes the script's purpose.

---

## Summary

| ID | Severity | Title |
|----|----------|-------|
| R-1 | LOW | README uses unversioned interface names |
| R-2 | LOW | README claims CloneFactory implements interpreter deployer discoverability |
| R-3 | LOW | Empty `## Implementations` section at end of README |
| A01-1 | INFO | `run()` function in Deploy script lacks NatSpec |

No findings for A08 (`LibCloneFactoryDeploy.sol`) -- documentation is complete and accurate.
