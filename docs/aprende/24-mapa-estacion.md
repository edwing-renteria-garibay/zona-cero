# 24. Mapa: La Estación

Un mapa cerrado de dos pisos, inspirado en Derelict de Halo. Es un octágono de 200 studs de
lado a lado, con techo, y se juega de noche con luces frías.

## Cómo está armado

- **Piso de abajo:** el suelo del octágono, con cajas y barreras para cubrirse.
- **Anillo de arriba:** una pasarela de 12 de ancho pegada a los 8 muros, a 14 de altura.
- **Puentes en cruz:** cuatro puentes de 14 de ancho que van del anillo a la plataforma del
  centro, que también está arriba.
- **Techo:** a 36 de altura. Tiene `CanQuery = false`, así que los rayos lo atraviesan. Por
  eso la colina del modo Rey de la colina se coloca sobre el piso y no encima del techo.

Para subir no hay teletransportes: cada equipo tiene **dos rampas** en las esquinas diagonales
de su lado. Suben del piso de abajo hasta el anillo. Junto a cada rampa hay una rejilla verde
que brilla, para encontrarla rápido.

## Cada equipo

El equipo rojo tiene el lado este (+X) y el azul el oeste. El azul es una copia del rojo girada
media vuelta (`Builder.half`).

| Qué | Dónde |
| --- | --- |
| Spawns | 2 en el anillo y 2 abajo, bajo el anillo, junto al muro de su lado |
| Bandera | En el anillo, en la esquina diagonal donde llega una rampa |
| Francotirador | En el anillo, en la otra esquina diagonal |
| Rifle láser | Arriba, en uno de los puentes laterales |
| Escopeta, pistola de hielo, granadas | Abajo |

En el centro, arriba, está el **lanzacohetes**. Justo debajo de la plataforma está el
**lanzallamas**. Quien quiera el lanzacohetes tiene que cruzar un puente al descubierto.

## Probarlo

En `src/shared/Config/Maps.luau` cambia `selected = "Aleatorio"` por
`selected = "Estacion"`. Así siempre sale este mapa. Cuando termines, regrésalo a
`"Aleatorio"`.

## Cambiarlo

Todo está en `src/server/Maps/Estacion.luau`. Las medidas están arriba del archivo:

| Constante | Qué es |
| --- | --- |
| `APOTHEM` | Del centro a los muros (100) |
| `HEIGHT` | Del piso al techo (36) |
| `UPPER` | Altura del piso de arriba (14) |
| `RING` | Ancho del anillo (12) |
| `BRIDGE` | Ancho de los puentes (14) |
| `CENTER` | Tamaño de la plataforma del centro (18) |

Si subes `UPPER`, las rampas se hacen más empinadas. Arriba de ~20 cuesta subirlas
caminando; alárgalas en `buildHalf` (el `44` es el largo de la rampa).

La luz del mapa está en `Maps.lighting.Estacion`.
