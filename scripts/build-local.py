#!/usr/bin/env python3

import argparse
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path


def get_build_plugin_map(manifest: dict) -> dict:
    return manifest.get("build", {}).get("plugins", {})


def get_artifact_manifest(manifest: dict) -> dict:
    return (
        manifest.get("artifact", {})
        .get("addons", {})
        .get("sourcemod", {})
    )


def classify_plugin(plugin_stem: str, plugin_map: dict) -> str | None:
    for bucket, plugin_names in plugin_map.items():
        if plugin_stem in plugin_names:
            return bucket
    return None


def copy_selected_files(names: list[str], source_dir: Path, target_dir: Path, extension: str = "") -> None:
    if not names:
        return
    target_dir.mkdir(parents=True, exist_ok=True)
    for name in names:
        filename = f"{name}{extension}" if extension else name
        source = source_dir / filename
        if not source.exists():
            raise FileNotFoundError(f"Required file not found: {source}")
        shutil.copy2(source, target_dir / filename)


def copy_selected_directories(names: list[str], source_dir: Path, target_dir: Path) -> None:
    if not names:
        return
    target_dir.mkdir(parents=True, exist_ok=True)
    for name in names:
        source = source_dir / name
        if not source.exists():
            raise FileNotFoundError(f"Required directory not found: {source}")
        shutil.copytree(source, target_dir / name, dirs_exist_ok=True)


def copy_manifest_section(section_manifest: dict, source_dir: Path, target_dir: Path, extension: str = "") -> None:
    if section_manifest.get("all", False):
        if not source_dir.exists():
            raise FileNotFoundError(f"Required directory not found: {source_dir}")
        shutil.copytree(source_dir, target_dir, dirs_exist_ok=True)
        return
    copy_selected_files(section_manifest.get("files", []), source_dir, target_dir, extension)
    copy_selected_directories(section_manifest.get("dirs", []), source_dir, target_dir)


def run_spcomp(spcomp: Path, source_file: Path, include_dirs: list[Path], output_file: Path, compile_log: Path) -> None:
    cmd = [str(spcomp), str(source_file)]
    for include_dir in include_dirs:
        cmd.append(f"-i{include_dir}")
    cmd.append(f"-o{output_file}")
    print(f"Compiling {source_file.name} -> addons/sourcemod/plugins/{output_file.name}", flush=True)
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    with compile_log.open("a", encoding="utf-8", newline="") as fh:
        if result.stdout:
            fh.write(result.stdout)
        if result.stderr:
            fh.write(result.stderr)
    if result.returncode != 0:
        raise RuntimeError(f"spcomp failed for {source_file.name}")
    if not output_file.exists():
        raise RuntimeError(f"Expected output file was not generated: {output_file}")


def remove_tree_if_exists(target: Path) -> None:
    if not target.exists():
        return
    last_error = None
    for _ in range(3):
        try:
            shutil.rmtree(target)
            return
        except FileNotFoundError:
            return
        except OSError as exc:
            last_error = exc
            time.sleep(0.2)
    if target.exists() and last_error is not None:
        raise last_error


def detect_default_workspace(root: Path) -> Path | None:
    if root.as_posix().startswith('/mnt/'):
        return Path('/tmp/l4d2-mission-manager-build')
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description='Compile L4D2-Mission-Manager plugins into a local build directory.')
    parser.add_argument('--root', default='.')
    parser.add_argument('--spcomp', required=True)
    parser.add_argument('--output-root', default='build')
    parser.add_argument('--compile-log', required=True)
    parser.add_argument('--workspace', default='')
    args = parser.parse_args()

    root = Path(args.root).resolve()
    spcomp = Path(args.spcomp).resolve()
    spcomp.chmod(spcomp.stat().st_mode | 0o111)
    output_root = (root / args.output_root).resolve()
    compile_log = (root / args.compile_log).resolve()
    workspace = Path(args.workspace).resolve() if args.workspace else detect_default_workspace(root)

    source_mod_include_dir = spcomp.parent / 'include'
    manifest = json.loads((root / 'plugin-package-map.json').read_text(encoding='utf-8'))
    plugin_map = get_build_plugin_map(manifest)
    artifact_manifest = get_artifact_manifest(manifest)
    source_root = root / 'addons' / 'sourcemod'
    scripting_dir = source_root / 'scripting'
    include_dir = scripting_dir / 'include'

    if workspace is not None:
        print(f'Using temporary workspace: {workspace}', flush=True)
        remove_tree_if_exists(workspace)
        workspace.mkdir(parents=True, exist_ok=True)
        workspace_source_root = workspace / 'addons' / 'sourcemod'
        shutil.copytree(source_root, workspace_source_root, dirs_exist_ok=True)
        workspace_spcomp_dir = workspace / 'spcomp'
        workspace_spcomp_dir.mkdir(parents=True, exist_ok=True)
        workspace_spcomp = workspace_spcomp_dir / spcomp.name
        shutil.copy2(spcomp, workspace_spcomp)
        workspace_spcomp.chmod(workspace_spcomp.stat().st_mode | 0o111)
        shutil.copytree(source_mod_include_dir, workspace_spcomp_dir / 'include', dirs_exist_ok=True)
        source_root = workspace_source_root
        scripting_dir = source_root / 'scripting'
        include_dir = scripting_dir / 'include'
        spcomp = workspace_spcomp
        source_mod_include_dir = workspace_spcomp_dir / 'include'

    artifact_root = output_root / 'addons' / 'sourcemod'
    plugins_root = artifact_root / 'plugins'
    remove_tree_if_exists(output_root)
    plugins_root.mkdir(parents=True, exist_ok=True)
    compile_log.parent.mkdir(parents=True, exist_ok=True)
    compile_log.write_text('', encoding='utf-8')

    include_dirs = [include_dir, scripting_dir, source_mod_include_dir]
    for source_file in sorted(scripting_dir.glob('*.sp')):
        bucket = classify_plugin(source_file.stem, plugin_map)
        if bucket is None:
            print(f'Skipping {source_file.name}: no plugin bucket mapping', flush=True)
            continue
        bucket_root = plugins_root if bucket == 'root' else plugins_root / bucket
        bucket_root.mkdir(parents=True, exist_ok=True)
        output_file = bucket_root / f'{source_file.stem}.smx'
        relative_output = output_file.relative_to(artifact_root)
        print(f'Output bucket: addons/sourcemod/{relative_output.parent.as_posix()}', flush=True)
        run_spcomp(spcomp, source_file, include_dirs, output_file, compile_log)

    runtime_root = root / 'addons' / 'sourcemod'
    artifact_scripting_root = artifact_root / 'scripting'
    scripting_manifest = artifact_manifest.get('scripting', {})
    scripting_include_manifest = scripting_manifest.get('include', {})
    translations_manifest = artifact_manifest.get('translations', {})
    data_manifest = artifact_manifest.get('data', {})
    gamedata_manifest = artifact_manifest.get('gamedata', {})

    copy_manifest_section(scripting_manifest, runtime_root / 'scripting', artifact_scripting_root)
    copy_manifest_section(scripting_include_manifest, runtime_root / 'scripting' / 'include', artifact_scripting_root / 'include')
    copy_manifest_section(translations_manifest, runtime_root / 'translations', artifact_root / 'translations')
    copy_manifest_section(data_manifest, runtime_root / 'data', artifact_root / 'data')
    copy_manifest_section(gamedata_manifest, runtime_root / 'gamedata', artifact_root / 'gamedata')

    if workspace is not None and workspace.exists():
        remove_tree_if_exists(workspace)
    print()
    print(f'Build local completed in: {output_root}')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
