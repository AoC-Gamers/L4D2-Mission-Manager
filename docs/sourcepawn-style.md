# SourcePawn Style Guide

Esta guia resume la convencion recomendada para este proyecto.
El objetivo es mantener los plugins legibles, consistentes y sin ruido innecesario en el compilador.

## Principios

- Priorizar nombres claros sobre hungarian notation completa.
- Mantener prefijos solo cuando aportan contexto real.
- Evitar prefijos de tipo en variables locales si el tipo ya es evidente en la declaracion.
- Reutilizar helpers comunes antes de duplicar validaciones o flujos.

## Prefijos recomendados

- `g_` para estado global.
- `g_b...` para booleanos globales.
- `g_cv...` para `ConVar` globales.
- `g_h...` para `Handle` globales.
- `g_kv...` para `KeyValues` globales.
- `b...` para funciones que retornan `bool`.
- `v...` para funciones `void` si ya se usa ese patron en el archivo.
- `e...` solo para funciones que retornan un enum, no para variables locales.
- `On...` para callbacks y entry points del plugin.
- `Handle...` para handlers de menu u otras callbacks internas.
- `Show...` o `vShow...` para helpers de presentacion, segun la convencion ya establecida en el archivo.

## Lo que conviene evitar

- No usar hungarian notation completa en parametros y locales.
- Evitar nombres como `eVoteType`, `eAccessType`, `iClient`, `sConfig` cuando el tipo ya se ve en la firma.
- No mezclar demasiadas convenciones en una sola funcion.

## Reglas practicas

### Globales

Usar prefijos porque ayudan a distinguir estado compartido del estado local.

```sourcepawn
ConVar g_cvEnabled;
bool g_bConfogl;
Handle g_hVote;
KeyValues g_kvModesKV;
```

### Variables locales y parametros

Preferir nombres simples y descriptivos.

```sourcepawn
MatchVoteType voteType
MatchVoteAccessType accessType
char configName[64]
int client
```

Evitar esto salvo que el archivo completo ya siga esa escuela de forma estricta.

```sourcepawn
MatchVoteType eVoteType
MatchVoteAccessType eAccessType
char sConfigName[64]
int iClient
```

### Funciones booleanas

Si retorna `bool`, usar prefijo `b`.

```sourcepawn
bool bCanHandleClientCommand(int client, const char[] context)
bool bFindConfigName(const char[] config, char[] name, int maxlen)
bool bStartMatchVote(int client, const char[] configName)
```

### Funciones void

Si el archivo ya usa el patron `v`, mantenerlo de forma consistente.

```sourcepawn
void vDisplayMatchModeMenu(int client, MatchVoteType voteType)
void vLoadTranslation(const char[] translation)
```

Si la funcion expresa una accion concreta de UI, tambien es valido usar un nombre por intencion.

```sourcepawn
void vShowLoadMatchModeMenu(int client)
void vShowChangeMatchModeMenu(int client)
```

### Callbacks y handlers

En callbacks conviene priorizar nombres por rol antes que por tipo de retorno.

```sourcepawn
Action OnMatchRequest(int client, int args)
Action OnMatchReset(int client, int args)
Action OnQuitCommand(int client, const char[] command, int argc)

int HandleLoadModeMenu(Menu menu, MenuAction action, int client, int item)
int HandleChangeConfigMenu(Menu menu, MenuAction action, int client, int item)
```

Evitar nombres centrados solo en el tipo si describen peor la responsabilidad.

```sourcepawn
Action aMatchReset(int client, int args)
int iChConfigsMenuHandler(Menu menu, MenuAction action, int client, int item)
```

### Funciones que retornan enums

Usar prefijo `e` en la funcion, no en la variable local.

```sourcepawn
MatchVoteType eResolveCommandVoteType(MatchVoteType requestedType, const char[] context)

MatchVoteType voteType = eResolveCommandVoteType(MatchVote_Load, "aMatchRequest");
```

## Recomendacion para enums

- El tipo del enum debe cargar el contexto semantico.
- La variable local no necesita repetirlo con prefijo hungaro.

```sourcepawn
enum MatchVoteType
{
    MatchVote_Load = 0,
    MatchVote_Change,
    MatchVote_Reset
}
```

Correcto:

```sourcepawn
MatchVoteType voteType
```

Menos recomendable:

```sourcepawn
MatchVoteType eVoteType
```

## Flujos y helpers

- Si dos comandos comparten validaciones, extraer un helper.
- Si menu y comando directo hacen lo mismo, intentar que ambos lleguen al mismo helper interno.
- Resolver una config una sola vez por flujo cuando sea posible.

## Regla de consistencia

Si un archivo viejo ya usa una convencion distinta, no reescribir todo por estilo.
Aplicar la guia al codigo nuevo o a las zonas que ya se estan refactorizando.

## Resumen corto

- Mantener `g_` en globales.
- Mantener `b...` para bool.
- Mantener `v...` para void si el archivo ya lo usa.
- Usar `e...` solo en funciones que retornan enums.
- Usar `On...` y `Handle...` en callbacks cuando describen mejor el rol de la funcion.
- Evitar hungarian notation completa en variables locales.
- Preferir nombres descriptivos y helpers compartidos.
