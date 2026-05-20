#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
echo "Resolving Linux SourceMod dependencies through make..."
make deps-linux
echo "Building Linux artifact through make..."
make artifact-linux
