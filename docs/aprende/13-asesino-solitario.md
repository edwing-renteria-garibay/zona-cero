# 13 · Asesino en solitario

Todos contra todos: no hay equipos y gana el primer jugador que llegue a **30 bajas**
en 10 minutos. Si nadie llega a tiempo, la partida termina en "Empate", igual que en los otros modos.

Desde esta versión el modo y el mapa vienen en **aleatorio**: cada partida elige uno de los
cuatro modos (Asesino por equipos, Asesino en solitario, Captura la bandera y Rey de la
colina), y cada servidor elige uno de los tres mapas al arrancar.

## Dónde está

- Reglas: `src/shared/Config/Modes.luau`, en `FreeForAll`. `scoreToWin = 30` son las bajas
  para ganar; `teams = false` es lo que lo hace "en solitario".
- Lógica: `src/server/Services/MatchService.luau`.
- Marcador: `src/client/UI/Scoreboard.luau`.

## Cómo se quitan los equipos

Al empezar la partida, `applyTeams(rules)`:

1. Pone `player.Team = nil` y `player.Neutral = true` a cada jugador: así nadie tiene equipo
   y todos le pueden hacer daño a todos (las armas ya revisaban `Neutral`).
2. Marca todos los `SpawnLocation` del mapa como `Neutral = true`: un punto de aparición
   neutral sirve para cualquier jugador.
3. Apaga `AutoAssignable` de los equipos para que quien entre a mitad de partida tampoco
   tenga equipo.

Cuando la siguiente partida es por equipos, todo se regresa y cada jugador va al equipo
que tenga menos gente.

## Reaparecer al azar

Como nadie tiene base, `MatchService.SetupCharacter` mueve a cada personaje que aparece:

1. Junta las posiciones de los demás jugadores vivos.
2. Revisa los 8 puntos de aparición del mapa (de las dos bases).
3. Se queda con los que no tienen a nadie a menos de `SAFE_SPAWN_DISTANCE` (40 studs) y
   elige uno **al azar**.
4. Si todos tienen a alguien cerca, usa el que esté más lejos de todos.

`character:PivotTo(...)` es lo que mueve el modelo completo del personaje.

## Lo que cambia en pantalla

- Marcador: a la izquierda (gris) tus bajas, a la derecha (dorado) las del que va ganando.
- Brazaletes: sin equipo no se ven.
- Resultados: "¡Gana *jugador*!" en dorado, y la tabla de bajas y muertes.

## Para probar

En `Modes.luau` pon `Modes.selected = "FreeForAll"` (luego regrésalo a `"Aleatorio"`).
Abre **Servidor y clientes** con 2 jugadores, mátense entre ustedes y revisa que cada uno
reaparezca en lugares distintos. Para no esperar 30 bajas, baja `scoreToWin` a 3 mientras
pruebas.
