# Aprende: cómo funciona el rifle

Esta guía explica el código del rifle de asalto, de arriba abajo. Léela con los archivos abiertos al lado.

## 1. Cliente y servidor

En Roblox cada partida tiene **un servidor** (la computadora de Roblox que manda) y **un cliente por jugador** (la computadora o el teléfono de cada uno).

- El cliente ve la pantalla, el mouse y el teclado. Es rápido, pero no es de fiar: un tramposo puede cambiar lo que hace.
- El servidor ve a todos los jugadores y decide qué pasa de verdad.

Regla de oro del juego: **el cliente pide, el servidor decide.** Por eso el daño solo se aplica en el servidor.

| Archivo | Dónde corre | Qué hace |
| --- | --- | --- |
| `src/client/Controllers/WeaponController.luau` | Cliente | Lee el clic, calcula hacia dónde apuntas y avisa al servidor |
| `src/server/Services/CombatService.luau` | Servidor | Revisa que el disparo sea posible y hace el daño |
| `src/server/Services/HealthService.luau` | Servidor | Resta primero el escudo y después la vida |
| `src/client/UI/HUD.luau` | Cliente | Muestra escudo, vida y munición |
| `src/shared/Config/Weapons.luau` | Los dos | Los números del arma: daño, cadencia, cargador |

## 2. RemoteEvent: el "teléfono" entre cliente y servidor

Un `RemoteEvent` manda un mensaje de un lado al otro. Están en `ReplicatedStorage/Remotes` y los crea Rojo desde `default.project.json`.

```lua
-- Cliente: "disparé desde mi cabeza en esta dirección"
fireWeapon:FireServer(origin, direction)

-- Servidor: recibe el mensaje; Roblox añade quién lo envió como primer valor
fireWeapon.OnServerEvent:Connect(onFire) -- onFire(player, origin, direction)

-- Servidor a todos los clientes: "dibujen una trazadora de aquí a allá"
shotFired:FireAllClients(from, to)
```

## 3. Apuntar (cliente)

`aim()` en `WeaponController` hace dos pasos:

1. Convierte la posición del mouse en un rayo que sale de la cámara (`ViewportPointToRay`).
2. Busca qué toca ese rayo y calcula la dirección **desde tu cabeza** hasta ese punto.

Se dispara desde la cabeza y no desde la cámara porque en tercera persona la cámara está lejos de tu personaje, y el servidor rechaza disparos que no salen de cerca de ti.

## 4. Revisar el disparo (servidor)

`onFire` en `CombatService` hace una lista de controles. Si cualquiera falla, hace `return` y el disparo se ignora:

1. ¿Los datos son del tipo correcto (`Vector3`)?
2. ¿Tienes un arma de `Config/Weapons` en la mano y no estás recargando?
3. ¿Estás vivo?
4. ¿Pasó suficiente tiempo desde el último disparo? (cadencia)
5. ¿Te queda munición?
6. ¿El disparo sale a menos de 10 studs de tu cabeza?

Solo si todo está bien se gasta una bala y se lanza el **raycast**.

## 5. Raycast: la bala invisible

```lua
local result = workspace:Raycast(origin, direction.Unit * stats.range, params)
```

`Raycast` traza una línea recta y devuelve lo primero que toca (`result.Instance`) y dónde (`result.Position`). Los `params` le dicen que ignore tu propio personaje.

Si lo que tocó pertenece a un modelo con `Humanoid` de otro equipo, se llama a `HealthService.Damage`. Un tiro en la cabeza (`Head`) multiplica el daño solo en armas que tengan `headshotMultiplier`, como la pistola.

## 6. Atributos: datos pegados a un objeto

La munición se guarda como **atributo** del arma: `tool:SetAttribute("Ammo", 31)`. Los atributos que pone el servidor se copian solos a los clientes, así el HUD puede leer `tool:GetAttribute("Ammo")` sin pedir nada.

Lo mismo pasa con `Reloading` en el arma y `Shield` en el personaje.

## 7. La mira y el aviso de acierto

`src/client/UI/Crosshair.luau` dibuja la mira con `Frame` (rectángulos de interfaz) y en cada fotograma la mueve a la posición del mouse. Con el rifle es una cruz; en la torreta del jeep, un círculo hecho con `UICorner` y `UIStroke`. Mientras se ve la mira, se oculta la flecha del mouse con `UserInputService.MouseIconEnabled`.

Cuando el servidor aplica daño en `applyHit`, avisa solo al tirador:

```lua
hitConfirmed:FireClient(attacker)
```

El cliente guarda la hora del aviso y pinta la mira de rojo durante 0.15 segundos. Como el aviso viene del servidor, la mira solo se pone roja si el daño fue real.

## 8. Prueba a cambiar cosas

Abre `src/shared/Config/Weapons.luau` con `rojo serve` corriendo y prueba:

- Sube `damage` del rifle de 7 a 20 y fíjate cuántos disparos hacen falta ahora.
- Cambia `automatic = true` a `false`: tendrás que hacer clic por cada bala.
- Baja `magazine` a 10 para ver la recarga automática más seguido.

Rojo actualiza Studio al guardar el archivo; detén la prueba y vuelve a iniciarla para ver el cambio.
