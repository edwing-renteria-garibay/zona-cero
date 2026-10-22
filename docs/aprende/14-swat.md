# 14 · SWAT y SWAT explosivo

Dos variantes de Asesino por equipos, sin escudos (solo los 100 de vida):

| | SWAT | SWAT explosivo |
|---|---|---|
| Armas | rifle y pistola | solo lanzacohetes, cohetes infinitos |
| Tiro a la cabeza | mata de un tiro | — |
| Granadas, objetos del mapa y jeeps | no hay | no hay |
| Para ganar | 50 bajas | 50 bajas |

El modo aleatorio puede elegir cualquiera de las dos. El marcador de arriba muestra el
nombre del modo que se está jugando.

## Las reglas de cada modo

En `src/shared/Config/Modes.luau` cada modo puede cambiar lo que trae `Modes.Common`:

- `loadout`: armas con las que se aparece (por defecto rifle y pistola).
- `shields = false`: sin escudo.
- `grenades = 0`: granadas al aparecer.
- `pickups = false`: las plataformas del mapa (lanzacohetes, granadas) se apagan.
- `vehicles = false`: no hay jeeps.
- `infiniteAmmo = true`: repuesto infinito.
- `headshotKills = true`: un tiro a la cabeza mata.

Para inventar otra variante basta con copiar un modo, cambiar estos valores y agregarlo
a `Modes.randomPool`.

## Cómo llegan las reglas a cada parte del juego

`src/server/Services/Rules.luau` guarda las reglas del modo actual en `Rules.current`.
`MatchService` lo cambia al empezar cada partida, y los demás servicios lo leen:

- `LoadoutService` da las armas al aparecer, copiándolas de `ServerStorage.Weapons`.
  Por eso las armas ya no están en `StarterPack`: si estuvieran ahí, Roblox se las daría a
  todos en todos los modos.
- `HealthService` pone el escudo en 0 si `shields = false`.
- `ProjectileService` da las granadas.
- `PickupService` apaga las plataformas.
- `CombatService` hace que la cabeza mate en SWAT.
- `VehicleService.SetEnabled` quita o regresa los jeeps.

## Para probar

En `Modes.luau` pon `Modes.selected = "SWAT"` o `"SWATExplosive"` y abre Servidor y
clientes con 2 jugadores. Revisa que no haya escudo ni jeeps, y las armas de cada variante.
Al terminar regresa `selected` a `"Aleatorio"`.
