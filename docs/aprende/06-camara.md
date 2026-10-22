# Aprende: la cámara

El juego empieza en **primera persona**. Con **V** (Y en mando, botón **Cámara** en móvil) cambias a **tercera persona sobre el hombro**, y con otra **V** vuelves. Todo está en `src/client/Controllers/CameraController.luau`.

## 1. Primera persona

Basta con una propiedad del jugador:

```lua
player.CameraMode = Enum.CameraMode.LockFirstPerson
```

Roblox pone la cámara en la cabeza, fija el mouse en el centro de la pantalla y gira el personaje hacia donde miras.

## 2. Tercera persona sobre el hombro

Aquí hay que hacer tres cosas a mano:

1. **Distancia fija:** `CameraMinZoomDistance` y `CameraMaxZoomDistance` valen lo mismo (10 studs), así que la rueda del mouse no la cambia.
2. **Sobre el hombro:** `humanoid.CameraOffset = Vector3.new(2, 0.5, 0)` corre la cámara 2 studs a la derecha, para que el personaje no tape la mira.
3. **Mirar hacia la cámara:** en cada fotograma el mouse se fija en el centro (`MouseBehavior = LockCenter`), y el personaje gira hacia donde mira la cámara. Para que Roblox no lo gire por su cuenta se apaga `humanoid.AutoRotate`.

`BindToRenderStep` ejecuta ese código en cada fotograma justo después de que Roblox mueve la cámara, así el personaje gira sin temblar.

## 3. ¿Por qué la mira está siempre en el centro?

Con el mouse fijo en el centro, `UserInputService:GetMouseLocation()` devuelve el centro de la pantalla. La mira se dibuja ahí y `Aim.GetTarget()` lanza su rayo desde ahí, así que el rifle, la pistola, la torreta, los cohetes y las granadas apuntan a donde mira la cámara sin cambiar su código.

## 4. Prueba a cambiar cosas

- Pon `SHOULDER_OFFSET` en `Vector3.new(-2, 0.5, 0)` para ver sobre el hombro izquierdo.
- Cambia `THIRD_PERSON_DISTANCE` a 16 para ver más lejos.
- Cambia `local firstPerson = true` a `false` para empezar en tercera persona.
