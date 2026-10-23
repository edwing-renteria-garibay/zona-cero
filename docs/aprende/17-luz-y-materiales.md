# 17 · Luz y materiales de los mapas

Primer paso para que el juego deje de verse como una maqueta gris.

## La luz

Lo que es igual en todos los mapas está en `default.project.json`, dentro de `Lighting`:

- `Technology = Future`: la luz más realista de Roblox, con sombras de cada luz.
- `Atmosphere`: niebla y color del aire. A lo lejos las cosas se ven más claras, como en la vida real.
- `ColorCorrection`: un poco más de contraste.
- `Bloom`: las cosas muy brillantes (las piezas neón) dan un resplandor.
- `SunRays`: rayos de sol suaves.

Lo que cambia en cada mapa está en `src/shared/Config/Maps.luau`, en `lighting`.
`MapService` lo aplica al construir el mapa:

| Mapa | Hora | Ambiente |
|---|---|---|
| Cañón Rojo | 15:30 | sol de la tarde y polvo cálido |
| Fortines | 10:30 | día nublado, gris azulado |
| El Cruce | 17:24 | atardecer dorado, sombras largas |

Prueba a cambiar `clockTime` o `density` y vuelve a darle a Play: es la forma más rápida de
cambiar el ambiente de un mapa.

## Los materiales

En `Maps/Builder.luau` hay estilos nuevos: `BRICK` (ladrillo), `RUST` (metal oxidado),
`STONE` (piedra) y `PAVEMENT` (pavimento).

- **El Cruce:** muros de ladrillo y techos de los túneles de metal oxidado (zona industrial).
- **Fortines:** muros de afuera de piedra y piso de pavimento.
- **Cañón Rojo:** se queda con roca y arena.

## Los acabados (`Builder.decorate`)

Después de construir cualquier mapa, `MapService` llama a `Builder.decorate`:

1. **Tonos:** cada bloque se aclara u oscurece un poco al azar, para que los muros no se
   vean todos idénticos. Se usa `Random.new(semilla)`, así que el mapa sale igual cada vez.
2. **Remates y zócalos:** los muros altos llevan una franja más oscura arriba y otra al
   nivel del piso, como en un edificio de verdad.
3. **Luces de equipo:** cada punto de aparición tiene una `PointLight` de su color.

Todas las piezas nuevas tienen `CanCollide = false` y `CanQuery = false`: no estorban al
caminar y las balas las atraviesan, así que el juego no cambia.
