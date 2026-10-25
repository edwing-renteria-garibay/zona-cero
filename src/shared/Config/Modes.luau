-- Reglas de cada modo de juego. name es el nombre que ven los jugadores.
-- teams: false = cada quien por su cuenta (Asesino en solitario): gana el primer jugador en
-- llegar a scoreToWin bajas
-- minScoreToWin: si un modo lo tiene, la meta depende de cuántos jugadores hay al empezar
-- (ver scaleScore en Common)
-- scoreBy: con qué suma puntos un equipo ("kills" = bajas, "captures" = banderas capturadas,
-- "hill" = segundos solo en la colina)
-- bots: true = los bots saben jugar este modo (Config/Bots); sin eso, no entran bots
local Modes = {
	TeamSlayer = {
		name = "Asesino por equipos",
		scoreToWin = 50, -- con muchos jugadores (ver scaleScore en Common)
		minScoreToWin = 25, -- con pocos jugadores
		timeLimit = 600,
		teams = true,
		vehicles = true,
		scoreBy = "kills",
		bots = true, -- con pocos jugadores se rellena con bots (Config/Bots)
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
		bots = true, -- con pocos jugadores se rellena con bots (Config/Bots)
		loadout = { "AssaultRifle", "Pistol" },
		shields = false,
		grenades = 0,
		pickups = false,
		headshotKills = true,
		testingKeepsLoadout = true, -- también en el modo de prueba: solo rifle y pistola
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
		testingKeepsLoadout = true, -- también en el modo de prueba: solo lanzacohetes
	},
	-- A puño limpio: sin armas de fuego ni granadas; solo el machete (clic o F). Por la espalda, mata de uno
	Brawl = {
		name = "A puño limpio",
		scoreToWin = 30, -- con muchos jugadores (ver scaleScore en Common)
		minScoreToWin = 15, -- con pocos jugadores
		timeLimit = 600,
		teams = true,
		vehicles = false,
		scoreBy = "kills",
		bots = true, -- con pocos jugadores se rellena con bots (Config/Bots)
		loadout = { "Machete" }, -- el machete en la mano, para que se vea el golpe
		testingKeepsLoadout = true, -- el modo de prueba no le da las 9 armas
		shields = false,
		grenades = 0,
		pickups = false,
	},
	-- Pollos y machetes: solo armas de golpe (Config/Melee.weapons)
	MeleeWeapons = {
		name = "Pollos y machetes",
		scoreToWin = 30, -- con muchos jugadores (ver scaleScore en Common)
		minScoreToWin = 15, -- con pocos jugadores
		timeLimit = 600,
		teams = true,
		vehicles = false,
		scoreBy = "kills",
		bots = true, -- con pocos jugadores se rellena con bots (Config/Bots)
		loadout = { "Machete", "RubberChicken" },
		testingKeepsLoadout = true,
		shields = false,
		grenades = 0,
		pickups = false,
	},
	-- Lluvia de SimiOs: sin armas; se lanzan Doctores SimiO infinitos (G) y se puede golpear
	SimiRain = {
		name = "Lluvia de SimiOs",
		scoreToWin = 50, -- con muchos jugadores (ver scaleScore en Common)
		minScoreToWin = 25, -- con pocos jugadores
		timeLimit = 600,
		teams = true,
		vehicles = false,
		scoreBy = "kills",
		bots = true, -- con pocos jugadores se rellena con bots (Config/Bots)
		loadout = {},
		testingKeepsLoadout = true,
		shields = false,
		grenades = 1, -- con infiniteGrenades nunca se acaba
		infiniteGrenades = true,
		grenadeStyle = "Simi",
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
		bots = true, -- con pocos jugadores se rellena con bots (Config/Bots)
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
		-- Las plataformas de armas y granadas siguen: los sobrevivientes se arman con lo que
		-- encuentren (los zombis no pueden recoger nada, ver PickupService)
		playersPerZombie = 4, -- 1 zombi por cada 4 jugadores...
		maxZombies = 6, -- ...hasta 6 (siempre al menos 1)
		zombieSpeed = 26, -- los sobrevivientes caminan a 16
		zombieJumpHeight = 13, -- saltan más alto que los sobrevivientes (7.2): suben a columnas y cajas
		zombieHealth = 150, -- vida de un zombi (sin escudo); un sobreviviente tiene 100 + 100 de escudo
		zombieMeleeDamage = 1000, -- un golpe de zombi mata
		zombieHeadStart = 5, -- segundos que los zombis del principio esperan quietos
		botZombies = true, -- se puede jugar contra la IA: los zombis son bots
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

-- Qué modo se juega: el nombre de un modo, o "Aleatorio" para ir pasando por los de
-- randomPool: sale cada uno una vez, en desorden, antes de repetir alguno (el mapa sí es al azar).
-- Captura la bandera y Asalto solo se eligen si el mapa tiene bases de bandera.
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
	"Brawl",
	"MeleeWeapons",
	"SimiRain",
}

-- Modo de prueba: con enabled = true todas las partidas son cortas para probar rápido todos
-- los mapas y modos. Para jugar normal, ponlo en false.
Modes.Testing = {
	enabled = false,
	scoreToWin = 2, -- bajas, banderas o bombas para ganar
	hillSeconds = 20, -- Rey de la colina: segundos en la colina para ganar
	timeLimit = 120, -- segundos por partida
	roundTime = 50, -- Asalto: segundos por ronda
	-- Con Modes.selected = "Aleatorio", los modos salen en el orden de randomPool en vez de
	-- al azar: así en 11 partidas se prueban todos
	inOrder = true,
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
-- infiniteAmmo = true (repuesto infinito), headshotKills = true (la cabeza mata de un tiro),
-- infiniteGrenades = true (las granadas no se acaban), grenadeStyle = "Simi" (se lanza un
-- Doctor SimiO en vez de granada), testingKeepsLoadout = true (el modo de prueba respeta su loadout)
Modes.Common = {
	loadout = { "AssaultRifle", "Pistol" },
	-- Armas de fuego que se pueden cargar a la vez, como en Halo. Con las manos llenas, una
	-- plataforma no te da el arma al pisarla: hay que pulsar E para cambiarla por la que
	-- llevas en la mano. El modo de prueba (Testing.loadout) se salta este límite.
	maxWeapons = 2,
	respawnDelay = 5, -- segundos muerto antes de reaparecer
	spawnProtection = 2, -- segundos de invulnerabilidad al reaparecer
	minPlayers = 2, -- jugadores necesarios para empezar (con Config/Bots activado basta 1)
	countdown = 10, -- cuenta regresiva antes de la partida
	resultsTime = 15, -- segundos que se muestra la pantalla de resultados (y el podio)
	-- Meta según jugadores (solo modos con minScoreToWin): con lowPlayers o menos la meta es
	-- minScoreToWin, con highPlayers o más es scoreToWin, y en medio sube poco a poco
	-- (redondeada de 5 en 5). Ej.: 10 jugadores = 25, 20 = 40, 30 = 50
	scaleScore = { lowPlayers = 10, highPlayers = 30 },
}

return Modes
