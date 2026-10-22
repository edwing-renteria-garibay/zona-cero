# Aprende: pistola, tiros a la cabeza y golpe cuerpo a cuerpo

Esta guía explica tres cambios. Ninguno necesitó un sistema nuevo: casi todo reutiliza lo que ya existía.

## 1. Una pistola casi sin código

La pistola es otra herramienta (`Tool`) en `ServerStorage.Weapons` (antes estaba en `StarterPack`; ver la guía 14), declarada en `default.project.json`, y una entrada nueva en `src/shared/Config/Weapons.luau`:

```lua
Pistol = {
	damage = 30,
	headshotMultiplier = 2.5,
	fireRate = 2.5,
	magazine = 8,
	reloadTime = 1.6,
	range = 400,
	automatic = false,
},
```

Como `WeaponController` y `CombatService` leen los datos del arma por su nombre (`Weapons[tool.Name]`), la pistola ya sabe disparar, recargar y mostrar su munición en el HUD. `automatic = false` hace que dispare una vez por clic.

Pulsa **1** para el rifle y **2** para la pistola.

## 2. Tiros a la cabeza

Cada arma tiene `damage` (daño en el cuerpo) y `headshotMultiplier` (cuánto se multiplica en la cabeza). Un jugador aguanta 200 (100 de escudo + 100 de vida):

| Arma | Cuerpo | Cabeza | Disparos para matar (cuerpo / cabeza) |
| --- | --- | --- | --- |
| Rifle | 7 | 14 | 29 / 15 |
| Pistola | 30 | 75 | 7 / 3 |
| Torreta del jeep | 10 | 20 | 20 / 10 |

`isHeadPart` en `CombatService` decide si el disparo fue a la cabeza. Hay un detalle: los gorros y sombreros son piezas aparte (`Accessory`) que tapan la cabeza. Sin este caso especial, un tiro al gorro contaría como tiro al cuerpo. Por eso, si la pieza está dentro de un `Accessory` soldado a la cabeza, también cuenta como cabeza.

## 3. Golpe cuerpo a cuerpo

Pulsa **F** (o el botón **Golpe** en móvil). `MeleeController` usa `ContextActionService`, que crea el botón táctil automáticamente.

En el servidor, `onMelee`:

1. Revisa que estés vivo, a pie y que hayan pasado 0.8 s desde tu último golpe.
2. Busca piezas en una esfera invisible delante de tu pecho con `workspace:GetPartBoundsInRadius`, y se queda con el enemigo más cercano.
3. Mira si lo golpeas por la espalda comparando hacia dónde mira él con la dirección desde ti hasta él (producto punto, `:Dot`). Si los dos apuntan hacia el mismo lado, estás detrás.
4. Golpe normal: 70 de daño. Por la espalda: 200, que mata de un golpe.

Si llevas un arma en la mano, el servidor crea un `StringValue` llamado `toolanim` con el valor `"Lunge"`, y el script de animación de Roblox hace que el personaje dé una estocada. Sin arma en la mano todavía no hay animación; se puede añadir más adelante con una animación propia.

## 4. La mira avisa del tipo de acierto

El servidor envía `HitConfirmed` con `"hit"` (cuerpo o jeep) o `"head"` (cabeza o golpe por la espalda). La mira se pone roja con un acierto normal, y naranja y un poco más grande con uno a la cabeza.

## 5. ¿Hice daño? Los avisos de acierto

Con la pistola, el cuerpo recibe 30 de daño. El escudo (100) aguanta 3 disparos, y el cuarto lo rompe y empieza a bajar la vida. Por eso antes parecía que los primeros tiros no hacían nada: la barra de Roblox solo muestra la vida. Ahora hay cuatro avisos:

| Aviso | Quién lo ve | Archivo |
| --- | --- | --- |
| Barras sobre la cabeza: escudo (azul) y vida (verde) | Todos | `src/client/UI/OverheadBars.luau` |
| El enemigo brilla en azul al recibir un golpe en el escudo, y en blanco cuando se rompe | Todos | `src/client/UI/OverheadBars.luau` |
| Destello en el impacto: azul (escudo), rojo (vida), amarillo (jeep), gris (escenario) | Todos | `src/client/Controllers/WeaponController.luau` |
| Número de daño que flota y un sonido de acierto | Solo quien dispara | `src/client/UI/HitFeedback.luau` |
| Sonido de cada disparo, desde el arma | Todos | `src/client/Controllers/WeaponController.luau` |

La bala también suena al pegar en el escenario o en un jeep. El servidor mira el material de la pieza (`result.Material`) y lo resume en `"concrete"`, `"metal"` o `"wood"`; cada uno tiene su sonido. Al disparar sin balas suena un clic.

La torreta del jeep tiene 100 balas. Al vaciarse se recarga sola en 5 s, o puedes recargarla antes con **R**. La munición se guarda en el jeep (atributo `TurretAmmo`), así que si cambias de artillero las balas que quedan siguen ahí.

Los sonidos se eligen en `src/shared/Config/Sounds.luau`. En Studio abre la Caja de herramientas, ve a **Audio**, busca un sonido (por ejemplo "gunshot"), haz clic derecho y copia su ID. Pégalo como `"rbxassetid://NÚMERO"`.

El escudo se empieza a recargar tras 3.5 s sin recibir daño y se llena en 1.5 s (`REGEN_DELAY` y `REGEN_TIME` en `HealthService`).

`HealthService.Damage` ahora devuelve dos números: cuánto se llevó el escudo y cuánto la vida. `CombatService` los usa para elegir el color del destello y del número.

## 6. Prueba a cambiar cosas

- Sube el `headshotMultiplier` del rifle a 3 y mira cuánto más rápido matas apuntando a la cabeza.
- Cambia `backstabDamage` en `src/shared/Config/Melee.luau` a 100 si el golpe por la espalda te parece demasiado fuerte.
- Dale a la pistola `magazine = 12` para una 9 mm más clásica.
