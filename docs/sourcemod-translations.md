# SourceMod Translations Guide

Esta guia resume como usar el sistema de traducciones de SourceMod en este proyecto.

Base de referencia conceptual:

- AlliedModders Wiki, `Translations (SourceMod Scripting)`

## Conceptos base

- `Languages`: idiomas registrados en `configs/languages.cfg`
- `Phrases`: claves de traduccion
- `Translations`: texto concreto de una phrase para un idioma

Notas importantes:

- los nombres de idioma son sensibles a mayusculas/minusculas
- las `Phrases` tambien son sensibles a mayusculas/minusculas

## Formato de archivo

Los archivos de traduccion usan formato Valve KV y deben tener una raiz `Phrases`.

Ejemplo minimo:

```text
"Phrases"
{
	"Welcome"
	{
		"en"		"Welcome to SourceMod"
		"es"		"Bienvenido a SourceMod"
	}
}
```

Cada phrase:

- tiene un nombre unico
- no debe contener subsecciones arbitrarias
- puede incluir `#format` si necesita reordenar argumentos

## Uso de argumentos

Si todos los idiomas usan el mismo orden, basta con `%s`, `%d`, etc.

Ejemplo simple:

```text
"Phrases"
{
	"NextMap"
	{
		"en"		"Next map: %s"
		"es"		"Siguiente mapa: %s"
	}
}
```

Si el orden de los argumentos cambia entre idiomas, usar `#format`.

Ejemplo:

```text
"Phrases"
{
	"OnFirePlural"
	{
		"#format"	"{1:s},{2:s}"
		"en"		"{1}'s {2} are on fire!"
		"es"		"Los {2} de {1} estan en llamas!"
	}
}
```

Tipos soportados en `#format`:

- `d` o `i`
- `x`
- `f`
- `s`
- `c`
- `t`

Regla importante:

- `%T` no debe usarse dentro del string de traduccion
- `%t` puede aparecer en `#format` si el flujo lo requiere

## Uso desde el plugin

Cada plugin debe cargar sus archivos de traduccion con `LoadTranslations`.

Ejemplo:

```sourcepawn
public void OnPluginStart()
{
	LoadTranslations("l4d2_mission_controller.phrases");
}
```

Si un plugin no llama `LoadTranslations`, las phrases pueden fallar aunque otro plugin ya haya cargado el mismo archivo.

## `%T` y `%t`

### `%T`

Usar `%T` cuando:

- se traduce hacia un cliente especifico
- se traduce hacia `LANG_SERVER`
- se esta dentro de `Format`, `ReplyToCommand`, `PrintToServer`, etc.

Ejemplo:

```sourcepawn
ReplyToCommand(client, "%T %T", "Tag", client, "MCNextMapCurrent", client, mapName);
```

### `%t`

Usar `%t` solo en funciones dirigidas directamente a un cliente, donde SourceMod ya conoce el receptor.

Ejemplo:

```sourcepawn
PrintToChat(client, "[SM] %t", "Hello", name);
```

Regla practica del repo:

- preferir `%T` en helpers y codigo compartido
- usar `%t` solo cuando el flujo es claramente player-directed y simplifica la firma

## Colores dentro de traducciones

En este repo se permite usar tags de `<colors>` dentro de las phrases.

Ejemplo:

```text
"Tag"
{
	"en"		"[{olive}MissionController{default}]"
	"es"		"[{olive}MissionController{default}]"
}
```

Tambien es valido colorear argumentos interpolados:

```text
"MCNextMissionCurrent"
{
	"en"		"Next mission{default}: {olive}%s{default}"
	"es"		"Siguiente mision{default}: {olive}%s{default}"
}
```

Para convenciones de color de L4D2, ver:

- [l4d2-chat-colors-guide.md](/c:/GitHub/AoC-L4D2-Competitive/docs/l4d2-chat-colors-guide.md:1)

## Organizacion recomendada

La documentacion oficial de SourceMod recomienda:

- archivo principal con ingles
- traducciones adicionales en carpetas por idioma, por ejemplo `translations/es/...`

Ejemplo:

```text
translations/stuff.phrases.txt
translations/es/stuff.phrases.txt
```

En este repo hoy existen archivos bilingues `en/es` en un mismo `.phrases.txt`.
Eso es valido y puede mantenerse mientras:

- el archivo siga legible
- las phrases sigan sincronizadas
- no se vuelva dificil revisar cambios

Si un archivo crece demasiado, conviene evaluar separacion por idioma.

## Reglas practicas para este repo

- usar nombres de phrase claros y estables
- no duplicar phrases si solo cambia una palabra; preferir una phrase parametrizada
- usar `#format` cuando cambie el orden semantico entre idiomas
- mantener `en` y `es` en cada cambio
- si una phrase usa colores, que el color tenga sentido semantico en L4D2
- no incrustar logica de negocio compleja en el texto

## Errores comunes

- olvidar `LoadTranslations`
- cambiar el nombre de una phrase en el archivo pero no en el codigo
- usar `%T` dentro de un string de traduccion
- olvidar pasar argumentos requeridos por la phrase
- asumir que el orden de palabras sirve igual en ingles y espanol
- dejar sin color un argumento cuando el resto del archivo ya lo destaca visualmente

## Recomendacion para este proyecto

Cuando una phrase representa salida visible al jugador:

- definir primero el texto en ingles
- escribir la version en espanol en el mismo cambio
- revisar si necesita `#format`
- revisar si necesita colores
- validar que el helper use `%T` o `%t` correctamente segun el contexto

## Resumen corto

- raiz `Phrases`
- cargar siempre con `LoadTranslations`
- `%T` para traduccion explicita por cliente o servidor
- `%t` solo en funciones dirigidas al cliente
- usar `#format` si cambia el orden de argumentos
- mantener `en` y `es` sincronizados
- aplicar la guia de colores de L4D2 cuando haya tags de chat
