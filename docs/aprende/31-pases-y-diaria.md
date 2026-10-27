# 31. Pases de juego y premio diario

Dos cosas nuevas para ganar más Robux y para que la gente regrese cada día.

## Pases de juego

Un **pase de juego** (Game Pass) se compra una sola vez con Robux y es para siempre. Roblox
recuerda quién lo compró, así que no hay que guardarlo nosotros.

| Pase | Precio | Qué da |
|---|---|---|
| VIP | 199 Robux | Doble de créditos jugando (bajas, asistencias, partidas) y en el premio diario |
| Pack Leyenda | 299 Robux | La armadura Leyenda completa (morada) y la skin Leyenda para las armas |

Las cosas Leyenda salen en la tienda con el botón del pase: no se compran con créditos.
Los paquetes de créditos con Robux **no** se doblan con el VIP (así no se regalan créditos).

Salen en la pestaña **Robux** de la tienda. Mientras su `id` sea `0` dicen "Próximamente".

### Cómo crearlos (una vez)

1. Entra a [create.roblox.com](https://create.roblox.com) > **Creaciones** > Escuadrón Cero.
2. Menú de la izquierda: **Monetización > Pases**.
3. **Crear un pase**: sube una imagen, nombre `VIP`, descripción "Doble de créditos".
4. Ábrelo > **Ventas** > activa **Artículo en venta** > precio **199** > Guardar.
5. Copia el número del pase (el **ID**).
6. Repite con `Pack Leyenda` a **299**.
7. Pásale los dos ID a Claude, o ponlos tú en `src/shared/Config/Shop.luau`, en
   `Shop.gamePasses` (cambia los `id = 0`).
8. Publica como siempre: `rojo build -o zona-cero.rbxl` y "Actualizar la experiencia actual".

## Premio diario

Al entrar por primera vez en el día te llegan créditos, y si entras días seguidos sube:

| Día | 1 | 2 | 3 | 4 | 5 | 6 | 7 en adelante |
|---|---|---|---|---|---|---|---|
| Créditos | 50 | 75 | 100 | 125 | 150 | 200 | 300 |

Si faltas un día vuelve al día 1. El día cambia a medianoche UTC (las 6 de la tarde en
México centro). Los valores están en `Shop.daily`.

## Cómo funciona por dentro

- `ShopService.luau` pregunta al entrar `MarketplaceService:UserOwnsGamePassAsync` por cada
  pase y pone el atributo `Pass_VIP` o `Pass_Leyenda` en el jugador. Si compra dentro del
  juego, `PromptGamePassPurchaseFinished` se lo da en seguida.
- `addCredits(player, cantidad, true)`: el `true` quiere decir "ganado jugando", y solo
  esos se doblan con el VIP.
- El perfil guarda `daily = { last, streak }`: el último día que cobró y los días seguidos.
- El aviso de arriba ("Premio diario: +75 créditos") lo dibuja `UI/Shop.luau` cuando cambia
  el atributo `DailyReward`.
- Con `Modes.Testing.enabled` no hay premio diario (no se guarda nada).
