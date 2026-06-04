# L4D2 Chat Colors Guide

Esta guía define una convención práctica para usar `<colors>` en plugins de L4D2.

## Contexto

`<colors>` es una librería multi-juego. Eso no significa que todos los tags funcionen igual en L4D2.

La documentación general de AlliedModders recuerda que los colores reales dependen del mod o juego, no solo de SourceMod:

- AlliedModders Wiki, `Scripting FAQ (SourceMod)`: https://wiki.alliedmods.net/index.php?title=Scripting_FAQ_%28SourceMod%29

Además, en discusiones específicas de L4D2 hay dos observaciones relevantes:

- algunos administradores reportan una paleta segura reducida para L4D2
- mezclar dos team-colors en un mismo mensaje puede producir error o comportamiento inválido

Referencias útiles:

- AlliedModders, `[L4D2] Advertisement plugin for Left 4 Dead 2`: https://forums.alliedmods.net/showthread.php?t=327485
- AlliedModders, `[L4D2] pcsWelcome Message`: https://forums.alliedmods.net/showthread.php?t=348160
- AlliedModders, `[INC] Colors (1.0.5)`: https://forums.alliedmods.net/showthread.php?t=96831

## Compatibilidad Observada

Hay dos niveles de compatibilidad que conviene distinguir.

### Colores seguros por defecto

Los más estables para mensajes de sistema son:

- `{default}`
- `{green}`
- `{lightgreen}`
- `{olive}`

Nota importante para L4D2:

- `{yellow}` no debe tratarse como un color independiente confiable
- en la práctica, el valor visual útil es `{olive}`

Por eso, dentro de este repo, cuando se quiera un acento amarillo, se debe usar `{olive}`.

`{olive}` es especialmente útil para tags, porque no depende de equipo.

### Colores de equipo

En L4D2, `red`, `blue` y `teamcolor` deben tratarse como team-colors.

Eso implica:

- `{blue}` puede usarse para supervivientes
- `{red}` puede usarse para infectados
- `{teamcolor}` hereda color de equipo según el autor o contexto

Restricción importante:

- no mezclar `{blue}`, `{red}` y `{teamcolor}` entre sí dentro del mismo mensaje

La librería `colors.inc` también documenta esta limitación de forma general:

- solo puede usarse un team-color por mensaje
- si un color no es soportado por el mod, puede degradarse o reemplazarse

También hay observaciones de la comunidad para L4D2 indicando que `red` y `blue` pueden funcionar, pero siguen sujetos a esa restricción de team-color y a la presencia real de jugadores del equipo correspondiente.

## Regla Base Del Proyecto

- usar `{olive}` para tags
- volver a `{default}` inmediatamente después del tag
- usar `{green}`, `{lightgreen}` o `{olive}` para énfasis neutro
- usar `{blue}` y `{red}` solo cuando la distinción supervivientes/infectados aporte significado real
- no usar `teamcolor` como opción por defecto para mensajes de sistema

## Convención Recomendada

- Tag: `{olive}`
- Texto normal: `{default}`
- Números o valores importantes: `{green}` o `{olive}`
- Supervivientes: `{blue}` cuando aporte contexto real
- Infectados: `{red}` cuando aporte contexto real

## Ejemplos

Tag largo:

```text
[{olive}MissionController{default}]
```

Tag corto:

```text
[{olive}!{default}]
```

Mensaje neutro:

```text
{olive}[MissionController]{default} Next mission: {olive}Dark Carnival{default}.
```

Mensaje con énfasis de equipo:

```text
{olive}[Director]{default} {red}Infected{default} pressure increased.
```

Mensaje con énfasis de supervivientes:

```text
{olive}[Campaign]{default} {blue}Survivors{default} reached the saferoom.
```

## Qué Evitar

- mezclar `{teamcolor}` con `{red}` o `{blue}` en el mismo mensaje
- usar colores de equipo para tags
- abusar de colores en cada palabra
- asumir que todos los tags de `<colors>` son válidos en L4D2
- depender de colores poco probados para mensajes críticos

## Regla Para Este Repo

Para mensajes de sistema:

- usar `{olive}` en el tag
- volver inmediatamente a `{default}`

Para mensajes de estado:

- reservar `{red}` y `{blue}` solo cuando la distinción infectados/supervivientes sea parte del mensaje

Resumen operativo:

- `olive` para identidad del plugin
- `default` para legibilidad
- `green/lightgreen/olive` para énfasis neutro
- `red/blue` como team-color semántico, nunca combinados con otro team-color
