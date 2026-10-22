# Aprende: Rey de la colina con colina al azar

En casi todos los juegos la colina está en el centro. Aquí aparece en **un lugar al azar** del mapa y se mueve cada 60 segundos. Siempre queda en un lugar al que los dos equipos pueden llegar caminando.

## 1. Las reglas

- Cada segundo que **solo tu equipo** está dentro de la colina, ganas 1 punto.
- Si hay jugadores de los dos equipos, la colina está **en disputa** (naranja) y nadie suma.
- Gana el primero en llegar a 120 puntos, o quien tenga más al acabarse el tiempo.
- La colina se ve como un cilindro brillante. Su letrero **COLINA** se ve a través de las paredes y cambia al color del equipo que la tiene.

## 2. ¿Cómo elige el lugar?

`HillService.luau` prueba lugares al azar dentro del mapa hasta encontrar uno que cumpla:

1. **Piso plano y abierto.** Lanza un rayo hacia abajo en el centro y 8 más alrededor de la orilla, a `hillRadius` de distancia. Todos deben chocar con piso a la misma altura, así la colina no queda pegada a un muro ni encima de una columna.
2. **Lejos de los spawns.** Debe quedar a más de `minSpawnDistance` (40 studs) de cualquier punto de aparición.
3. **Se puede llegar.** `PathfindingService` busca un camino caminando desde un spawn de cada equipo. Si no hay camino (por ejemplo, encima de un muro o de un techo), el lugar no sirve.

Si en 60 intentos no encuentra nada, la pone en el centro.

## 3. Elegir el modo

En `src/shared/Config/Modes.luau`:

```lua
Modes.selected = "KingOfTheHill"
```

Con `"Aleatorio"`, cada partida elige uno de `randomPool`: Team Slayer, Captura la bandera o Rey de la colina.

## 4. Prueba a cambiar cosas

En `KingOfTheHill` (`Config/Modes.luau`):

- `moveEvery = 0`: la colina no se mueve en toda la partida.
- `moveEvery = 30`: se mueve más seguido.
- `hillRadius = 12`: una colina más grande.
- `scoreToWin = 30`: para probar rápido.
