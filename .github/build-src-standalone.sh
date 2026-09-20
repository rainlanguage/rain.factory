#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-DCL-1.0
# SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd

# Builds `src/` in a directory holding nothing but `src/` and this repo's
# `foundry.toml`. `dependencies/` and `remappings.txt` are absent here and
# excluded from the published package (`.soldeerignore`), so an import in
# `src/` that is not an intra-repo relative path fails to resolve exactly as it
# would in a consumer that installed `rain-factory`. Copying `foundry.toml`
# rather than writing one keeps solc, EVM version and optimizer identical to
# the repo's own build, so the absent dependency path is the only difference.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="$(mktemp -d)"
trap 'rm -rf "$build_root"' EXIT

cp -r "$root/src" "$build_root/src"
cp "$root/foundry.toml" "$build_root/foundry.toml"

forge build --root "$build_root"
