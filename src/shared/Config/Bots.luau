-- Bots: soldados que controla el servidor para jugar aunque no haya más gente.
-- Si hay menos jugadores que Modes.Common.minPlayers, la partida empieza igual con bots y
-- solo se eligen modos que los bots saben jugar (los que tienen bots = true en Config/Modes).
-- Cuando entra alguien a mitad de partida, un bot de su equipo se va para dejarle el lugar.
-- En las partidas "Contra la IA" del menú (ver MatchSettings) se usa vsAI en vez de fillTo.

return {
	enabled = true, -- false = sin bots: hay que esperar a minPlayers jugadores de verdad
	fillTo = 6, -- jugadores + bots que habrá en la partida (6 = 3 contra 3)

	-- Nombres de los bots (se toman en orden; a todos se les pone "[BOT]" delante)
	names = {
		"Coyote",
		"Halcón",
		"Jaguar",
		"Lobo",
		"Puma",
		"Tejón",
		"Cuervo",
		"Ocelote",
		"Zorro",
		"Bisonte",
	},

	-- Dificultad. En "Contra la IA" cada quien la elige en el menú; en las partidas rápidas y
	-- privadas se usa defaultDifficulty. Valores de cada nivel:
	--   reactionTime: segundos que tarda en empezar a disparar cuando te ve
	--   spread: grados que se desvía cada bala al azar (más = falla más)
	--   damageMultiplier: qué parte del daño normal hacen (0.7 = 70 %)
	--   sightRange: studs; más lejos de eso no te ve
	difficultyOrder = { "Beginner", "Intermediate", "Hard", "Extreme" }, -- orden en el menú
	defaultDifficulty = "Intermediate",
	difficulties = {
		Beginner = {
			name = "Principiante",
			reactionTime = 1.2,
			spread = 7,
			damageMultiplier = 0.45,
			sightRange = 110,
		},
		Intermediate = {
			name = "Intermedia",
			reactionTime = 0.6,
			spread = 3.5,
			damageMultiplier = 0.7,
			sightRange = 160,
		},
		Hard = {
			name = "Difícil",
			reactionTime = 0.35,
			spread = 2,
			damageMultiplier = 0.9,
			sightRange = 220,
		},
		Extreme = { name = "Extrema", reactionTime = 0.2, spread = 1, damageMultiplier = 1, sightRange = 300 },
	},
	preferredDistance = 35, -- studs: con un arma de fuego intenta quedarse a esta distancia

	-- Contra la IA (botón del menú): todos los jugadores en Azul y los bots rivales en Rojo.
	-- En los modos por equipos se juega teamSize contra teamSize: si faltan jugadores en Azul,
	-- entran bots aliados (cada amigo que llega toma el lugar de uno). Con más jugadores que
	-- teamSize, los dos equipos crecen. En el menú se puede elegir "sin aliados": los
	-- jugadores solos contra los teamSize bots rivales.
	-- En los demás (Infección, solitario): bots = jugadores × perPlayer, entre minBots y
	-- maxBots. En Infección, esos bots son los zombis.
	vsAI = { teamSize = 5, minBots = 3, perPlayer = 2, maxBots = 10 },

	-- Créditos de la tienda por eliminar a un bot (false = no dan créditos)
	creditsForKills = true,
}
