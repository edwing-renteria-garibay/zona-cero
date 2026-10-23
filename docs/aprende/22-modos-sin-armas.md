# 22. Modos sin armas de fuego

Tres modos nuevos para partidas más locas. Están en `src/shared/Config/Modes.luau` y entran
en la rotación aleatoria (`randomPool`).

| Modo | Nombre en el código | Con qué se pelea |
| --- | --- | --- |
| A puño limpio | `Brawl` | Solo golpes (clic o F) |
| Pollos y machetes | `MeleeWeapons` | Machete (tecla 1) y pollo de hule (tecla 2) |
| Lluvia de Simis | `SimiRain` | Doctores Simi infinitos (G) y golpes |

Los tres van sin escudo, sin jeeps y sin objetos en el mapa.

## Cómo se arma un modo así

Un modo es una tabla de reglas. Lo que lo hace "sin armas" es esto:

```lua
loadout = {}, -- aparece sin armas
testingKeepsLoadout = true, -- el modo de prueba no le da las 9 armas
grenades = 0, -- sin granadas
```

Y en Lluvia de Simis:

```lua
infiniteGrenades = true, -- lanzar no gasta
grenadeStyle = "Simi", -- en vez de la granada sale un Doctor Simi
```

## Golpear con clic

Antes el clic solo golpeaba siendo zombi. Ahora `MeleeController` revisa qué llevas en la mano
cada vez que cambias de arma:

- Arma de fuego en la mano: el clic dispara (como siempre).
- Manos vacías o un arma de golpe: el clic golpea.

La tecla F sigue golpeando con cualquier cosa.

## Armas de golpe

Están en `src/shared/Config/Melee.luau`, en `Melee.weapons`. Cada una cambia el daño, el
alcance y la espera entre golpes:

| Arma | Daño | Espera | Especial |
| --- | --- | --- | --- |
| Puños | 70 | 0.8 s | |
| Machete | 60 | 0.7 s | |
| Pollo de hule | 35 | 0.4 s | Avienta lejos (`knockback`) |

Por la espalda, cualquiera mata de un golpe.

Su forma está en `src/shared/WeaponModels.luau` (`Machete` y `RubberChicken`), igual que las
armas de fuego. El machete de los zombis de Infección ahora es el mismo.

### ¿Por qué el empujón lo hace el cliente?

En Roblox, tu personaje lo mueve tu propia computadora (es su "dueño de red"). Si el servidor
cambia su velocidad, tu computadora la vuelve a escribir y el empujón no se nota. Por eso el
servidor le manda al golpeado el aviso `Knockback`, y su cliente salta y sale volando.

## El Doctor Simi

Está en `ProjectileService.luau` (`makeSimi`). Son piezas soldadas al cuerpo con
`WeldConstraint`: bata blanca, cabeza, pelo y bigote blancos, ojos y corbata. Solo el cuerpo
choca con las cosas. Al lanzarlo da maromas (`AssemblyAngularVelocity`) y explota igual que una
granada. Sus valores están en `Config/Grenades.luau`, en `simi`.

## Sonidos

- `Sounds.melee.RubberChicken`: el sonido al pegar con el pollo. Está vacío; pon ahí el ID que
  quieras.
- `Sounds.explosion.simi`: la explosión del Simi. Por ahora es la de la granada.
