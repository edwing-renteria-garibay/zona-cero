# Zona Cero (nombre de trabajo)

Shooter de arena por equipos para Roblox, estilo Halo: Combat Evolved en línea, con vehículos.
Documento de diseño: https://claude.ai/artifact/Db9y3BWdNtESCJbiRrMR1z

## Qué hay ya

- Equipos Rojo y Azul con asignación automática
- Escudo + vida estilo Halo (`src/server/Services/HealthService.luau`)
- Ciclo de partida de Team Slayer: espera, cuenta regresiva, marcador, ganador (`MatchService.luau`)
- Modo **Asesino en solitario**: todos contra todos, gana el primero en llegar a 30 bajas; cada quien reaparece en un punto al azar sin enemigos cerca
- Modo **Rey de la colina**: la colina aparece en un lugar al azar al que los dos equipos pueden llegar, y se mueve cada 60 s
- Modo **Captura la bandera**: una bandera en una esquina de cada base; tómala, llévala a tu base y captura (el modo se elige en `src/shared/Config/Modes.luau`; viene en `"Aleatorio"`)
- Marcador en pantalla con el tiempo, registro de bajas (quién eliminó a quién y con qué) y pantalla de resultados al terminar
- Rifle de asalto: disparo con clic o toque, recarga con **R**, daño validado en el servidor
- HUD con escudo, vida y munición; columnas de **Bajas** y **Muertes** en la lista de jugadores
- Mira para el rifle y la torreta, que se pone roja al acertar (naranja en la cabeza)
- Pistola tipo Desert Eagle; más daño en la cabeza que en el cuerpo en todas las armas
- Cámara en primera persona; **V** cambia a tercera persona sobre el hombro (y vuelve)
- Golpe cuerpo a cuerpo con **F** (o botón en móvil); por la espalda mata de un golpe
- Mapa **Cañón Rojo** (greybox): base baja, zona de spawn y base alta por equipo; montículo central, dos carriles, cornisas altas y cuartos con granadas
- Mapa **Fortines** (greybox, diseño de edwing): 200 × 200 studs, dos fuertes amurallados frente a frente con tres accesos cada uno, una plaza en medio y una plataforma al fondo con la base de la bandera. Sin jeeps
- Mapa **El Cruce** (greybox, inspirado en Rat Race de Halo CE): base Azul en lo alto con tres rampas, túneles techados en medio y base Roja con columnas al sur
- El mapa se elige en `src/shared/Config/Maps.luau` (o `"Aleatorio"`)
- Lanzacohetes en lo alto del montículo central (reaparece a los 120 s): el cohete vuela y explota; un impacto directo mata y dos destruyen un jeep
- Granadas con **G** (2 por vida): mantén G para ver dónde caerá y suelta para lanzarla; explotan al chocar o a los 1.5 s
- Jeep con torreta: conductor (W/A/S/D), artillero con ametralladora y pasajero; llantas que se ponchan, barra de vida, se destruye y reaparece
- Brazaletes del color del equipo (rojo o azul) en ambos brazos, sin cambiar el avatar
- Configuración de armas, vehículos y modos en `src/shared/Config/`

Para entender el código paso a paso, lee las guías de [`docs/aprende/`](docs/aprende/).

## Cómo abrirlo en Roblox Studio

1. Instala [Rokit](https://github.com/rojo-rbx/rokit) y, en esta carpeta, ejecuta `rokit install` (instala Rojo, Selene y StyLua).
2. En Roblox Studio instala el plugin de Rojo (Plugins > Manage Plugins, o con `rojo plugin install`).
3. En esta carpeta ejecuta `rojo serve`.
4. En Studio abre un lugar vacío (Baseplate), pulsa **Connect** en el plugin de Rojo y el código aparecerá en el Explorer.
5. Abre **Ventana > Salida** y pulsa **Prueba > Iniciar sesión de prueba > Servidor y clientes** (F7). Con la sesión iniciada, usa **Prueba > Añadir clientes** para tener 2 jugadores: la partida empieza con 2.
6. Para probar las armas, en cada ventana de jugador pulsa **1** (rifle) o **2** (pistola) y dispárale al otro jugador. Con **F** golpeas cuerpo a cuerpo y con **G** apuntas una granada (suelta para lanzarla). El lanzacohetes está en lo alto del montículo central; recógelo y usa **3**.
7. Para probar el jeep, camina hacia uno de los dos jeeps (a 25 studs a cada lado del punto de aparición) y siéntate: delante a la izquierda conduces, detrás disparas la torreta. **Espacio** para bajar.

## Estructura

```
src/shared/  -> ReplicatedStorage.Shared   (código y datos que ven cliente y servidor)
src/server/  -> ServerScriptService.Server (lógica del juego; el servidor manda)
src/client/  -> StarterPlayerScripts.Client (HUD, cámara, controles)
```
