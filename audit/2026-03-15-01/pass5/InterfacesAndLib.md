# Pass 5 - Correctness / Intent Verification

## Scope

| Agent | File |
|-------|------|
| A04 | `src/interface/ICloneableV2.sol` |
| A08 | `src/lib/LibCloneFactoryDeploy.sol` |
| Test | `test/src/lib/LibCloneFactoryDeploy.t.sol` |
| A01 | `script/Deploy.sol` |

## Evidence of Thorough Reading

### A04: `src/interface/ICloneableV2.sol` (49 lines)

- File-level constant: `ICLONEABLE_V2_SUCCESS` (line 7) = `keccak256("ICloneableV2.initialize")`
- Interface: `ICloneableV2` (line 11)
- Error: `InitializeSignatureFn()` (line 13)
- Function: `initialize(bytes calldata data) external returns (bytes32 success)` (line 48)
- NatSpec (lines 15-47): describes initialize semantics, overloaded signature pattern, success return value

### A08: `src/lib/LibCloneFactoryDeploy.sol` (22 lines)

- Library: `LibCloneFactoryDeploy` (line 11)
- Constant: `CLONE_FACTORY_DEPLOYED_ADDRESS` (line 14) = `0x444acC29d63fa643E8adCC35FD9aa6DE111dCb39`
- Constant: `CLONE_FACTORY_DEPLOYED_CODEHASH` (lines 20-21) = `0xf21b813c7075a1621285df3a8369d0652c31ea80cb807be1aaadafeecd134475`

### Test: `test/src/lib/LibCloneFactoryDeploy.t.sol` (27 lines)

- Contract: `LibCloneFactoryDeployTest` (line 10)
- Function: `testDeployAddress()` (line 11) - forks ETH, deploys via Zoltu, asserts address and codehash match constants
- Function: `testExpectedCodeHash()` (line 22) - deploys CloneFactory locally, asserts codehash matches constant

### A01: `script/Deploy.sol` (27 lines)

- Contract: `Deploy` (line 12)
- Function: `run()` (line 13) - reads DEPLOYMENT_KEY, calls `deployAndBroadcastToSupportedNetworks`

## Correctness Verification

### 1. `ICLONEABLE_V2_SUCCESS` matches documented meaning

**Verified correct.** The constant on line 7 is `keccak256("ICloneableV2.initialize")`. The NatSpec on line 39 states it should be "the keccak256 hash of the string 'ICloneableV2.initialize'". The `@return` on line 47 repeats this. The `CloneFactory.clone()` at line 39 of `CloneFactory.sol` checks `ICloneableV2(child).initialize(data) != ICLONEABLE_V2_SUCCESS`. All uses are consistent.

Verified independently: `cast keccak "ICloneableV2.initialize"` = `0xe0e57eda3f08f2a93bbe980d3df7f9c315eac41181f58b865a13d917fe769fc3`.

### 2. `InitializeSignatureFn` serves documented purpose

**Verified correct.** NatSpec on line 12 says "Overloaded initialize function MUST revert with this error." Lines 30-32 elaborate: typed overloaded `initialize` functions exist only for ABI discoverability and MUST always revert with this error to prevent accidental calls. The error serves as a sentinel for misrouted calls. Intent and declaration are aligned.

### 3. Constants in `LibCloneFactoryDeploy` match deploy script and tests

**Verified correct.**
- `Deploy.run()` passes both `CLONE_FACTORY_DEPLOYED_ADDRESS` (line 22) and `CLONE_FACTORY_DEPLOYED_CODEHASH` (line 23) to `deployAndBroadcastToSupportedNetworks`.
- `testDeployAddress()` asserts the Zoltu-deployed address matches `CLONE_FACTORY_DEPLOYED_ADDRESS` (line 16) and the codehash matches `CLONE_FACTORY_DEPLOYED_CODEHASH` (line 19).
- `testExpectedCodeHash()` asserts a locally-deployed `CloneFactory` codehash matches `CLONE_FACTORY_DEPLOYED_CODEHASH` (line 25).
- All three consumers reference the same constants from the same library. Consistent.

### 4. Tests verify what their names claim

**Verified correct.**
- `testDeployAddress`: Tests that Zoltu deployment produces the expected address AND codehash AND that code exists at the address. The name focuses on address but the test is more comprehensive (also covers codehash). This is not a defect.
- `testExpectedCodeHash`: Tests that a locally-deployed CloneFactory has the expected codehash. Name and behavior align.

### 5. `Deploy.run()` correctly uses referenced constants

**Verified mostly correct.** The function reads a deployer private key, constructs the supported networks list, and calls `deployAndBroadcastToSupportedNetworks` with `type(CloneFactory).creationCode`, the expected address, and expected codehash. The deployment logic itself is correct.

One issue: the `contractPath` parameter is passed as `""` (empty string). In `LibRainDeploy.deployAndBroadcastToSupportedNetworks` (line 141), this parameter is used to construct a `forge verify-contract` command logged for manual verification. An empty string produces a malformed command missing the contract identifier. See finding A01-2.

## Findings

### A01-2 [LOW] Empty `contractPath` produces malformed verification command

**File:** `script/Deploy.sol`, line 21

**Description:** `Deploy.run()` passes `""` as the `contractPath` argument to `deployAndBroadcastToSupportedNetworks`. The `LibRainDeploy` library uses this value at line 141 to construct a `forge verify-contract` command that is logged for operators to run manually. With an empty string, the logged command will be:

```
forge verify-contract --chain arbitrum 0x444acC29d63fa643E8adCC35FD9aa6DE111dCb39
```

This is missing the required contract path argument (e.g., `src/concrete/CloneFactory.sol:CloneFactory`), making it a broken command that will fail if copy-pasted.

**Impact:** Operators following the deployment log output will get a non-functional verification command. Deployment correctness is unaffected since `contractPath` is only used for the log message, not for any deployment logic. However, this could delay post-deployment verification if operators rely on the logged command.

**Recommendation:** Pass the correct contract path, e.g., `"src/concrete/CloneFactory.sol:CloneFactory"`.

## Summary

| ID | Severity | Title | File |
|----|----------|-------|------|
| A01-2 | LOW | Empty `contractPath` produces malformed verification command | `script/Deploy.sol` |

No CRITICAL, HIGH, or MEDIUM findings. All correctness checks pass. Constants, interfaces, tests, and deploy script are aligned in intent and implementation.
