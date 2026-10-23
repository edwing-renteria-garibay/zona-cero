# 27. Solo dos armas a la vez

Como en Halo, cada jugador carga como máximo **2 armas de fuego**. Se aparece con rifle y
pistola, así que ya va con las manos llenas.

## Cómo se juega

- **Pisar una plataforma** te da el arma solo si te cabe. Si ya la traes, te rellena la munición.
- **Con las manos llenas**, al acercarte aparece el botón **Cambiar** (tecla **E**, o mantener
  el botón en móvil). Al pulsarlo, sueltas el arma que llevas en la mano y tomas la de la
  plataforma, que ya queda en tu mano.
- Si no llevas ningún arma en la mano, se cambia la primera que cargas.
- Las granadas no cuentan: se recogen siempre que no tengas el máximo.

## Cómo está hecho

Todo está en `src/server/Services/PickupService.luau`:

1. `carriedWeapons` junta las armas de fuego del jugador: las de su personaje (la de la mano)
   y las de su mochila (`Backpack`). Solo cuenta las que están en `Config/Weapons`, así que
   el machete o el pollo de hule no cuentan.
2. Al pisar la plataforma se llama a `give` con `swap = false`: si ya cargas el máximo, no te
   da nada y la plataforma no se gasta.
3. Cada plataforma de arma tiene un `ProximityPrompt`: el botón que Roblox muestra solo cuando
   estás cerca. Al pulsarlo se llama a `give` con `swap = true`, que borra el arma de la mano,
   te da la nueva y te la pone en la mano con `Humanoid:EquipTool`.

## Cambiarlo

El máximo es `maxWeapons` en `Modes.Common` (`src/shared/Config/Modes.luau`). Pon 3 si quieres
cargar tres. Un modo puede tener su propio `maxWeapons`.

En el modo de prueba (`Modes.Testing.enabled = true`) se aparece con las 9 armas y no hay
límite.
