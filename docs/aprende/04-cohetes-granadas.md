# Aprende: lanzacohetes, granadas y explosiones

Hasta ahora todas las armas eran **instantáneas**: un raycast va de tu cabeza al blanco en el mismo instante. Los cohetes y las granadas son **proyectiles**: existen en el mundo, viajan y explotan al llegar. Eso permite esquivarlos.

| Archivo | Qué hace |
| --- | --- |
| `src/server/Services/ExplosionService.luau` | Una explosión: efecto visual, sonido y daño a los jugadores cercanos |
| `src/server/Services/ProjectileService.luau` | Mueve los cohetes y lanza las granadas |
| `src/client/Controllers/GrenadeController.luau` | La tecla **G**: apuntar con el arco y lanzar |
| `src/shared/Config/Weapons.luau` | Los números del lanzacohetes |
| `src/shared/Config/Grenades.luau` | Los números de la granada |

## 1. Una explosión para todo

El jeep, el cohete y la granada explotan igual, así que la lógica vive en un solo lugar: `ExplosionService.Blast(centro, atacante, blast)`. `blast` es una tabla con cuatro números:

```lua
blast = {
	damage = 300, -- daño completo cerca del centro
	innerRadius = 4, -- hasta aquí el daño es completo
	radius = 14, -- aquí el daño ya es 0
	vehicleDamage = 350, -- daño máximo a un jeep
},
```

Entre `innerRadius` y `radius` el daño baja en línea recta. A 9 studs de un cohete (la mitad del camino entre 4 y 14) recibes 150.

La explosión no daña a tus compañeros, pero **sí a ti**. Cuidado con disparar un cohete a una pared que tienes enfrente.

## 2. El cohete: un raycast corto en cada fotograma

El servidor crea una pieza anclada (`Anchored = true`) y la mueve él mismo en cada `Heartbeat` (unas 60 veces por segundo):

1. Calcula el paso: `velocidad × dt` (dt son los segundos desde el último fotograma).
2. Lanza un raycast desde donde está el cohete hasta donde va a estar.
3. Si el raycast toca algo, el cohete explota ahí. Si no, avanza.

¿Por qué no usar la física de Roblox o el evento `Touched`? A 140 studs por segundo el cohete avanza más de 2 studs por fotograma y podría "saltarse" una pared delgada. El raycast revisa todo el tramo, así que no se salta nada.

Como usa el mismo arma, cadencia y munición que el rifle, `CombatService.onFire` hace todas las revisiones de siempre y solo al final elige: si el arma tiene `projectile = true`, lanza un cohete; si no, hace el raycast de bala.

## 3. La granada: física de verdad

La granada sí usa la física de Roblox: una bola con velocidad inicial (`AssemblyLinearVelocity`) que vuela en arco y cae.

Explota al chocar con algo. El evento `Touched` avisa cuando la granada toca otra pieza; se ignoran las piezas de quien la lanzó, porque sale de su mano. Si no toca nada, explota sola cuando se acaba la mecha.

`grenade:SetNetworkOwner(nil)` hace que el servidor calcule su física. Si no, Roblox le daría el control al cliente más cercano, y cada jugador podría verla en un lugar un poco distinto.

### Apuntar la granada

Mantén **G** y verás un arco de bolitas y un círculo rojo donde caerá; suelta **G** para lanzarla. El arco solo lo ves tú.

`GrenadeController` usa la fórmula del tiro parabólico. La posición de la granada después de `t` segundos es:

```
posición = origen + velocidad·t − ½·gravedad·t²
```

Elegimos cuánto tarda en llegar (más lejos, más tiempo) y despejamos la velocidad que la hace caer justo donde apunta tu mouse. Esa velocidad se manda al servidor, que crea la granada con ella. Como el servidor usa la misma gravedad (`workspace.Gravity`), la granada sigue el arco que viste. El servidor recorta velocidades exageradas (`maxThrowSpeed`) para que nadie haga trampa, y no se puede lanzar a más de `maxRange` studs.

`task.delay(fuse, ...)` es la mecha: pasados 1.5 segundos, la granada explota donde esté. La variable `exploded` evita que explote dos veces (por el choque y por la mecha).

Cada explosión elige su sonido con el campo `sound` de su `blast`: `"rocket"`, `"grenade"` o `"jeep"` (en `Config/Sounds.luau`).

Las granadas que te quedan se guardan en el atributo `Grenades` de tu personaje. Al reaparecer vuelves a tener 2.

## 4. Prueba a cambiar cosas

- Sube `speed` del lanzacohetes a 300 y verás que ya casi no se puede esquivar.
- Cambia `fuse` de la granada a 3 y lánzala al cielo: tardará más en explotar.
- Dale `count = 4` en `Grenades.luau` para tener más granadas.
- Cambia `maxRange` a 120 para lanzarlas mucho más lejos.
