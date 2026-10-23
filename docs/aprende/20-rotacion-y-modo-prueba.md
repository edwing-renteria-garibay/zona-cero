# 20. Rotación de mapas y modo de prueba

## Cada partida en un mapa distinto

Con `selected = "Aleatorio"` en `src/shared/Config/Maps.luau`, el mapa cambia entre partidas:
cuando termina una, el servidor quita el mapa y construye otro distinto. Al empezar cada
partida, el registro de la derecha dice qué mapa y qué modo tocaron.

Si eliges un mapa fijo (por ejemplo `selected = "Cruce"`), se queda siempre ese.

### Cómo funciona

- `MapService.Next()` borra el mapa actual y llama a `MapService.Build()` otra vez. Antes, el
  mapa solo se construía al arrancar el servidor.
- Lo que depende del mapa se vuelve a preparar en `changeMap` (en `init.server.luau`):
  - las plataformas de armas
  - las bases de bandera (para Captura la bandera y Asalto)
  - la colina
  - los jeeps (`VehicleService.Reset()`)
- `MatchService.Run` llama a `changeMap` justo antes de cada partida, menos la primera.

Un mapa hecho a mano en Studio (una carpeta `Map` que ya estaba en Workspace) nunca se borra.

## Modo de prueba

En `src/shared/Config/Modes.luau`:

```lua
Modes.Testing = {
	enabled = true,
	scoreToWin = 2, -- bajas, banderas o bombas para ganar
	hillSeconds = 20, -- Rey de la colina: segundos en la colina para ganar
	timeLimit = 120, -- segundos por partida
	roundTime = 50, -- Asalto: segundos por ronda
}
```

Con `enabled = true`, todas las partidas duran 2 minutos como máximo y se ganan con 2 puntos.
Sirve para recorrer todos los mapas y modos rápido.

**Para jugar normal, cambia `enabled` a `false`.** Así vuelven las metas de cada modo y la meta
según los jugadores.

## Modos en orden

Con `Modes.Testing.inOrder = true`, en modo de prueba los modos ya no salen al azar: van en el
orden de `randomPool`, uno por partida. Así en 11 partidas pasas por todos sin depender de la
suerte. Para probar uno solo, pon su nombre en `Modes.selected` (por ejemplo `"SimiRain"`).
