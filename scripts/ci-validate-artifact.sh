#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
artifact_dir="$repo_root/dist/sourcemod/artifact"
[[ -d "$artifact_dir/addons/sourcemod/plugins" ]] || { echo "Missing plugins directory" >&2; exit 1; }
[[ -f "$artifact_dir/addons/sourcemod/plugins/l4d2_mission_controller.smx" ]] || { echo "Missing l4d2_mission_controller.smx" >&2; exit 1; }
[[ -f "$artifact_dir/addons/sourcemod/plugins/l4d2_mission_manager.smx" ]] || { echo "Missing l4d2_mission_manager.smx" >&2; exit 1; }
[[ -f "$artifact_dir/compile.log" ]] || { echo "Missing compile.log" >&2; exit 1; }
echo "Artifact validation passed: $artifact_dir"
