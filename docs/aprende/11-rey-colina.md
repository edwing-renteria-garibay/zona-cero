# Aprende: Rey de la colina con colina al azar

En casi todos los juegos la colina está en el centro. Aquí aparece en **un lugar al azar** del mapa y se mueve cada 60 segundos. Siempre queda en un lugar al que los dos equipos pueden llegar caminando.

## 1. Las reglas

- Cada segundo que **solo tu equipo** está dentro de la colina, ganas 1 punto.
- Si hay jugadores de los dos equipos, la colina está **en disputa** (naranja) y nadie suma.
- Gana el primero en llegar a 120 puntos, o quien tenga más al acabarse el tiempo.
- La colina se ve como un cilindro brillante. Su letrero **COLINA** se ve a través de las paredes y cambia al color del equipo que la tiene.

## 2. ¿Cómo elige el lugar?

`HillService.luau` prueba lugares al azar dentro del mapa hasta encontrar uno que cumpla:

1. **Piso plano y abierto, al aire libre o en un túnel.** Busca todos los pisos que hay en ese punto, de arriba hacia abajo, así también encuentra los de dentro de los túneles. Luego revisa:
   - que haya espacio para estar de pie;
   - que hacia los 8 lados no haya un muro cerca;
   - que el piso siga a la misma altura.

   La colina puede rozar paredes. Quien esté del otro lado de un muro no cuenta como dentro.
2. **Lejos de los spawns.** Debe quedar a más de `minSpawnDistance` (40 studs) de cualquier punto de aparición.
3. **Se puede llegar.** `PathfindingService` busca un camino caminando desde un spawn de cada equipo. Si no hay camino (por ejemplo, encima de un muro o de un techo), el lugar no sirve.

4. **En otra zona.** Al moverse, el nuevo lugar debe quedar a más de `minMoveDistance` (120 studs) de los últimos `rememberSpots` (2) lugares de la colina. Así, si salió en el cuarto este, la siguiente sale en otro lado del mapa.

Si en 150 intentos no encuentra nada, la pone en el centro.

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
- `hillRadius = 20`: una colina todavía más grande (hoy mide 16 de radio).
- `scoreToWin = 30`: para probar rápido.
