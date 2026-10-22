# Aprende: el mapa Fortines y cómo elegir mapa

**Fortines** es el segundo mapa, hecho a partir del diseño de edwing en SketchUp: dos fuertes amurallados, uno frente al otro, con una plaza en medio. Cada fuerte tiene tres accesos (dos laterales y uno central), muros por dentro para cubrirse y, al fondo, una plataforma con rampas y un puente. Arriba del puente está la base de la bandera para el futuro modo Captura la bandera.

## 1. Elegir el mapa

Abre `src/shared/Config/Maps.luau`:

```lua
selected = "Fortines",
```

Pon `"CanonRojo"`, `"Fortines"` o `"Aleatorio"`. El mapa se construye al arrancar el servidor, así que el cambio se ve en la siguiente prueba (F7).

## 2. Un archivo por mapa

Los mapas ahora viven en `src/server/Maps/`:

| Archivo | Qué hace |
|---|---|
| `Builder.luau` | Herramientas comunes: `block`, `slope`, `wallWithGaps`, `pickupPad` y `half()` |
| `CanonRojo.luau` | El mapa estándar |
| `Fortines.luau` | El mapa nuevo |

Cada mapa tiene una función `Build(map)`. `MapService` lee `Config/Maps`, busca el archivo con ese nombre y llama a su `Build`.

Para hacer un mapa nuevo: copia `Fortines.luau` con otro nombre (por ejemplo `Desierto.luau`), cambia lo que quieras y agrégalo a `list` en `Config/Maps.luau`.

## 3. Medidas con "d" y "z"

En `Fortines.luau` las piezas se colocan con `pos(d, y, z)`:

- **d**: distancia desde la entrada del fuerte hacia el fondo (0 = la entrada, 124 = el muro del fondo).
- **y**: altura.
- **z**: hacia los lados (0 = el pasillo central).

Así las medidas se leen igual que tu dibujo. Como el fuerte es simétrico de izquierda a derecha, el ciclo `for _, side in { 1, -1 }` construye las dos mitades con las mismas medidas.

Y como en Cañón Rojo, `Builder.half()` gira todo 180° para hacer el fuerte Azul.

## 4. Las alturas

| Pieza | Altura (studs) |
|---|---|
| Muros de afuera y brazos | 20 |
| Muros de dentro | 12 |
| Muro bajo frente a la plataforma | 10 |
| Plataforma y puente | 8 |

Un personaje salta unos 7 studs, así que no puede subirse a los muros de dentro desde el suelo. Desde la plataforma (8) sí ve por encima del muro bajo (10), y puede saltar sobre él.

## 5. Prueba a cambiar cosas

- Cambia `PLAZA` a 40 para separar más los fuertes.
- Cambia `LOW_HEIGHT` a 6 para que el muro bajo sea solo una cobertura.
- Mueve las granadas: busca `GrenadePad` y cambia `pos(34, 0.2, 0)`.
