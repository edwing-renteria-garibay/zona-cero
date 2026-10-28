# 30. Jugar en celular

En celular no hay teclado ni mouse: todo se hace con los dedos. El pulgar izquierdo mueve
al soldado (el stick de Roblox) y el derecho mira arrastrando la pantalla y aprieta los
botones.

## Botones (abajo a la derecha, alrededor de Saltar)

| Botón | Qué hace |
|---|---|
| Disparar (el rojo, grande) | Lo mismo que el clic: dispara, usa la torreta, lanza SimiOs o golpea con el machete. Si arrastras el dedo sin soltarlo, también apuntas |
| Apuntar | Zoom del francotirador (solo sale con armas que tienen zoom) |
| Recargar | Recargar |
| Granada | Mantén para ver a dónde cae y suelta para lanzarla. Siendo zombi es la pócima |
| Golpe | Golpe cuerpo a cuerpo |
| Correr | Un toque para correr, otro para parar (queda amarillo mientras corres) |
| Cámara | 1.ª / 3.ª persona |

Arriba a la izquierda van **Tienda**, **Menú** (o los botones de la sala) y **Puntajes**.

## Qué arreglamos

1. **No había botón de disparar.** Antes se disparaba tocando la pantalla, pero el mismo
   dedo también mueve la cámara, y la bala iba a donde tocabas. Ahora hay botón, la mira
   está siempre en el centro (`Aim.luau`, igual que con control) y tocar la pantalla ya no
   dispara (`tool.ManualActivationOnly`).
2. **Botones encimados y cortados.** Eran los botones automáticos de Roblox (el `true` de
   `BindAction`). Los cambiamos por los nuestros en `UI/TouchButtons.luau`, que llaman a
   las mismas acciones con `ContextActionService:CallFunction`. Así una tecla y un botón
   hacen exactamente lo mismo.
3. **HUD tapado.** En celular el escudo, la vida y las balas van en el centro, arriba de la
   barra de armas (`HUD.luau`).
4. **El menú no se cerraba y te sacaba del juego.** El menú era más alto que la pantalla y
   los botones de la izquierda (Salir, Invitar...) quedaban **encima** del menú y de la
   tienda: al tocar el menú se apretaba "Salir a partida rápida". Ahora el menú cabe en la
   pantalla, tiene una **X** para cerrarse, esos botones se esconden mientras hay un menú
   abierto y "Salir a partida rápida" pide un segundo toque.

`Controllers/Mobile.luau` tiene `Mobile.IsTouch()` (pantalla táctil sin mouse), que usan
todos estos archivos para saber si están en celular.

## Probar sin celular

En Studio: pestaña **Test** → **Device** (el ícono del celular) → elige un celular, por
ejemplo *iPhone 14*, y gíralo a horizontal. Luego **Play**. Studio simula la pantalla
táctil y el mouse funciona como dedo. Si ahí no salen los botones, la prueba buena es en el
celular de verdad (publica y entra desde la app de Roblox).

## Apuntar mientras disparas

Al principio el botón Disparar solo disparaba: había que apuntar con un dedo y luego
disparar con otro. Ahora, si dejas el dedo en Disparar y lo arrastras, la cámara gira igual
que al arrastrar la pantalla (`CameraController.Look`). La velocidad está en
`LOOK_SPEED` de `UI/TouchButtons.luau` (0.35 grados por punto); súbela si se siente lenta.

## El stick izquierdo solo mueve

En celular Roblox usa por defecto la cámara "Follow": al moverte hacia un lado con el stick
izquierdo, la cámara gira sola hacia donde caminas. En un juego de disparos eso estorba,
porque el stick cambiaba hacia dónde apuntabas. En `default.project.json`, dentro de
`StarterPlayer`, pusimos:

- `DevTouchCameraMovementMode = Classic`: la cámara solo gira cuando tú la mueves (con el
  botón Disparar o arrastrando la pantalla).
- `DevTouchMovementMode = Thumbstick`: el stick fijo de siempre, para avanzar, retroceder y
  moverte de lado.

Si lo cambias en Studio, está en **StarterPlayer** → Propiedades → *Mobile*.
