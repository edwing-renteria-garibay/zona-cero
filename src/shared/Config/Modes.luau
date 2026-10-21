-- Reglas de cada modo de juego.
local Modes = {
	TeamSlayer = { scoreToWin = 50, timeLimit = 600, teams = true, vehicles = true },
	FreeForAll = { scoreToWin = 25, timeLimit = 480, teams = false, vehicles = false },
}

-- Valores comunes a todos los modos
Modes.Common = {
	respawnDelay = 5, -- segundos muerto antes de reaparecer
	spawnProtection = 2, -- segundos de invulnerabilidad al reaparecer
	minPlayers = 2, -- jugadores necesarios para empezar
	countdown = 10, -- cuenta regresiva antes de la partida
}

return Modes
