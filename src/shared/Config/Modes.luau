-- Reglas de cada modo de juego.
-- scoreBy: con qué suma puntos un equipo ("kills" = bajas, "captures" = banderas capturadas)
local Modes = {
	TeamSlayer = { scoreToWin = 50, timeLimit = 600, teams = true, vehicles = true, scoreBy = "kills" },
	FreeForAll = { scoreToWin = 25, timeLimit = 480, teams = false, vehicles = false, scoreBy = "kills" },
	CaptureTheFlag = {
		scoreToWin = 3,
		timeLimit = 900,
		teams = true,
		vehicles = true,
		scoreBy = "captures",
		pickupRadius = 5, -- studs para tomar o regresar una bandera
		captureRadius = 6, -- studs de tu base para capturar
		flagReturnTime = 30, -- segundos que una bandera tirada tarda en volver sola
	},
}

-- Qué modo se juega: el nombre de un modo, o "Aleatorio" para elegir uno de randomPool
-- en cada partida. Captura la bandera solo se elige si el mapa tiene bases de bandera.
Modes.selected = "CaptureTheFlag"
Modes.randomPool = { "TeamSlayer", "CaptureTheFlag" }

-- Valores comunes a todos los modos
Modes.Common = {
	respawnDelay = 5, -- segundos muerto antes de reaparecer
	spawnProtection = 2, -- segundos de invulnerabilidad al reaparecer
	minPlayers = 2, -- jugadores necesarios para empezar
	countdown = 10, -- cuenta regresiva antes de la partida
	resultsTime = 12, -- segundos que se muestra la pantalla de resultados
}

return Modes
