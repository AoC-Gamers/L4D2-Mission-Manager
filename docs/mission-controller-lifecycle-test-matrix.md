# Mission Controller Lifecycle Test Matrix

Esta matriz sirve para validar que `l4d2_mission_controller` respeta el contrato de lifecycle definido en:

- `docs/l4d2-mode-lifecycle-business-rules.md`
- `docs/l4d2_game_events.json`

Tambien cubre el formato actual de config:

- `addons/sourcemod/data/l4d2_mission_controller.txt`

## Objetivo

Verificar tres cosas por escenario:

- que el modo use la señal canonica correcta
- que el `natural_end` configurado coincida con la politica aplicada
- que el target efectivo respete `target.map` y `target.scope`

## Precondiciones comunes

- `l4d2_mission_controller` cargado
- `l4d2_mission_manager` cargado
- `sm_mc_debug 1`
- config valida bajo `addons/sourcemod/data/l4d2_mission_controller.txt`

## Coop

### Coop finale por `finale_win`

- mapa: `c1m4_atrium`
- modo: `coop`
- config esperada:
  - `target.map = c2m1_highway`
  - `target.scope = campaign`
  - `lifecycle.natural_end = finale_win`
- evento a provocar: `finale_win`
- resultado esperado:
  - se programa cambio a `c2m1_highway`
  - no depende de `map_transition`

### Coop por `map_transition`

- usar una entrada `coop` configurada con `lifecycle.natural_end = map_transition`
- evento a provocar: `map_transition`
- resultado esperado:
  - si el mapa es `effective final` pero no `real final`, se redirige al target configurado

## Versus

### Versus cierre por segunda mitad

- mapa: cualquier entrada `versus`
- modo: `versus`
- config esperada:
  - `lifecycle.natural_end = round_end_second_half`
- eventos a provocar:
  - `versus_round_start`
  - `round_end` primera mitad
  - `round_end` segunda mitad
- resultado esperado:
  - no cambia tras la primera mitad
  - cambia solo cuando `m_bInSecondHalfOfRound` es verdadero

### Versus `competitive finale` exacto en mapa 4

- mapa: campaña de `versus` con al menos 5 mapas
- modo: `versus`
- precondiciones extra:
  - `sm_mc_competitive_finale = 1`
  - `confogl` cargado
  - match mode activo
- verificacion esperada:
  - en mapa 3, `L4D2MC_IsCurrentMapCompetitiveFinale()` devuelve `false`
  - en mapa 4, `L4D2MC_IsCurrentMapCompetitiveFinale()` devuelve `true`
  - en mapa 5, `L4D2MC_IsCurrentMapCompetitiveFinale()` debe seguir devolviendo `false`

## Scavenge

### Scavenge cierre por `scavenge_match_finished`

- mapa: `c1m4_atrium`
- modo: `scavenge`
- config esperada:
  - `target.map = c6m1_riverbank`
  - `target.scope = map`
  - `lifecycle.natural_end = scavenge_match_finished`
- evento a provocar: `scavenge_match_finished`
- resultado esperado:
  - se programa cambio al target configurado
  - no depende de `round_end`

### Scavenge cierre por `scavenge_round_finished`

- usar una entrada `scavenge` configurada con `lifecycle.natural_end = scavenge_round_finished`
- evento a provocar: `scavenge_round_finished`
- resultado esperado:
  - se programa cambio al target configurado
  - `scavenge_match_finished` no debe ser necesario

## Survival

### Survival cierre por `round_end`

- mapa: `c1m1_hotel`
- modo: `survival`
- config esperada:
  - `target.map = c2m1_highway`
  - `target.scope = map`
  - `lifecycle.natural_end = round_end`
- evento a provocar: `round_end`
- resultado esperado:
  - incrementa contador de intentos
  - al llegar al limite, programa cambio al target configurado

## Validacion de config

El plugin ahora debe fallar al cargar si encuentra alguna configuracion invalida en:

- `target.map` vacio
- `target.scope` distinto de `campaign` o `map`
- `lifecycle.natural_end` no permitido para el modo
- seccion `target` faltante
- seccion `lifecycle` faltante

## Señales canónicas esperadas

| Modo | Señal configurada permitida |
|---|---|
| Coop | `finale_win`, `map_transition` |
| Versus | `round_end_second_half` |
| Scavenge | `scavenge_match_finished`, `scavenge_round_finished` |
| Survival | `round_end` |
