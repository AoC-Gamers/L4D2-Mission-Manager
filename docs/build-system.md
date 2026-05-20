# Sistema de Build

## Objetivo

Este repositorio usa el mismo enfoque de build local y CI aplicado en otros repos de SourceMod del stack de AoC:

- mismo flujo logico para local y CI
- mismo script Python para Windows y Linux
- `make` como interfaz corta
- soporte automatico para WSL cuando el repo vive bajo `/mnt/`

## Archivos principales

- `Makefile`
- `plugin-package-map.json`
- `scripts/fetch-sourcemod.py`
- `scripts/build-local.py`
- `scripts/stage-artifact.py`
- `scripts/ci-build-sourcemod.sh`
- `scripts/ci-validate-artifact.sh`
- `scripts/ci-package-release-assets.sh`
- `.github/workflows/sourcemod-build.yml`

## Targets

- `make deps-windows`
- `make deps-linux`
- `make build-windows`
- `make build-linux`
- `make artifact-windows`
- `make artifact-linux`
- `make clean`
- `make clean-all`

## Layout

Los binarios compilados quedan en la raiz de:

- `addons/sourcemod/plugins/`

Actualmente el repo compila:

- `l4d2_mission_controller.sp`
- `l4d2_mission_manager.sp`

## WSL

Si el repositorio esta bajo `/mnt/`, `build-local.py` usa automaticamente un workspace temporal Linux para evitar la penalizacion de I/O tipica de WSL sobre discos montados de Windows.

## CI

El workflow usa tres etapas logicas en un solo job:

- deps
- build
- artifact

Y publica:

- artifact temporal de Actions
- release asset persistente en `channel/latest` y `channel/develop`
