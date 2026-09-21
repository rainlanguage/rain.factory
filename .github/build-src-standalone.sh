#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-DCL-1.0
# SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd

# Builds `src/` in a directory holding nothing but `src/` and this repo's
# `foundry.toml`, so an import a consumer of the published package could not
# resolve fails here.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="$(mktemp -d)"
trap 'rm -rf "$build_root"' EXIT

cp -r "$root/src" "$build_root/src"
cp "$root/foundry.toml" "$build_root/foundry.toml"

forge build --root "$build_root"
