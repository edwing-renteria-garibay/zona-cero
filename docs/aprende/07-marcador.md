# Aprende: marcador, registro de bajas y resultados

Ahora la partida se ve en pantalla: arriba al centro el **marcador** con el tiempo, arriba a la derecha el **registro de bajas** ("quién eliminó a quién y con qué") y, al terminar, la **pantalla de resultados**.

## 1. El servidor guarda el estado en atributos

`MatchService.luau` escribe el estado de la partida como **atributos** de `ReplicatedStorage`:

| Atributo | Qué guarda |
|---|---|
| `MatchPhase` | `"Waiting"`, `"Countdown"`, `"Playing"` o `"Ended"` |
| `MatchCountdown` | segundos que faltan para empezar |
| `MatchEndsAt` | cuándo se acaba el tiempo |
| `MatchScoreToWin` | bajas para ganar |
| `MatchPlayersNeeded` | jugadores necesarios para empezar |

Y el marcador de cada equipo es el atributo `Score` de su `Team`.

¿Por qué atributos y no solo un RemoteEvent? Porque los atributos se replican solos y **se quedan**: quien entra a mitad de partida los lee al instante. Un evento solo lo reciben quienes ya estaban conectados.

## 2. El reloj compartido

`MatchEndsAt` se guarda con `workspace:GetServerTimeNow()`, un reloj que el servidor y todos los clientes tienen sincronizado. El cliente calcula lo que falta así:

```lua
local remaining = endsAt - workspace:GetServerTimeNow()
```

Así el servidor no tiene que mandar el tiempo cada segundo.

## 3. Registro de bajas: la causa de la muerte

Para decir "con qué" te eliminaron, cada daño lleva una **causa**:

```lua
HealthService.Damage(humanoid, amount, attacker, cause, headshot)
```

El rifle manda `"AssaultRifle"`, la torreta `"Turret"`, el golpe `"Melee"` o `"Backstab"`, las explosiones `"rocket"` o `"grenade"` y el jeep destruido `"jeep"`. HealthService recuerda la última causa de cada jugador y, al morir, el evento `Killed` la entrega. MatchService la manda a todos con el RemoteEvent `KillFeed`.

En `src/client/UI/KillFeed.luau` la tabla `CAUSES` traduce cada causa a texto. Si muere sin causa (por ejemplo, al caer al vacío) se muestra "Caída".

## 4. Pantalla de resultados

Al terminar, el servidor arma la tabla con `buildResults`: los equipos con su puntaje y los jugadores ordenados por bajas (si empatan, primero quien murió menos). La manda con `MatchState` en estado `"Ended"` y `src/client/UI/Results.luau` la muestra durante `resultsTime` segundos (`Config/Modes.luau`).

## 5. Prueba a cambiar cosas

- En `Config/Modes.luau` cambia `resultsTime` a 5 para ver los resultados menos tiempo.
- En `KillFeed.luau` cambia `MAX_LINES` o `LINE_TIME` para mostrar más líneas o que duren más.
- Agrega un texto nuevo a `CAUSES` para una arma futura.
