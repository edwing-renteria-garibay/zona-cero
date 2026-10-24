# 26. Mapa: La Barranca (con Terrain)

Un cañón grande y abierto, inspirado en Blood Gulch de Halo, hecho para pelear con jeeps.
Mide 800 de largo (de base a base) por 480 de ancho. Cada equipo tiene 6 jeeps frente a su
base.

## Cómo está armado

- **El cañón:** piso de pasto, paredes de roca de 100 de alto y peñascos pegados a las
  paredes, para que no se vean rectas.
- **Las montañas:** 4 iguales (35 de alto), en cruz alrededor del centro, con forma de
  triángulo y la punta hacia el centro: una frente a cada base y una a cada lado (el dibujo
  de edwing). Entre ellas quedan pasos en diagonal y el centro abierto, así que los jeeps
  cruzan por en medio en cualquier dirección o rodean las 4 por afuera. Los jeeps no las
  pueden subir; a pie sí. Cada una es una montaña redonda con una loma en cada esquina del
  triángulo (función `triangleMountain`). En la cima de las de los lados están el
  **lanzacohetes** y el **cañón de iones**; en la de frente a cada base, el rifle láser.
- **Los caminos:** un anillo de tierra alrededor de las 4 montañas, una X por los pasos
  del centro y uno de cada base al anillo.
- **Las bases:** un búnker de metal con una puerta al centro de cada lado y azotea. A la
  azotea se sube por una rampa por detrás; ahí está el francotirador. Adentro están la
  bandera (en una esquina del fondo) y la escopeta.

Para cambiar el tamaño o la forma, mueve los números de arriba de `Barranca.luau`:
`HALF_LENGTH`, `HALF_WIDTH`, `MOUNTAIN_DISTANCE`, `TRIANGLE_SIDE`, `MOUNTAIN_HEIGHT` y `RING`.

## Terrain: el terreno de Roblox

Los otros mapas están hechos solo con bloques (`Part`). Este usa **Terrain**, el terreno de
Roblox: pasto, tierra y roca que se ven naturales y se pueden rellenar con formas.

```lua
local terrain = workspace.Terrain
terrain:FillBlock(CFrame.new(0, -4, 0), Vector3.new(600, 8, 300), Enum.Material.Grass) -- un bloque
terrain:FillBall(Vector3.new(0, 1, 0), 5, Enum.Material.Rock) -- una bola (una roca)
terrain:FillCylinder(CFrame.new(0, -2, 0), 4, 10, Enum.Material.Ground) -- un cilindro
```

- Lo que se rellena después **reemplaza** lo que había. Por eso el camino se pinta antes que
  las montañas: si se tocan, gana la montaña.
- Una **loma suave** es la punta de una esfera muy grande que casi toda queda bajo el piso
  (función `mound`). Mientras más grande la esfera, más suave la loma.
- El terreno se mide en cuadros de 4 studs, así que las medidas no quedan exactas al stud.
- El terreno no está dentro de la carpeta del mapa. Por eso `MapService` lo borra con
  `workspace.Terrain:Clear()` cuando cambia de mapa.
- El Rey de la colina calcula qué tan grande es el mapa con sus bloques. Como el terreno no
  cuenta, hay 4 bloques invisibles en las esquinas (`BoundsMarker`).

**Piso invisible.** Cuando el servidor crea el terreno, Roblox tarda un momento en hacerlo sólido. Los jeeps aparecen enseguida, así que lo atravesaban y caían al vacío. Por eso debajo del pasto hay una pieza invisible, `Ground`, con su cara de arriba en `y = 0`: es sólida desde el principio. Tiene material de pasto para que los pasos y las balas suenen igual.

## Probarlo

En `src/shared/Config/Maps.luau` pon `selected = "Barranca"`. Usa un modo con vehículos
(por ejemplo Asesino por equipos o Captura la bandera) para que salgan los jeeps.

## Cambiarlo

Todo está en `src/server/Maps/Barranca.luau`:

| Qué | Dónde |
| --- | --- |
| Tamaño del cañón | `HALF_LENGTH`, `HALF_WIDTH`, `WALL_HEIGHT` |
| El anillo del camino | `RING` (qué tan lejos del centro pasa) |
| El camino | la lista `path` en `buildHalf` |
| Las montañas | `CENTER_RADIUS` y `CENTER_HEIGHT` para la del centro; las de las esquinas, en `buildHalf` (altura 30 y 22) |
| Las rocas | la lista de rocas en `buildHalf` (x, z, tamaño) |
| La base | `buildBase` |
