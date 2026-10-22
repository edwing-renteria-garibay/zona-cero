-- Reglas de cada modo de juego. name es el nombre que ven los jugadores.
-- teams: false = cada quien por su cuenta (Asesino en solitario): gana el primer jugador en
-- llegar a scoreToWin bajas
-- scoreBy: con qué suma puntos un equipo ("kills" = bajas, "captures" = banderas capturadas,
-- "hill" = segundos solo en la colina)
local Modes = {
	TeamSlayer = {
		name = "Asesino por equipos",
		scoreToWin = 50,
		timeLimit = 600,
		teams = true,
		vehicles = true,
		scoreBy = "kills",
	},
	-- SWAT: sin escudos, sin granadas, sin objetos en el mapa ni jeeps; solo rifle y pistola,
	-- y un tiro a la cabeza mata
	SWAT = {
		name = "SWAT",
		scoreToWin = 50,
		timeLimit = 600,
		teams = true,
		vehicles = false,
		scoreBy = "kills",
		loadout = { "AssaultRifle", "Pistol" },
		shields = false,
		grenades = 0,
		pickups = false,
		headshotKills = true,
	},
	-- SWAT explosivo: igual, pero solo con lanzacohetes y cohetes infinitos
	SWATExplosive = {
		name = "SWAT explosivo",
		scoreToWin = 50,
		timeLimit = 600,
		teams = true,
		vehicles = false,
		scoreBy = "kills",
		loadout = { "RocketLauncher" },
		infiniteAmmo = true,
		shields = false,
		grenades = 0,
		pickups = false,
	},
	-- Asesino en solitario: todos contra todos
	FreeForAll = {
		name = "Asesino en solitario",
		scoreToWin = 30,
		timeLimit = 600,
		teams = false,
		vehicles = false,
		scoreBy = "kills",
	},
	CaptureTheFlag = {
		name = "Captura la bandera",
		scoreToWin = 3,
		timeLimit = 900,
		teams = true,
		vehicles = true,
		scoreBy = "captures",
		pickupRadius = 5, -- studs para tomar o regresar una bandera
		captureRadius = 6, -- studs de tu base para capturar
		flagReturnTime = 30, -- segundos que una bandera tirada tarda en volver sola
	},
	KingOfTheHill = {
		name = "Rey de la colina",
		scoreToWin = 120, -- segundos en la colina para ganar
		timeLimit = 600,
		teams = true,
		vehicles = true,
		scoreBy = "hill",
		hillRadius = 16, -- radio de la colina en studs (32 de ancho)
		moveEvery = 60, -- segundos antes de que la colina cambie de lugar (0 = no se mueve)
		minSpawnDistance = 40, -- qué tan lejos de cualquier punto de aparición debe quedar
		minMoveDistance = 120, -- al moverse, qué tan lejos debe quedar de los lugares anteriores
		rememberSpots = 2, -- cuántos lugares anteriores evita (así no regresa a la misma zona)
	},
}

-- Qué modo se juega: el nombre de un modo, o "Aleatorio" para elegir uno de randomPool
-- en cada partida. Captura la bandera solo se elige si el mapa tiene bases de bandera.
Modes.selected = "Aleatorio"
Modes.randomPool = { "TeamSlayer", "FreeForAll", "CaptureTheFlag", "KingOfTheHill", "SWAT", "SWATExplosive" }

-- Valores comunes a todos los modos. Un modo puede cambiar algunos con su propio valor:
-- loadout (armas al aparecer), shields = false (sin escudo), grenades (granadas al aparecer),
-- pickups = false (sin objetos en el mapa), vehicles = false (sin jeeps),
-- infiniteAmmo = true (repuesto infinito), headshotKills = true (la cabeza mata de un tiro)
Modes.Common = {
	loadout = { "AssaultRifle", "Pistol" },
	respawnDelay = 5, -- segundos muerto antes de reaparecer
	spawnProtection = 2, -- segundos de invulnerabilidad al reaparecer
	minPlayers = 2, -- jugadores necesarios para empezar
	countdown = 10, -- cuenta regresiva antes de la partida
	resultsTime = 12, -- segundos que se muestra la pantalla de resultados
}

return Modes
