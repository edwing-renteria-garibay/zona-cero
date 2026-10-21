# Zona Cero (nombre de trabajo)

Shooter de arena por equipos para Roblox, estilo Halo: Combat Evolved en línea, con vehículos.
Documento de diseño: https://claude.ai/artifact/Db9y3BWdNtESCJbiRrMR1z

## Qué hay ya

- Equipos Rojo y Azul con asignación automática
- Escudo + vida estilo Halo (`src/server/Services/HealthService.luau`)
- Ciclo de partida de Team Slayer: espera, cuenta regresiva, marcador, ganador (`MatchService.luau`)
- Rifle de asalto: disparo con clic o toque, recarga con **R**, daño validado en el servidor
- HUD con escudo, vida y munición; columna de **Bajas** en la lista de jugadores
- Jeep con torreta: conductor (W/A/S/D), artillero con ametralladora y pasajero; llantas que se ponchan, barra de vida, se destruye y reaparece
- Configuración de armas, vehículos y modos en `src/shared/Config/`

Para entender el código paso a paso, lee las guías de [`docs/aprende/`](docs/aprende/).

## Cómo abrirlo en Roblox Studio

1. Instala [Rokit](https://github.com/rojo-rbx/rokit) y, en esta carpeta, ejecuta `rokit install` (instala Rojo, Selene y StyLua).
2. En Roblox Studio instala el plugin de Rojo (Plugins > Manage Plugins, o con `rojo plugin install`).
3. En esta carpeta ejecuta `rojo serve`.
4. En Studio abre un lugar vacío (Baseplate), pulsa **Connect** en el plugin de Rojo y el código aparecerá en el Explorer.
5. Abre **Ventana > Salida** y pulsa **Prueba > Iniciar sesión de prueba > Servidor y clientes** (F7). Con la sesión iniciada, usa **Prueba > Añadir clientes** para tener 2 jugadores: la partida empieza con 2.
6. Para probar el rifle, en cada ventana de jugador pulsa **1** para sacar el arma y dispárale al otro jugador.
7. Para probar el jeep, camina hacia uno de los dos jeeps (a 25 studs a cada lado del punto de aparición) y siéntate: delante a la izquierda conduces, detrás disparas la torreta. **Espacio** para bajar.

## Estructura

```
src/shared/  -> ReplicatedStorage.Shared   (código y datos que ven cliente y servidor)
src/server/  -> ServerScriptService.Server (lógica del juego; el servidor manda)
src/client/  -> StarterPlayerScripts.Client (HUD, cámara, controles)
```
