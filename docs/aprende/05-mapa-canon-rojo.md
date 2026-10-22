# Aprende: el mapa Cañón Rojo

El mapa se construye con código en `src/server/Maps/CanonRojo.luau` cada vez que arranca el servidor. Es un **greybox**: bloques simples para probar si el mapa se juega bien antes de decorarlo.

## 1. Cómo está hecho

Cada equipo tiene tres lugares propios en su extremo del cañón:

- **Base baja:** un cuarto cerrado en la esquina, con 2 puntos de aparición. Sus dos puertas miden 8 studs: una persona pasa, un jeep no.
- **Zona de spawn:** un nicho techado contra la pared del fondo, con otros 2 puntos de aparición y sacos de arena al frente para cubrirse al salir.
- **Base alta:** una mesa de roca a 16 studs, con parapetos. Se sube por la rampa del color del equipo, desde la zona de spawn, o por otra rampa desde el carril sur.

En el centro:

- **Montículo:** una plataforma a 4 studs con rampas por los cuatro lados. Arriba está el **lanzacohetes**, a la vista de todos.
- **Dos carriles** separados por un muro con huecos para cruzar. Tienen barreras, cajas, contenedores, sacos de arena, pilares y una duna donde el jeep salta.
- **Cornisas:** un camino alto (8 studs) junto a cada pared del cañón, con rampas en las puntas, para flanquear.
- **Cuartos laterales:** uno por equipo junto al carril sur, con **granadas** (+2, máximo 4, vuelven a los 30 s).

Las dos mitades son iguales, giradas 180°. `buildHalf` construye la mitad de un equipo con las medidas de la mitad Roja; para el Azul, `Builder.half()` (en `src/server/Maps/Builder.luau`) gira cada pieza 180° alrededor del centro del mapa. Así ningún equipo tiene ventaja.

### Rampas

`slope(carpeta, nombre, abajo, arriba, ancho, estilo)` crea una losa inclinada cuya cara de arriba va del punto `abajo` al punto `arriba`. Usa `CFrame.lookAt(medio, arriba)`, que gira la pieza para que su eje Z apunte hacia `arriba`. Con eso se hacen el montículo, las rampas de las bases, las cornisas y la duna.

## 2. Materiales y sonidos

Cada bloque tiene un material y el material decide el sonido del impacto:

| Material | Dónde | Sonido |
| --- | --- | --- |
| Rock, Sand, Concrete, Fabric | Paredes, suelo, bases, barreras, sacos de arena | Concreto |
| WoodPlanks | Cajas | Madera |
| Metal, DiamondPlate | Contenedores y rampas de las bases | Metal |

## 3. Puntos de aparición por equipo

Un `SpawnLocation` con `Neutral = false` y `TeamColor` igual al color del equipo solo sirve para ese equipo. Roblox elige uno al azar al reaparecer. `Duration = 0` quita el campo de fuerza de Roblox, porque la protección de 2 s la da nuestro juego.

El mapa desactiva los `SpawnLocation` que no son suyos, como el que trae la plantilla de Studio.

## 4. Armas del mapa

`PickupService` busca las piezas de `Map.WeaponPickups`. Cada una dice qué da con un atributo:

- `Weapon = "RocketLauncher"`: una copia del arma guardada en `ServerStorage.Weapons`. Si ya la tienes, te rellena el cargador y el repuesto; si los tienes llenos, la plataforma no se gasta. Vuelve a los `pickupRespawn` segundos (120 el lanzacohetes).
- `Pickup = "Grenades"`: granadas (`Config/Grenades.luau`). Si ya tienes el máximo, no la gastas.

El lanzacohetes ya no está en el inventario inicial: hay que ir a buscarlo. Trae 2 cohetes cargados y 4 de repuesto (`reserve` en `Config/Weapons.luau`).

## 5. ¿Y si quiero hacer el mapa a mano en Studio?

Si en el Workspace hay una carpeta llamada `Map`, el código usa esa y no construye nada. Así puedes:

1. Iniciar una prueba, copiar la carpeta `Map` y `VehicleSpawns` del Workspace, detener la prueba y pegarlas.
2. Mover, decorar o cambiar lo que quieras, y guardar el lugar.

La próxima vez se usará tu versión.

## 6. Prueba a cambiar cosas

- Cambia `MESA_HEIGHT` a 24 para una base alta más elevada (las rampas se inclinan solas).
- Agrega una cobertura en `buildCover` con `mirrored(...)` y mira cómo aparece en las dos mitades.
- Cambia `pickupRespawn` del lanzacohetes a 30 para que haya cohetes por todos lados.
