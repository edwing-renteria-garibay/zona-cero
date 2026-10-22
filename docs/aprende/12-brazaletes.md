# 12 · Brazaletes del equipo

Cada jugador conserva su avatar de Roblox, pero lleva una banda del color de su equipo
(rojo o azul) en la parte de arriba de cada brazo. Así se distingue a un aliado de un
enemigo sin cambiarle la ropa a nadie.

El código está en `src/server/Services/TeamMarkers.luau`.

## Cómo funciona

1. Cuando aparece el personaje (`CharacterAdded` en `init.server.luau`), el servidor llama
   a `TeamMarkers.SetupCharacter(player, character)`.
2. Busca los brazos por nombre. Los avatares R15 tienen `LeftUpperArm` y `RightUpperArm`;
   los R6 tienen `Left Arm` y `Right Arm`. Se prueban los cuatro nombres.
3. A cada brazo le pega una pieza (`Part`) llamada `TeamArmband`, un poco más ancha que el
   brazo para que se vea por encima de la ropa.
4. La pieza se une al brazo con un `WeldConstraint`, así se mueve con él.
5. El color sale de `player.TeamColor`. Si el jugador cambia de equipo, se vuelve a pintar.

## Detalles importantes

- `CanCollide = false`: el brazalete no choca con nada.
- `CanQuery = false`: las balas lo atraviesan y le pegan al brazo, así que el daño no cambia.
- `Massless = true`: no pesa, no afecta cómo camina el personaje.

## Para probar

En Studio pulsa **Prueba > Iniciar sesión de prueba > Servidor y clientes** (F7) y añade un
segundo cliente. Cada jugador debe verse con bandas rojas o azules en los brazos.

## Para cambiarlo

- Más gruesa o más delgada: cambia `BAND_HEIGHT` (fracción del largo del brazo).
- Más arriba o más abajo: cambia el `0.15` en el `CFrame.new(0, arm.Size.Y * 0.15, 0)`.
