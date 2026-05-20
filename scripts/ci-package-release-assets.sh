#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
release_dir="$repo_root/dist/release"
artifact_dir="$repo_root/dist/sourcemod/artifact"
: "${RELEASE_BASENAME:?RELEASE_BASENAME is required}"
mkdir -p "$release_dir"
archive_path="$release_dir/${RELEASE_BASENAME}.zip"
rm -f "$archive_path"
export ARCHIVE_PATH="$archive_path"
(
  cd "$artifact_dir"
  python3 - <<'PY'
import os
import zipfile
from pathlib import Path
artifact_dir = Path('.')
archive_path = Path(os.environ['ARCHIVE_PATH'])
with zipfile.ZipFile(archive_path, 'w', compression=zipfile.ZIP_DEFLATED) as zf:
    for path in artifact_dir.rglob('*'):
        if path.is_file():
            zf.write(path, path.as_posix())
PY
)
echo "Release package generated: $archive_path"
