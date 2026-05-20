# L4D2-Mission-Manager

Repositorio de dos plugins complementarios para Left 4 Dead 2:

- `l4d2_mission_manager`
- `l4d2_mission_controller`

## Resumen

### `l4d2_mission_manager`

Construye y expone una vista estructurada de las campanas y mapas disponibles por gamemode.

Responsabilidades principales:

- descubrir misiones y mapas
- exponer natives para consultar indices, nombres y cantidades
- resolver nombres localizados de campanas y mapas
- soportar mapas custom y exclusiones configurables
- entregar una API reutilizable para otros plugins

### `l4d2_mission_controller`

Usa la informacion del mission manager para decidir y controlar el flujo del siguiente mapa o cambio de campana.

Responsabilidades principales:

- determinar el siguiente mapa efectivo
- aplicar overrides por voto
- anunciar cambios de destino
- automatizar cambios de mapa en distintos modos
- exponer natives para consultar el estado actual del controlador

## Relacion entre ambos

- `l4d2_mission_manager` es la capa de datos y consulta
- `l4d2_mission_controller` es la capa de decision y control de flujo

El controller depende del manager, pero el manager puede ser consumido por otros plugins sin necesidad del controller.

## Build

- `make deps-windows`
- `make deps-linux`
- `make build-windows`
- `make build-linux`
- `make artifact-windows`
- `make artifact-linux`

El artifact final no copia todo `addons/` por defecto.

La seleccion de archivos runtime se define explicitamente en:

- `plugin-package-map.json`

Ese archivo ahora funciona como manifiesto del proyecto:

- `build.plugins`
- `artifact.addons.sourcemod.scripting`
- `artifact.addons.sourcemod.translations`
- `artifact.addons.sourcemod.data`
- `artifact.addons.sourcemod.gamedata`

`build.plugins` se organiza por bucket de salida, por ejemplo:

- `root`

Cada sección de artifact puede declarar una de estas formas:

- `files`
- `dirs`
- `all: true`

`all: true` indica que se copia completo el directorio canonico de esa seccion.

Dentro de `scripting`, la estructura actual es:

- `files`
- `dirs`
- `include`

## Documentacion

- [Sistema de build](docs/build-system.md)
- [Bibliotecas auxiliares](docs/library-dependencies.md)
