# Pass 2 -- Test Coverage: Interfaces and Deploy Script

Reviewed files:
- A01: `script/Deploy.sol`
- A03: `src/interface/ICloneableFactoryV2.sol`
- A04: `src/interface/ICloneableV2.sol`
- A05: `src/interface/deprecated/ICloneableFactoryV1.sol`
- A06: `src/interface/deprecated/ICloneableV1.sol`
- A07: `src/interface/deprecated/IFactory.sol`

---

## A01: `script/Deploy.sol`

**Contract:** `Deploy` (inherits `Script`)
- **Function:** `run()` (line 13) -- external, reads `DEPLOYMENT_KEY` env var, calls `LibRainDeploy.deployAndBroadcastToSupportedNetworks` with `CloneFactory` creation code and constants from `LibCloneFactoryDeploy`.

**Evidence of reading:**
- Imports: `Script` (forge-std), `CloneFactory`, `LibRainDeploy`, `LibCloneFactoryDeploy` (lines 5-8)
- Uses `vm.envUint("DEPLOYMENT_KEY")` (line 14)
- Passes `type(CloneFactory).creationCode`, empty constructor args `""`, `CLONE_FACTORY_DEPLOYED_ADDRESS`, `CLONE_FACTORY_DEPLOYED_CODEHASH`, and empty address array (lines 20-24)

**Testable logic:** The script contains orchestration logic for deployment. The underlying constants (`CLONE_FACTORY_DEPLOYED_ADDRESS`, `CLONE_FACTORY_DEPLOYED_CODEHASH`) are tested in `test/src/lib/LibCloneFactoryDeploy.t.sol`, which validates both the deterministic deploy address and the code hash. The script itself is a Forge `Script` intended for operational use, not unit-testable in isolation.

**Indirect test references:** `test/src/lib/LibCloneFactoryDeploy.t.sol` tests the same constants and deployment flow used by the script.

**Findings:** No findings.

---

## A03: `src/interface/ICloneableFactoryV2.sol`

**Interface:** `ICloneableFactoryV2` (line 10)
- **Event:** `NewClone(address sender, address implementation, address clone)` (line 15)
- **Function:** `clone(address implementation, bytes calldata data) external returns (address)` (line 31)

**Evidence of reading:** Pure interface, no implementation code. Two declarations total (1 event, 1 function).

**Indirect test references:** `CloneFactory` implements `ICloneableFactoryV2`. The `NewClone` event is tested in `CloneFactory.t.sol` at line 80 (topic hash verified) and line 81 (data verified). The `clone` function signature is exercised throughout `CloneFactory.t.sol`.

**Findings:** No findings.

---

## A04: `src/interface/ICloneableV2.sol`

**Interface:** `ICloneableV2` (line 11)
- **File-level constant:** `ICLONEABLE_V2_SUCCESS = keccak256("ICloneableV2.initialize")` (line 7)
- **Error:** `InitializeSignatureFn()` (line 13)
- **Function:** `initialize(bytes calldata data) external returns (bytes32 success)` (line 48)

**Evidence of reading:** Constant defined at file scope (not inside interface). Error `InitializeSignatureFn` is defined for typed overload reverts. NatSpec documents the pattern of typed overloads that must revert with `InitializeSignatureFn`.

**Indirect test references:**
- `ICLONEABLE_V2_SUCCESS` is imported and used in `CloneFactory.t.sol` (lines 8, 21, 28, 95). `TestCloneable` returns it on success; `TestCloneableFailure` returns arbitrary values. The `CloneFactory.sol` implementation checks the return value against this constant at line 39.
- `ICloneableV2` interface is implemented by `TestCloneable` and `TestCloneableFailure` in `CloneFactory.t.sol`.
- `InitializeSignatureFn` error: not referenced anywhere in tests or source implementation. It is defined purely as a convention for implementors of typed `initialize` overloads. No implementation in this repository uses it.

**Findings:** No findings. The `InitializeSignatureFn` error is a convention for downstream implementors; it has no implementation in this repo to test. The constant `ICLONEABLE_V2_SUCCESS` is thoroughly tested indirectly.

---

## A05: `src/interface/deprecated/ICloneableFactoryV1.sol`

**Interface:** `ICloneableFactoryV1` (line 10)
- **Event:** `NewClone(address sender, address implementation, address clone)` (line 15)
- **Function:** `clone(address implementation, bytes calldata data) external returns (address)` (line 27)

**Evidence of reading:** Pure interface, deprecated. Two declarations (1 event, 1 function). Identical structure to `ICloneableFactoryV2` but references `ICloneableV1` in NatSpec.

**Indirect test references:** Not referenced anywhere in `src/` implementation code or `test/`. This is a deprecated interface retained for ABI compatibility only.

**Findings:** No findings. Deprecated pure interface with no implementation in this repository.

---

## A06: `src/interface/deprecated/ICloneableV1.sol`

**Interface:** `ICloneableV1` (line 8)
- **Function:** `initialize(bytes calldata data) external` (line 26) -- note: returns `void`, unlike V2 which returns `bytes32`.

**Evidence of reading:** Pure interface, deprecated. Single function declaration. Key difference from V2: no return value on `initialize`, which was the security concern that motivated V2 (false positive initialization detection).

**Indirect test references:** Not referenced anywhere in `src/` implementation code or `test/`. Deprecated interface retained for ABI compatibility.

**Findings:** No findings. Deprecated pure interface with no implementation in this repository.

---

## A07: `src/interface/deprecated/IFactory.sol`

**Interface:** `IFactory` (line 5)
- **Event:** `NewChild(address sender, address child)` (line 10)
- **Event:** `Implementation(address sender, address implementation)` (line 18)
- **Function:** `createChild(bytes calldata data) external returns (address)` (line 24)
- **Function:** `isChild(address maybeChild) external view returns (bool)` (line 35)

**Evidence of reading:** Pure interface, deprecated. Four declarations (2 events, 2 functions). This is a different pattern from the CloneableFactory interfaces -- it includes `isChild` for registry checks and `createChild` instead of `clone`.

**Indirect test references:** Not referenced anywhere in `src/` implementation code or `test/`. Deprecated interface retained for ABI compatibility.

**Findings:** No findings. Deprecated pure interface with no implementation in this repository.

---

## Summary

| File | Type | Testable Logic | Indirectly Tested | Findings |
|------|------|---------------|-------------------|----------|
| A01 `Deploy.sol` | Script | Deployment orchestration | Yes (constants tested in `LibCloneFactoryDeploy.t.sol`) | None |
| A03 `ICloneableFactoryV2.sol` | Interface | None | Yes (implemented by `CloneFactory`, tested in `CloneFactory.t.sol`) | None |
| A04 `ICloneableV2.sol` | Interface + constant + error | Constant `ICLONEABLE_V2_SUCCESS` | Yes (constant used in `CloneFactory.sol` and tested in `CloneFactory.t.sol`) | None |
| A05 `ICloneableFactoryV1.sol` | Deprecated interface | None | No (not used anywhere) | None |
| A06 `ICloneableV1.sol` | Deprecated interface | None | No (not used anywhere) | None |
| A07 `IFactory.sol` | Deprecated interface | None | No (not used anywhere) | None |

**Total findings: 0**

All files are either pure interface declarations (no implementation to test), deprecated interfaces not used by any implementation in this repository, or a deployment script whose underlying logic is already covered by existing tests. No coverage gaps identified.
