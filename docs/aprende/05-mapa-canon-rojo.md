# Aprende: el mapa Cañón Rojo

El mapa se construye con código en `src/server/Services/MapService.luau` cada vez que arranca el servidor. Es un **greybox**: bloques simples para probar si el mapa se juega bien antes de decorarlo.

## 1. Cómo está hecho

```
  pared del cañón
  [rampa] ___ techo del túnel (camino alto) ___ [rampa]
          |__ túnel de infantería ____________|
  AZUL       camino de jeeps · puente en el centro      ROJO
          |__ túnel de infantería ____________|
  [rampa] ___ techo del túnel (camino alto) ___ [rampa]
  pared del cañón
```

- **Bases:** un búnker por equipo en cada extremo, con 4 puntos de aparición (`SpawnLocation`) y una franja del color del equipo.
- **Tres rutas** entre bases, como pide el documento de diseño:
  - el camino de jeeps por el centro, con coberturas cada 15 a 25 studs;
  - los túneles de infantería, cuyos postes en las entradas dejan pasar a una persona pero no a un jeep;
  - el camino alto sobre los techos, al que se sube por las rampas de las esquinas.
- **Puente:** cruza el camino a la altura de los techos. En su centro está el **lanzacohetes**, en un lugar muy expuesto.
- **Jeeps:** aparece uno junto a cada base.

Las dos mitades son iguales, giradas 180°: la función `mirrored` pone cada bloque en las dos mitades. Así ningún equipo tiene ventaja.

## 2. Materiales y sonidos

Cada bloque tiene un material y el material decide el sonido del impacto:

| Material | Dónde | Sonido |
| --- | --- | --- |
| Rock, Sand, Concrete | Paredes, suelo, túneles, barreras | Concreto |
| WoodPlanks | Cajas | Madera |
| Metal, DiamondPlate | Contenedores, puente, rampas, postes | Metal |

## 3. Puntos de aparición por equipo

Un `SpawnLocation` con `Neutral = false` y `TeamColor` igual al color del equipo solo sirve para ese equipo. Roblox elige uno al azar al reaparecer. `Duration = 0` quita el campo de fuerza de Roblox, porque la protección de 2 s la da nuestro juego.

El mapa desactiva los `SpawnLocation` que no son suyos, como el que trae la plantilla de Studio.

## 4. Armas del mapa

`PickupService` busca las piezas de `Map.WeaponPickups` con el atributo `Weapon`. Al tocar la plataforma te da una copia del arma guardada en `ServerStorage.Weapons`, y la plataforma tarda `pickupRespawn` segundos en volver (120 s el lanzacohetes).

El lanzacohetes ya no está en el inventario inicial: hay que ir a buscarlo. Trae 2 cohetes cargados y 4 de repuesto (`reserve` en `Config/Weapons.luau`).

## 5. ¿Y si quiero hacer el mapa a mano en Studio?

Si en el Workspace hay una carpeta llamada `Map`, el código usa esa y no construye nada. Así puedes:

1. Iniciar una prueba, copiar la carpeta `Map` y `VehicleSpawns` del Workspace, detener la prueba y pegarlas.
2. Mover, decorar o cambiar lo que quieras, y guardar el lugar.

La próxima vez se usará tu versión.

## 6. Prueba a cambiar cosas

- Cambia `ROOF_TOP` a 20 para un camino alto más elevado (las rampas se inclinan solas).
- Agrega una cobertura en `buildCover` con `mirrored(...)` y mira cómo aparece en las dos mitades.
- Cambia `pickupRespawn` del lanzacohetes a 30 para que haya cohetes por todos lados.
