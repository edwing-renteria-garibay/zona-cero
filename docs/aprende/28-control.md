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

## Para probar sin consola

En Studio conecta un control de Xbox a tu PC (o uno de PlayStation) y dale *Play*:
Roblox lo reconoce solo.
