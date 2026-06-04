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
- resolver nombres localizados de campanas y mapas de forma dinamica
- soportar mapas custom y exclusiones configurables
- entregar una API reutilizable para otros plugins

La localizacion de campanas y capitulos se resuelve en runtime con `campaign_manager` y su `Localizer`, sin depender de `translations/maps.phrases.txt`.

ConVars principales del manager:

- `sm_mm_debug`

Log principal:

- `addons/sourcemod/logs/sm_mm.log`

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

## Mission Controller API

`l4d2_mission_controller` expone una API publica orientada al destino efectivo y al final competitivo de Versus.

Natives actuales:

- `L4D2MC_HasNextMap()`
- `L4D2MC_GetNextMap(char[] mapName, int length)`
- `L4D2MC_GetConfiguredNextMap(char[] mapName, int length)`
- `L4D2MC_HasVoteOverride()`
- `L4D2MC_GetVoteOverrideMap(char[] mapName, int length)`
- `L4D2MC_SetVoteOverrideNextMap(const char[] mapName)`
- `L4D2MC_ClearVoteOverride()`
- `L4D2MC_IsCompetitiveFinaleEnabled()`
- `L4D2MC_WillApplyCompetitiveFinale()`
- `L4D2MC_IsCurrentMapCompetitiveFinale()`
- `L4D2MC_SetCompetitiveFinaleDisabled(bool disabled)`

Forwards actuales:

- `L4D2MC_OnNextMapChanged(const char[] mapName, bool voteOverride)`
- `L4D2MC_OnCompetitiveFinaleChanged(bool enabled, bool active, bool disabled, bool currentMapCompetitiveFinale)`

La declaracion canonica de esta API esta en:

- `addons/sourcemod/scripting/include/l4d2_mission_controller.inc`

## Comandos de Mission Controller

Comando canonico para el final competitivo:

- `sm_mc_finale <off|on|status>`

ConVars principales del controller:

- `sm_mc_debug`
- `sm_mc_competitive_finale`
- `sm_mc_enable_modes`
- `sm_mc_announce`
- `sm_mc_crec_coop_map`
- `sm_mc_crec_coop_final`
- `sm_mc_crec_survival_map`

Log principal:

- `addons/sourcemod/logs/sm_mc.log`

Otros comandos relevantes:

- `sm_mc_menu`
- `sm_mc_vote`
- `sm_mc_extend`
- `sm_mc_next`
- `sm_mc_help`

## Build

- `make deps-smx`
- `make build-smx`
- `make package-smx`
- `make release`

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

El flujo actual separa claramente:

- dependencias de compilacion (`deps-smx`)
- compilacion (`build-smx`)
- empaquetado del arbol runtime (`package-smx`)
- generacion del ZIP final (`release`)

## Documentacion

- [Sistema de build](docs/build-system.md)
- [Bibliotecas auxiliares](docs/library-dependencies.md)
