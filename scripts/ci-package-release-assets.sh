#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
: "${RELEASE_BASENAME:?RELEASE_BASENAME is required}"
python3 "$repo_root/scripts/package-release.py" --root "$repo_root" --basename "$RELEASE_BASENAME"
