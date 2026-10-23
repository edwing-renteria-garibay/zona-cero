# 29. Machetazo y botón de recarga

## Golpe con machete

Antes el golpe (F, R3 en control, botón "Golpe" en móvil) era con la mano y costaba
atinarle: solo pegaba a quien estuviera justo enfrente, a menos de 6 studs.

Ahora todos llevan un machete al cinto:

- **Se ve**: en primera persona el arma baja y el machete cruza la pantalla de derecha a
  izquierda (`ViewModel.Bash` y `updateSwing` en `ViewModel.luau`). Si ya llevas el
  machete o el pollo de hule en la mano, se usa esa arma como antes.
- **Es más fácil atinar** (`CombatService`, `onMelee`): busca enemigos en una esfera
  alrededor de ti del tamaño del alcance (`range = 8`) y cuenta a los que estén más o
  menos enfrente. `aimCone` en `Config/Melee.luau` dice qué tanto de lado:

  | aimCone | Ángulo a cada lado |
  |---|---|
  | 1 | 0° (solo justo enfrente) |
  | 0.7 | unos 45° |
  | 0.4 | unos 66° (el que pusimos) |
  | 0 | 90° |

- En el registro de bajas sale como **Machete**. Por la espalda sigue matando de un golpe.

## Botón de recarga

Recargar era una tecla suelta (`UserInputService`), así que en celular no había botón.
Ahora es una acción de `ContextActionService`, como la granada y el golpe. El `true`
de `BindAction` crea el botón táctil **Recargar** en móvil. Las teclas no cambian: **R**
en teclado y **X / Cuadrado** en control.
