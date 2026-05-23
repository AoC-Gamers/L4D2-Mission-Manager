# Bibliotecas Auxiliares

## Objetivo

Este documento explica por que el repositorio incluye mas bibliotecas de las que parecen necesarias a primera vista.

Los plugins principales son solo dos:

- `l4d2_mission_manager`
- `l4d2_mission_controller`

Pero ambos dependen de varias bibliotecas locales para compilar y para exponer una API publica consistente.

## Bibliotecas usadas directamente

### `campaign_manager.inc`

Se usa para resolver nombres de campanas y capitulos de forma dinamica.

Aporta:

- extraccion de codigos de campana y mapa
- generacion de translation keys de Valve
- resolucion localizada por cliente
- fallback controlado para mapas o campanas desconocidas

Este repositorio usa esta biblioteca como fuente principal de localizacion para el mission manager, asi que ya no depende de `translations/maps.phrases.txt` para resolver nombres de campanas o capitulos.

### `l4d2_mission_manager.inc`

Contrato publico del mission manager.

Aporta:

- natives para consultar misiones, mapas e IDs
- forward de actualizacion de lista
- superficie API para consumidores externos

### `l4d2_mission_controller.inc`

Contrato publico del mission controller.

Aporta:

- natives para leer el siguiente mapa
- manejo de vote override
- forward cuando cambia el destino efectivo

### `left4dhooks.inc`

Se usa para integracion con estado y gamemode de L4D2.

### `builtinvotes.inc`

Se usa en el mission controller para votos integrados del juego.

### `colors.inc`

Se usa para mensajes de chat coloreados en el controller.

### `l4d2_changelevel.inc`

Se usa como dependencia opcional en el controller para interoperar con un plugin externo de cambio de mapa.

## Bibliotecas usadas indirectamente

### `language_manager.inc`

Necesaria por `campaign_manager.inc`.

Aporta helpers para obtener traducciones Valve y manejar idioma de cliente/servidor.

### `localizer.inc`

Necesaria por `campaign_manager.inc`.

Aporta cache y acceso a traducciones del juego para resolucion dinamica de nombres en runtime.

### `left4dhooks_stocks.inc`

No se incluye directamente desde los plugins principales, pero forma parte de la cadena de `left4dhooks` local usada por este repo.

### `left4dhooks_anim.inc`
### `left4dhooks_lux_library.inc`
### `left4dhooks_silver.inc`

Se conservan porque forman parte del paquete local de `left4dhooks` que este repo distribuye para compilar de manera autocontenida.

### `builtinvotes_stocks.inc`

Se conserva porque `builtinvotes.inc` la incluye explicitamente.

## Criterio de inclusion

Este repositorio intenta seguir este criterio:

- incluir contratos publicos propios
- incluir dependencias locales necesarias para compilar de forma autocontenida
- excluir bibliotecas que no participan en el build ni en la API real del modulo
