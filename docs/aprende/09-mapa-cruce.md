# Aprende: el mapa El Cruce y los mapas dibujados con letras

**El Cruce** es el tercer mapa, inspirado en **Rat Race** de Halo CE. Mide unos 360 × 300 studs.

- La **base Azul** está en lo alto, al noroeste (14 studs).
- De la base Azul bajan **tres rampas**: una al cuarto oeste, un pasillo largo al cuarto este y un túnel hacia el centro.
- En medio hay **muros y túneles techados** que cruzan de lado a lado, así que no hay líneas de tiro largas.
- La **base Roja** es el cuarto grande del sur, con columnas.

## 1. El plano es texto

Abre `src/server/Maps/Cruce.luau` y busca `PLAN`. Cada letra es una celda de 5 × 5 studs:

| Letra | Qué es |
|---|---|
| `#` | muro (32 studs) |
| `.` | piso de abajo |
| `t` | túnel: piso con techo a 12 studs |
| `^` | piso alto (base Azul, 14 studs) |
| `R` / `r` | rampa al aire libre / dentro de un túnel |
| `P` / `p` | columna en el piso de abajo / en el piso alto |

El norte está arriba. Si cambias una letra, el mapa cambia la próxima vez que pruebes con F7. Por ejemplo:
- Pon `t` en lugar de `.` para techar un pasillo.
- Pon `#` para cerrar un paso.
- Pon `P` para agregar una columna.

## 2. De letras a piezas

Crear una pieza por celda daría miles de piezas. La función `rectangles` junta las celdas iguales que están una al lado de la otra en rectángulos grandes, y `fill` crea un bloque por rectángulo. Así el mapa usa unas 200 piezas.

## 3. Las rampas

Una rampa no se puede dibujar solo con letras, porque hay que saber hacia dónde sube. Por eso está en la tabla `RAMPS`:

```lua
{ rows = { 20, 27 }, columns = { 2, 12 }, high = "N", tunnel = false },
```

Quiere decir que de la fila 20 a la 27 y de la columna 2 a la 12 hay una rampa que sube hacia el norte (`N`, `S`, `E` u `O`). Si `tunnel` es `true`, también lleva un techo inclinado. El lado alto debe tocar el piso `^`, y el bajo, piso `.` o `t`.

## 4. Techos macizos

El techo de un túnel no es una losa delgada: es un bloque que llega hasta lo alto de los muros. Así nadie puede caminar encima de los túneles desde la base alta.

## 5. Prueba a cambiar cosas

- Cambia `HIGH` a 18 para subir la base Azul (las rampas se ajustan solas).
- Cambia `TUNNEL_HEIGHT` a 10 para túneles más bajos.
- Mueve un punto de aparición en `SPAWNS` o las granadas en `GRENADES` (son `{fila, columna}` de `PLAN`).
