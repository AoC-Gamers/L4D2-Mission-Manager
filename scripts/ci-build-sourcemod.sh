#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
echo "Resolving SourceMod dependencies through make..."
make deps-smx
echo "Building SMX through make..."
make build-smx
echo "Packaging SMX tree through make..."
make package-smx
