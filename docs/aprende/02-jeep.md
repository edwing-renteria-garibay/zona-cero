# Aprende: cómo funciona el jeep con torreta

Esta guía explica el código del jeep. Antes conviene haber leído [01-rifle.md](01-rifle.md), porque el jeep reutiliza las mismas ideas: el cliente pide y el servidor decide.

| Archivo | Dónde corre | Qué hace |
| --- | --- | --- |
| `src/server/Services/VehicleService.luau` | Servidor | Construye el jeep, lo mueve, le quita vida, lo hace explotar y reaparecer |
| `src/server/Services/CombatService.luau` | Servidor | Valida los disparos de la torreta y aplica el daño a jeeps y jugadores |
| `src/client/Controllers/VehicleController.luau` | Cliente | Envía los disparos de la torreta mientras mantienes el clic |
| `src/client/Controllers/Aim.luau` | Cliente | Calcula a qué punto apuntas (lo usan el rifle y la torreta) |
| `src/shared/Config/Vehicles.luau` | Los dos | Vida, velocidad, giro y daño de la torreta |

## 1. El jeep se construye con código

`buildJeep` crea cada pieza con `Instance.new("Part")`, la coloca respecto al chasis y la une con una `WeldConstraint` (una soldadura). Así el jeep entero se mueve como un solo objeto.

```lua
addPart(model, chassis, wheelProps(), CFrame.new(x, -0.8, z))
```

`CFrame.new(x, y, z)` es una posición relativa: `x` es izquierda/derecha, `y` arriba/abajo y `z` delante/detrás. En Roblox **el frente es -Z**, por eso el capó está en `z = -3.8` y la torreta atrás, en `z = 2.2`.

Hacerlo con código en vez de en Studio tiene una ventaja: todo vive en Git y se puede revisar en un pull request.

## 2. Asientos

- `DriverSeat` es un `VehicleSeat`: cuando te sientas, Roblox lee W/A/S/D y los guarda en `ThrottleFloat` (adelante/atrás) y `SteerFloat` (izquierda/derecha). No hace falta código en el cliente para conducir.
- `TurretSeat` y `PassengerSeat` son `Seat` normales. El de la torreta tiene el atributo `Turret`, que es como el código lo reconoce.
- Para subir, camina hacia un asiento. Para bajar, pulsa **Espacio** (saltar).

## 3. Conducción arcade

En vez de simular motor, ruedas y suspensión, dos **restricciones** de física empujan el chasis:

- `LinearVelocity` fija la velocidad horizontal: hacia donde mira el jeep, y 0 de lado, así no derrapa. Como su fuerza en el eje vertical es 0, la gravedad sigue funcionando.
- `AngularVelocity` fija la rotación: solo gira sobre el eje vertical, y por eso **el jeep no vuelca**.

En cada fotograma `updateJeep` lee el asiento y ajusta el motor de avance y el giro:

```lua
drive.VectorVelocity = flatForward.Unit * forward
steering.AngularVelocity = Vector3.new(0, -steer * stats.turnRate * turnFactor, 0)
```

`turnFactor` hace que, como un coche, no gire estando parado y gire al revés en marcha atrás.

Limitación actual: como nunca se inclina, en rampas o cuestas el jeep se mantiene horizontal. Para el mapa en greybox es suficiente; más adelante se puede cambiar por algo más realista.

## 4. La torreta

1. El cliente (`VehicleController`) comprueba en cada fotograma si vas en el asiento de la torreta. Si mantienes el clic, envía `FireTurret` con la dirección hacia donde apuntas, a 10 disparos por segundo.
2. El servidor (`onFireTurret` en `CombatService`) revisa que estés vivo, sentado en ese asiento y respetando la cadencia.
3. Gira el cañón hacia la dirección del disparo, lanza un raycast **desde la punta del cañón** (no desde tu cabeza) y aplica el daño con `applyHit`, la misma función que usa el rifle.

En la torreta tu rifle se guarda solo, para que un clic no dispare las dos armas.

## 5. Vida, explosión y reaparición

- La vida del jeep es el atributo `Health` del modelo (600). El HUD la muestra cuando vas dentro.
- `VehicleService.Damage` resta vida, salvo que dentro vaya el atacante o alguien de su equipo.
- A 0, `explode` mata a quien va dentro (la baja cuenta para quien destruyó el jeep), crea una explosión solo visual y borra el modelo.
- `task.delay(stats.respawnTime, ...)` lo vuelve a crear en su sitio a los 45 segundos.

## 6. Llantas ponchadas

Cada llanta (`Wheel`) guarda su propia vida en el atributo `TireHealth` (60). Cuando un disparo toca una llanta, `CombatService` pasa a `VehicleService.Damage` la pieza que recibió el impacto (`hitPart`), y así se sabe que fue una llanta:

1. `damageTire` le resta el daño a esa llanta.
2. El jeep recibe solo la mitad (`tireHitShare`), porque una llanta es más fácil de romper que el motor.
3. Cuando la llanta llega a 0 se poncha: se hace más pequeña y gris, y suben los contadores `FlatTires` y `FlatFrontTires` del jeep.

En `updateJeep`, cada llanta ponchada quita un 20 % de velocidad, y cada delantera un 30 % de giro. Con las cuatro ponchadas el jeep apenas avanza. Al reaparecer, el jeep sale con llantas nuevas.

La barra sobre el jeep es un `BillboardGui`: una interfaz que flota en el mundo 3D pegada a una pieza. El servidor cambia el ancho y el color de la barra con cada daño, y todos los jugadores lo ven.

## 7. Prueba a cambiar cosas

En `src/shared/Config/Vehicles.luau`:

- Sube `maxSpeed` a 90 para un jeep más rápido.
- Cambia `turnRate` a 3 para que gire más cerrado.
- Baja `health` a 100 para probar la explosión sin disparar tanto.
- Baja `tireHealth` a 20 para poncharlas con 3 disparos.

Para que los jeeps aparezcan en otro lugar, crea en Workspace una carpeta `VehicleSpawns` con una pieza por jeep, orientada hacia donde debe mirar el jeep.
