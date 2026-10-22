# Aprende: Captura la bandera

Nuevo modo de juego: cada equipo tiene una bandera en **una esquina de su base**. Gana el primero en capturar 3 banderas (o quien lleve más al acabarse el tiempo).

## 1. Las reglas

- **Tomar:** tocas la bandera enemiga y la llevas en la espalda.
- **Capturar:** llegas con ella a la base de **tu** bandera mientras tu bandera está en casa. Tu equipo gana 1 punto y la bandera vuelve a su base.
- **Soltar:** si mueres con la bandera, cae al suelo donde estabas.
- **Regresar:** si un compañero del dueño toca la bandera tirada, vuelve a su base. Si nadie la toca, vuelve sola a los 30 segundos.

Cada cosa sale como aviso en el registro de bajas, arriba a la derecha.

## 2. Dónde está cada cosa

| Archivo | Qué hace |
|---|---|
| `src/shared/Config/Modes.luau` | Reglas del modo `CaptureTheFlag` y qué modo se juega (`selected`) |
| `src/server/Services/FlagService.luau` | Las banderas: el modelo, tomar, soltar, regresar y capturar |
| `src/server/Maps/Builder.luau` | `Builder.flagStand`: la base de la bandera que pone cada mapa |
| `src/server/Services/MatchService.luau` | Elige el modo y suma los puntos |

## 3. Elegir el modo

En `Config/Modes.luau`:

```lua
Modes.selected = "CaptureTheFlag"
```

Pon `"TeamSlayer"`, `"CaptureTheFlag"` o `"Aleatorio"`. Con `"Aleatorio"`, cada partida elige uno de `randomPool`. Si el mapa no tiene bases de bandera, se juega Team Slayer.

## 4. El modelo de la bandera

`buildModel` arma la bandera con tres piezas:
- un **asta** de metal de 9 studs;
- una **tela** del color del equipo;
- una **bola** arriba.

La tela y la bola van soldadas al asta con `WeldConstraint`, así que al mover el asta se mueve todo.

Para llevarla en la espalda, el asta se suelda al torso del jugador. Todas las piezas tienen `Massless = true`, así que no pesan y quien la lleva corre igual.

## 5. ¿Cómo sabe el servidor que tocaste la bandera?

En lugar de usar `Touched`, que a veces falla con piezas rápidas, el servidor revisa 10 veces por segundo la distancia de cada jugador a cada bandera:
- a menos de `pickupRadius` (5 studs), la toma o la regresa;
- a menos de `captureRadius` (6 studs) de tu base, capturas.

## 6. Prueba a cambiar cosas

- Cambia `scoreToWin` de `CaptureTheFlag` a 1 para probar rápido una partida completa.
- Cambia `flagReturnTime` a 10 para que las banderas tiradas vuelvan antes.
- Mueve la base de la bandera de un mapa:
  - El Cruce: `FLAGS` en `Cruce.luau`.
  - Fortines: `half.flagStand` en `Fortines.luau`.
  - Cañón Rojo: `half.flagStand` en `CanonRojo.luau`.
