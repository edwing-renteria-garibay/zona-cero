# 18. Meta de bajas según los jugadores

En Asesino por equipos, SWAT y SWAT explosivo la meta ya no es siempre 50 bajas: depende de
cuántos jugadores hay cuando empieza la partida.

| Jugadores al empezar | Meta |
| --- | --- |
| 10 o menos | 25 |
| 15 | 30 |
| 20 | 40 |
| 25 | 45 |
| 30 o más | 50 |

## Dónde se configura

En `src/shared/Config/Modes.luau` cada uno de esos modos tiene dos valores:

```lua
scoreToWin = 50, -- con muchos jugadores
minScoreToWin = 25, -- con pocos jugadores
```

Y en `Modes.Common` está cuántos jugadores son "pocos" y cuántos "muchos":

```lua
scaleScore = { lowPlayers = 10, highPlayers = 30 },
```

Si un modo no tiene `minScoreToWin`, su meta es siempre `scoreToWin` (por ejemplo, Asesino en
solitario se queda en 30). Si quieres que otro modo también se ajuste, solo agrégale
`minScoreToWin`.

## Cómo se calcula

En `MatchService` la función `scoreGoal` hace una regla de tres:

1. Calcula qué tan lleno está el servidor entre `lowPlayers` y `highPlayers`, como un número de
   0 a 1. `math.clamp` lo deja dentro de ese rango, así que 4 jugadores cuentan como 0 y 40
   como 1.
2. Recorre esa misma fracción entre `minScoreToWin` y `scoreToWin`.
3. Redondea de 5 en 5 para que la meta sea un número bonito.

La meta se fija al empezar y no cambia si alguien entra o sale a mitad de partida. El marcador
muestra la meta real.

Para no modificar la configuración original, `MatchService` trabaja con una copia de las reglas
(`table.clone`), y a esa copia le pone la meta calculada.
