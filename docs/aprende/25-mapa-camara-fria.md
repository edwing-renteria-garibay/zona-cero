# 25. Mapa: Cámara Fría

Un cuarto rectangular cerrado, con techo y dos pisos, inspirado en Chill Out de Halo. En Halo
cada base era distinta. Aquí las dos son iguales, para que ningún equipo tenga ventaja: cada
base tiene su túnel con ventanas.

Mide 280 de largo (de base a base) por 140 de ancho.

## Cómo está armado

- **Arriba (a 20 de altura):** una plataforma corrida pegada a cada muro de los lados, que une
  las cubiertas de las dos bases. Al centro, unas pasarelas la unen con el puente oscuro que
  cruza todo el mapa de base a base. La plataforma mide 12 de fondo y se ensancha en
  algunos tramos (`WIDE_SPANS`). En cada tramo ancho hay un bloque en forma de trapecio
  contra el muro, alto como un jugador de pie, que se rodea por la orilla. Así ni el camino
  ni la orilla son rectos. Cada uno es un bloque (`Part`) con una cuña
  (`WedgePart`) a cada lado; se hacen con la función `cover`.
- **Lanzacohetes:** está en una plataforma sobre un poste, a 32 de altura. Se sube por cuatro
  rampas angostas que salen de las plataformas de los lados. Abajo del poste está el lanzallamas.
- **Cada base:** una cubierta alta al fondo, con la bandera y un muro bajo para cubrirse.
  Debajo corre el **túnel**, que tiene ventanas que miran al centro y la escopeta adentro.
- **Para subir:** en cada esquina de las bases hay un spawn abajo y una **rampa** que sube a la
  plataforma del lado. Si te caes en medio del mapa, también hay una **escalera** en medio de
  cada lado. Es un `TrussPart`, la pieza de Roblox por la que se trepa sola al caminar contra
  ella.

## Cada equipo

El Rojo tiene el lado este (+X) y el Azul el oeste. El Azul es una copia del Rojo girada media
vuelta (`Builder.half`). Lo que va a los dos lados de una base se hace en un `for` con
`side = 1` y `side = -1`. Así el mapa también es igual de izquierda a derecha.

| Qué | Dónde |
| --- | --- |
| Spawns | 2 en la cubierta y 2 abajo, en las esquinas, junto a las rampas |
| Bandera | Al fondo de la cubierta |
| Francotirador | En la cubierta, en una esquina |
| Escopeta | En el túnel |
| Rifle láser | En una de las plataformas de los lados |
| Granadas, pistola de hielo | Abajo, en el centro |

## Probarlo

En `src/shared/Config/Maps.luau` pon `selected = "CamaraFria"`. Cuando termines, regrésalo a
`"Aleatorio"`.

## Cambiarlo

Todo está en `src/server/Maps/CamaraFria.luau`. Las medidas están arriba del archivo
(`HALF_LENGTH`, `HALF_WIDTH`, `HEIGHT`, `UPPER`, `ROCKET_HEIGHT`, `SHELF_FROM`, y dónde empiezan el túnel
y la cubierta). La luz está en `Maps.lighting.CamaraFria`.
