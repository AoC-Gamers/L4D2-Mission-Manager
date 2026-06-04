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
- `scripts/package-release.py`
- `scripts/ci-build-sourcemod.sh`
- `scripts/ci-validate-artifact.sh`
- `scripts/ci-package-release-assets.sh`
- `.github/workflows/sourcemod-build.yml`

## Targets

- `make deps-smx`
- `make build-smx`
- `make package-smx`
- `make release`
- `make clean`
- `make clean-all`

## Layout

Los binarios compilados quedan en la raiz de:

- `addons/sourcemod/plugins/`

Actualmente el repo compila:

- `l4d2_mission_controller.sp`
- `l4d2_mission_manager.sp`

## Seleccion explicita de runtime

`plugin-package-map.json` no solo define que plugins se compilan.

Tambien define que archivos se copian al artifact final:

- `build.plugins`
- `artifact.addons.sourcemod.scripting.files`
- `artifact.addons.sourcemod.scripting.dirs`
- `artifact.addons.sourcemod.scripting.include`
- `artifact.addons.sourcemod.translations`
- `artifact.addons.sourcemod.data`
- `artifact.addons.sourcemod.gamedata`

Eso permite que el artifact publique solo los archivos realmente necesarios para este bundle, en vez de copiar todo `addons/sourcemod/`.

`build.plugins` se define por bucket de salida. Aunque hoy solo exista `root`, el formato ya soporta subdirectorios futuros bajo `plugins/`.

Cada seccion del artifact puede usar:

- `files`
- `dirs`
- `all: true`

`all: true` significa copiar completo el directorio canonico representado por esa seccion. En este repo se usa para:

- `translations`
- `data`
- `gamedata`

La separacion de `scripting` sigue la estructura canonica real del proyecto:

- `files`: archivos `.sp` raiz
- `dirs`: subdirectorios auxiliares usados por esos plugins
- `include`: contratos publicos y dependencias locales del bundle

## WSL

Si el repositorio esta bajo `/mnt/`, `build-local.py` usa automaticamente un workspace temporal Linux para evitar la penalizacion de I/O tipica de WSL sobre discos montados de Windows.

## CI

El workflow separa el camino `smx` en jobs explicitos:

- `deps-smx`
- `build-smx`
- `release`

Eso deja el flujo local y el de CI alineados sobre el mismo modelo:

- resolver dependencias
- compilar
- preparar el arbol runtime
- generar el ZIP final

Y publica:

- artifact temporal de Actions
- release asset persistente en `channel/latest` y `channel/develop`
