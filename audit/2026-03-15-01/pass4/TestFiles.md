# Pass 4 -- Code Quality: Test Files

## Evidence of Thorough Reading

### CloneFactory.t.sol

- **Contract `TestCloneable`** (line 15): implements `ICloneableV2`
  - `sData` public state variable (line 16)
  - `initialize(bytes memory data)` (line 19)
- **Contract `TestCloneableFailure`** (line 30): implements `ICloneableV2`
  - `initialize(bytes memory data)` (line 32)
- **Contract `CloneFactoryCloneTest`** (line 39): inherits `Test`
  - `I_CLONE_FACTORY` immutable (line 42)
  - `constructor()` (line 45)
  - `testCloneBytecode(bytes memory data)` external (line 52)
  - `testCloneInitializeData(bytes memory data)` external (line 63)
  - `testCloneInitializeEvent(bytes memory data)` external (line 72)
  - `testCloneUninitializableFails(address implementation, bytes memory data)` external (line 87)
  - `testCloneInitializeFailureFails(bytes32 notSuccess)` external (line 94)
  - `testZeroImplementationCodeSizeError(address implementation, bytes memory data)` **public** (line 103)
- **Imported errors**: `ZeroImplementationCodeSize`, `InitializationFailed` (line 9)
- **Imported constants**: `ICLONEABLE_V2_SUCCESS` (line 8)

### LibCloneFactoryDeploy.t.sol

- **Contract `LibCloneFactoryDeployTest`** (line 10): inherits `Test`
  - `testDeployAddress()` external (line 11)
  - `testExpectedCodeHash()` external (line 22)
- **Imported libraries**: `LibRainDeploy` (line 6), `LibCloneFactoryDeploy` (line 7), `CloneFactory` (line 8)

---

## Findings

### T01-1 [LOW] Bare `src/` import paths in CloneFactory.t.sol

**File:** `test/src/concrete/CloneFactory.t.sol`, lines 8-9

```solidity
import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "src/interface/ICloneableV2.sol";
import {CloneFactory, ZeroImplementationCodeSize, InitializationFailed} from "src/concrete/CloneFactory.sol";
```

These imports use bare `src/` paths that rely on foundry's implicit `src` directory resolution. The `src/` prefix is not listed in `remappings.txt`. When this repository is consumed as a git submodule by another project, foundry resolves import paths relative to the consuming project's `src` directory, not the submodule's. This breaks compilation.

The source files in `src/` already use relative imports (e.g., `../interface/ICloneableV2.sol`), so the test files are inconsistent with the source file convention.

---

### T01-2 [LOW] Inconsistent function visibility on test function

**File:** `test/src/concrete/CloneFactory.t.sol`, line 103

```solidity
function testZeroImplementationCodeSizeError(address implementation, bytes memory data) public {
```

All other test functions in this contract use `external` visibility (lines 52, 63, 72, 87, 94). This single function uses `public`. There is no reason for `public` since no internal caller invokes it. This is a style inconsistency.

---

### T01-3 [LOW] Bare `vm.expectRevert()` without specific error selector

**File:** `test/src/concrete/CloneFactory.t.sol`, line 88

```solidity
vm.expectRevert();
I_CLONE_FACTORY.clone(implementation, data);
```

The test uses a bare `vm.expectRevert()` without specifying an expected error. This means the test passes on any revert, including reverts from unrelated causes. While the comment on lines 84-86 acknowledges that fuzzed addresses may error for various reasons, the bare expectRevert weakens the test: it cannot distinguish between the intended `ZeroImplementationCodeSize` revert and an unrelated failure path.

At minimum, this test should be split into two paths -- one for zero-code addresses (which should assert `ZeroImplementationCodeSize` as `testZeroImplementationCodeSizeError` already does) and one for addresses with code that fail initialization (which should assert `InitializationFailed`). The current test conflates both cases under a bare revert expectation.

---

### T02-1 [LOW] Bare `src/` import paths in LibCloneFactoryDeploy.t.sol

**File:** `test/src/lib/LibCloneFactoryDeploy.t.sol`, lines 7-8

```solidity
import {LibCloneFactoryDeploy} from "src/lib/LibCloneFactoryDeploy.sol";
import {CloneFactory} from "src/concrete/CloneFactory.sol";
```

Same issue as T01-1. These imports use bare `src/` paths not covered by `remappings.txt`. They will break when the repo is used as a git submodule.
