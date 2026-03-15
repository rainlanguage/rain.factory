# Pass 4: Build Warnings

## Command

```
forge build 2>&1
```

## Raw Output

```
Warning: This is a nightly build of Foundry. It is recommended to use the latest stable version. To mute this warning set `FOUNDRY_DISABLE_NIGHTLY_WARNING` in your environment.

Compiling 2 files with Solc 0.8.25
Solc 0.8.25 finished in 508.20ms
Compiler run successful!
```

## Analysis

The Solidity compiler (solc 0.8.25) produced **zero warnings**. The build completed
successfully with no diagnostics.

The only warning present is from the Foundry toolchain itself (nightly build notice),
which is an environment/tooling concern and not a code quality issue.

## Findings

No findings.
