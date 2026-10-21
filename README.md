# Zona Cero (nombre de trabajo)

Shooter de arena por equipos para Roblox, estilo Halo: Combat Evolved en línea, con vehículos.
Documento de diseño: https://claude.ai/artifact/Db9y3BWdNtESCJbiRrMR1z

## Qué hay ya

- Equipos Rojo y Azul con asignación automática
- Escudo + vida estilo Halo (`src/server/Services/HealthService.luau`)
- Ciclo de partida de Team Slayer: espera, cuenta regresiva, marcador, ganador (`MatchService.luau`)
- Configuración de armas, vehículos y modos en `src/shared/Config/`

## Cómo abrirlo en Roblox Studio

1. Instala [Rokit](https://github.com/rojo-rbx/rokit) y, en esta carpeta, ejecuta `rokit install` (instala Rojo, Selene y StyLua).
2. En Roblox Studio instala el plugin de Rojo (Plugins > Manage Plugins, o con `rojo plugin install`).
3. En esta carpeta ejecuta `rojo serve`.
4. En Studio abre un lugar vacío (Baseplate), pulsa **Connect** en el plugin de Rojo y el código aparecerá en el Explorer.
5. Pulsa **Play** con 2 jugadores (pestaña Test > Clients and Servers) para ver la partida empezar en la ventana Output.

## Estructura

```
src/shared/  -> ReplicatedStorage.Shared   (código y datos que ven cliente y servidor)
src/server/  -> ServerScriptService.Server (lógica del juego; el servidor manda)
src/client/  -> StarterPlayerScripts.Client (HUD, cámara, controles)
```
