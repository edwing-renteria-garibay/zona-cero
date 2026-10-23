-- Reglas de cada modo de juego. name es el nombre que ven los jugadores.
-- teams: false = cada quien por su cuenta (Asesino en solitario): gana el primer jugador en
-- llegar a scoreToWin bajas
-- minScoreToWin: si un modo lo tiene, la meta depende de cuántos jugadores hay al empezar
-- (ver scaleScore en Common)
-- scoreBy: con qué suma puntos un equipo ("kills" = bajas, "captures" = banderas capturadas,
-- "hill" = segundos solo en la colina)
local Modes = {
	TeamSlayer = {
		name = "Asesino por equipos",
		scoreToWin = 50, -- con muchos jugadores (ver scaleScore en Common)
		minScoreToWin = 25, -- con pocos jugadores
		timeLimit = 600,
		teams = true,
		vehicles = true,
		scoreBy = "kills",
	},
	-- SWAT: sin escudos, sin granadas, sin objetos en el mapa ni jeeps; solo rifle y pistola,
	-- y un tiro a la cabeza mata
	SWAT = {
		name = "SWAT",
		scoreToWin = 50, -- con muchos jugadores (ver scaleScore en Common)
		minScoreToWin = 25, -- con pocos jugadores
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
		scoreToWin = 50, -- con muchos jugadores (ver scaleScore en Common)
		minScoreToWin = 25, -- con pocos jugadores
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
		scoreToWin = 30, -- con muchos jugadores
		minScoreToWin = 15, -- con pocos jugadores
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
	-- Infección: zombis contra sobrevivientes (ver InfectionService)
	Infection = {
		name = "Infección",
		scoreToWin = 0, -- no aplica: ganan los zombis si infectan a todos
		timeLimit = 300, -- si queda un sobreviviente al acabarse el tiempo, ganan ellos
		teams = false,
		vehicles = false,
		scoreBy = "infection",
		pickups = false,
		playersPerZombie = 4, -- 1 zombi por cada 4 jugadores...
		maxZombies = 6, -- ...hasta 6 (siempre al menos 1)
		zombieSpeed = 26, -- los sobrevivientes caminan a 16
		zombieHealth = 150, -- vida de un zombi (sin escudo); un sobreviviente tiene 100 + 100 de escudo
		zombieMeleeDamage = 1000, -- un golpe de zombi mata
	},
	-- Asalto: una bomba; un equipo ataca y otro defiende, y cada ronda se cambian
	Assault = {
		name = "Asalto",
		scoreToWin = 3, -- bombas detonadas para ganar
		timeLimit = 900,
		teams = true,
		vehicles = true,
		scoreBy = "bombs",
		roundTime = 150, -- segundos por ronda; si nadie detona, se cambian los papeles
		roundBreak = 4, -- segundos de pausa entre rondas
		pickupRadius = 5, -- studs para tomar la bomba
		plantRadius = 8, -- radio de la zona naranja (en la base enemiga) donde se arma
		armTime = 3, -- segundos que hay que quedarse ahí para que explote
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
-- en cada partida. Captura la bandera y Asalto solo se eligen si el mapa tiene bases de bandera.
Modes.selected = "Aleatorio"
Modes.randomPool = {
	"TeamSlayer",
	"FreeForAll",
	"CaptureTheFlag",
	"KingOfTheHill",
	"SWAT",
	"SWATExplosive",
	"Infection",
	"Assault",
}

-- Modo de prueba: con enabled = true todas las partidas son cortas para probar rápido todos
-- los mapas y modos. Para jugar normal, ponlo en false.
Modes.Testing = {
	enabled = true,
	scoreToWin = 2, -- bajas, banderas o bombas para ganar
	hillSeconds = 20, -- Rey de la colina: segundos en la colina para ganar
	timeLimit = 120, -- segundos por partida
	roundTime = 50, -- Asalto: segundos por ronda
	-- Armas con las que aparece todo el mundo (teclas 1 a 9) para probarlas todas.
	-- Bórralo (o pon nil) para aparecer con las armas normales de cada modo.
	loadout = {
		"AssaultRifle",
		"Pistol",
		"RocketLauncher",
		"Shotgun",
		"Sniper",
		"LaserRifle",
		"IceGun",
		"Flamethrower",
		"IonCannon",
	},
}

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
	-- Meta según jugadores (solo modos con minScoreToWin): con lowPlayers o menos la meta es
	-- minScoreToWin, con highPlayers o más es scoreToWin, y en medio sube poco a poco
	-- (redondeada de 5 en 5). Ej.: 10 jugadores = 25, 20 = 40, 30 = 50
	scaleScore = { lowPlayers = 10, highPlayers = 30 },
}

return Modes
