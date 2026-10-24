# 28. Jugar con control (Xbox y PlayStation)

En consola no hay teclado ni mouse, así que cada acción necesita un botón del control.

## Botones

| Acción | Teclado | Xbox | PlayStation |
|---|---|---|---|
| Disparar | Clic | RT | R2 |
| Apuntar / mira | Clic derecho | LT | L2 |
| Cambiar de arma | 1 / 2 | LB / RB | L1 / R1 |
| Granada (mantén y suelta) | G | B | Círculo |
| Recargar | R | X | Cuadrado |
| Golpe | F | Apretar stick derecho (RS) | R3 |
| Cámara 1ª / 3ª persona | V | Y | Triángulo |
| Cambiar por el arma del suelo | E | Flecha arriba | Flecha arriba |
| Tienda | B | Flecha abajo | Flecha abajo |
| Menú / botones de la sala | M | Flecha derecha | Flecha derecha |
| Correr (mantén) | Shift | Apretar stick izquierdo (LS) | L3 |
| Saltar | Espacio | A | Equis |

## Qué arreglamos

1. **Granadas.** Estaban en LB/L1, pero Roblox ya usa LB y RB para cambiar de arma, y
   ganaba Roblox. Ahora la granada va en B / Círculo.
2. **Apuntar.** `Aim.luau` usaba la posición del mouse. En consola no hay mouse, así que
   ahora, si lo último que tocaste fue el control (`GetLastInputType` empieza con
   "Gamepad"), se apunta al **centro de la pantalla**. La mira (`Crosshair.luau`) usa
   el mismo punto.
3. **Recargar** no tenía botón: ahora es X / Cuadrado. Por eso el golpe pasó a R3.
4. **Cambiar arma del suelo**: el `ProximityPrompt` usaba X por defecto y chocaba con
   recargar. Ahora usa `GamepadKeyCode = DPadUp`.
5. **Tienda**: se abre con la flecha abajo. Al abrirla se selecciona un botón
   (`GuiService.SelectedObject`) para que puedas moverte con el stick y elegir con A.
6. **Selección "pegada" en el menú** (`MainMenu.luau`): en PS5, después de "Invitar
   amigos", el botón se quedaba seleccionado y el stick y los gatillos movían la selección
   en vez del personaje. Ahora la selección se suelta sola al apretar un botón de la sala,
   al cerrar la ventana de invitaciones y al cerrar el menú. La flecha derecha entra a los
   botones de la sala (o abre el menú en una partida rápida). Si algún día se queda pegada,
   Círculo / B también la suelta (eso lo hace Roblox).

## Para probar sin consola

En Studio conecta un control de Xbox a tu PC (o uno de PlayStation) y dale *Play*:
Roblox lo reconoce solo.

## Otros ajustes de esta versión

- **Correr** (`SprintController.luau`, `Config/Movement.luau`): mientras mantienes Shift
  la velocidad sube de 16 a 24. Los zombis no corren porque ya son rápidos. Si el arma de
  hielo te frenó, tampoco: solo se corre desde la velocidad normal.
- **Más luz** en Fortines, La Estación y Cámara Fría (`Config/Maps.luau`, `lighting`).
  Hay dos valores nuevos opcionales:
  - `ambient`: la luz que llega a donde no da el sol (bajo techo, entre muros).
  - `exposure`: sube la luz de toda la pantalla.
  Si un mapa no los trae, `MapService` usa los normales.
- **Fortines**: el muro bajo frente a la plataforma era tan largo que junto a los brazos
  quedaba un hueco de 2 studs. Ahora mide de z = -38 a 38 y deja un paso de 12 studs.
- **La Barranca con jeeps en todos los modos**: `Config/Maps.luau` tiene
  `alwaysVehicles = { Barranca = true }`. `MatchService` enciende los jeeps si el modo los
  permite **o** si el mapa está en esa lista.
- **Armas con las dos manos** (`Services/TwoHands.luau`): Roblox pone la herramienta solo
  en la mano derecha. En las armas largas, un `IKControl` lleva la mano izquierda al
  punto `LeftHandGrip` del arma (lo pone `WeaponModels.Dress` con el `leftHand` de cada
  arma). La pistola, el arma de hielo y las de golpe llevan `oneHand = true` y se quedan
  con una mano.
