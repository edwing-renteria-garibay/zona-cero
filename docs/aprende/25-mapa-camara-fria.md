# 25. Mapa: Cámara Fría

Un cuarto rectangular cerrado, con techo y dos pisos, inspirado en Chill Out de Halo. En Halo
cada base era distinta. Aquí las dos son iguales, para que ningún equipo tenga ventaja: cada
base tiene su túnel con ventanas.

Mide 220 de largo (de base a base) por 140 de ancho.

## Cómo está armado

- **Centro, arriba (a 20 de altura):** dos repisas grandes, una en cada lado, unidas por
  pasarelas con el puente oscuro que cruza todo el mapa de base a base.
- **Lanzacohetes:** está en una plataforma sobre un poste, a 32 de altura. Se sube por cuatro
  rampas angostas que salen de las repisas. Abajo del poste está el lanzallamas.
- **Cada base:** una cubierta alta al fondo, con la bandera y un muro bajo para cubrirse.
  Debajo corre el **túnel**, que tiene ventanas que miran al centro y la escopeta adentro.
- **Para subir:** 8 rampas en total. Cada base tiene dos rampas a su cubierta y dos a las
  repisas, todas pegadas a los muros de los lados.

## Cada equipo

El Rojo tiene el lado este (+X) y el Azul el oeste. El Azul es una copia del Rojo girada media
vuelta (`Builder.half`). Lo que va a los dos lados de una base se hace en un `for` con
`side = 1` y `side = -1`. Así el mapa también es igual de izquierda a derecha.

| Qué | Dónde |
| --- | --- |
| Spawns | 2 en la cubierta y 2 en el túnel |
| Bandera | Al fondo de la cubierta |
| Francotirador | En la cubierta, en una esquina |
| Escopeta | En el túnel |
| Rifle láser | En una de las repisas |
| Granadas, pistola de hielo | Abajo, en el centro |

## Probarlo

En `src/shared/Config/Maps.luau` pon `selected = "CamaraFria"`. Cuando termines, regrésalo a
`"Aleatorio"`.

## Cambiarlo

Todo está en `src/server/Maps/CamaraFria.luau`. Las medidas están arriba del archivo
(`HALF_LENGTH`, `HALF_WIDTH`, `HEIGHT`, `UPPER`, `ROCKET_HEIGHT`, y dónde empiezan el túnel
y la cubierta). La luz está en `Maps.lighting.CamaraFria`.
