# Aprende: el mapa El Cruce y los mapas dibujados con letras

**El Cruce** es el tercer mapa, inspirado en un mapa de Halo CE (unos 220 × 205 studs). Tiene cuatro zonas en las orillas unidas por pasillos y, en medio, un **abismo** con una plataforma alta y tres puentes en forma de Y. En lugar de teletransportes hay un **corredor de afuera** (oeste, sur y este) para flanquear.

## 1. El plano es texto

Abre `src/server/Maps/Cruce.luau` y busca `PLAN`. Cada letra es una celda de 5 × 5 studs:

| Letra | Qué es |
|---|---|
| `#` | muro alto (20 studs), no se puede subir |
| `.` | piso |
| `P` | pilar de 8 studs para cubrirse |
| `o` | abismo: si caes, mueres |

El norte está arriba. Si cambias una letra, el mapa cambia la próxima vez que pruebes con F7. Por ejemplo, pon una `P` en medio de un cuarto para agregar una cobertura, o cambia `.` por `#` para cerrar un pasillo.

## 2. De letras a piezas

Crear una pieza por celda daría miles de piezas. La función `rectangles` junta las celdas iguales que están una al lado de la otra en rectángulos grandes, y `fillCells` crea un bloque por rectángulo. Así el mapa usa unas 200 piezas.

## 3. Barandales automáticos

El código revisa cada celda de piso: si la de al lado es abismo (`o`), pone un barandal de 3 studs en esa orilla. Se puede disparar por encima, pero no te caes por accidente. Donde llega un puente no pone barandal (`nearBridge`).

## 4. El abismo mata

Abajo del abismo hay una pieza invisible con el atributo `KillZone`. `MapService` busca las piezas con ese atributo y, cuando un personaje las toca, le pone la vida en 0. En el registro de bajas sale como "Caída" (o como baja de quien te dañó antes de caer).

## 5. Los puentes

Los puentes están en la tabla `BRIDGES`: cada uno va de un punto alto (la orilla de la plataforma, a 8 studs) a un punto bajo (el piso de una zona). `Builder.slope` hace la rampa y se le agregan barandales a los lados.

## 6. Prueba a cambiar cosas

- Cambia `HUB_HEIGHT` a 12 para que la plataforma del centro sea más alta.
- Mueve un punto de aparición en `SPAWNS` (fila y columna, contadas desde 0 como en el dibujo).
- Agrega granadas en `GRENADES`.
