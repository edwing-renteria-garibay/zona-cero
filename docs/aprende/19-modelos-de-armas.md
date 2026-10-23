# 19. Modelos de armas

Las armas ya no son un bloque: el rifle, la pistola y el lanzacohetes están hechos de varias
piezas (cuerpo, cañón, cargador, culata, miras...). En primera persona además ves tus brazos, y
el arma reacciona: retrocede al disparar, se balancea al caminar y baja al recargar.

## Dónde está cada cosa

| Archivo | Qué hace |
| --- | --- |
| `src/shared/WeaponModels.luau` | La forma de cada arma: piezas, tamaños, colores, boca del cañón |
| `src/client/Controllers/ViewModel.luau` | El arma y los brazos en primera persona |
| `src/server/Services/LoadoutService.luau` | Al arrancar, les da forma a las armas de `ServerStorage.Weapons` |

`WeaponModels` está en `shared` porque lo usan los dos lados:

- **El servidor** arma la herramienta (Tool) que todos ven en tu mano y en las plataformas.
  La primera pieza se vuelve la `Handle` y las demás quedan dentro de ella, pegadas con una
  `Weld`.
- **El cliente** construye una copia suelta solo para ti, pegada a la cámara.

## Cómo se describe una pieza

Todo se mide desde el punto donde la mano derecha agarra el arma:

- X positivo = a la derecha
- Y positivo = hacia arriba
- Z negativo = hacia el frente (hacia donde dispara)

```lua
box("Magazine", V(0.2, 0.62, 0.32), C(0, -0.1, -0.55) * CFrame.Angles(rad(14), 0, 0), POLYMER),
```

Esto es un bloque llamado Magazine (cargador):

- Mide 0.2 de ancho, 0.62 de alto y 0.32 de largo.
- Está un poco abajo y adelante de la mano.
- Está inclinado 14 grados.
- Es de plástico negro.

`tube(...)` hace un cilindro a lo largo del arma, como un cañón.

## Cambiar cómo se ve en primera persona

Cada arma tiene estos valores:

- `view`: dónde queda el arma respecto a la cámara. El primer número la mueve a la derecha, el
  segundo hacia arriba y el tercero hacia el frente (más negativo = más lejos). El ángulo final
  la gira un poco hacia el centro de la pantalla.
- `kick` y `kickAngle`: cuánto retrocede y cuánto sube al disparar.
- `leftHand`: dónde va la mano izquierda.

Si un arma se ve muy grande, muy cerca o tapa la mira, cambia `view` y prueba otra vez.

## Cómo se mueve (ViewModel)

En cada fotograma, `ViewModel` calcula la posición del arma así:

```
cámara * view * (balanceo + retroceso + recarga + golpe) 
```

Cada movimiento es un número que regresa solo a 0 con la función `approach`. Por ejemplo, al
disparar, `ViewModel.Kick()` sube `kickAngle`, y en los siguientes fotogramas baja hasta 0. Así
el arma sube y vuelve sola.

Para mover todas las piezas a la vez se usa `workspace:BulkMoveTo`, que es más rápido que
cambiar el `CFrame` de cada pieza por separado.

Mientras ves este modelo, el arma de tu mano se esconde solo para ti con
`LocalTransparencyModifier = 1`. Los demás siguen viéndola.

## Boca del cañón

Cada arma tiene un `Attachment` llamado `Muzzle` en la punta. El servidor dibuja la trazadora
desde ahí. En primera persona, tus propios disparos salen de la boca del arma que ves. Los
disparos de los demás muestran un fogonazo con una luz que dura un instante.

## Bonus: el machete

Revisando cómo se agarran las herramientas, encontré que el machete de los zombis tenía la hoja
hacia atrás. Ahora apunta al frente.
