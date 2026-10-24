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

	-- Dificultad
	reactionTime = 0.6, -- segundos que tarda en empezar a disparar cuando te ve
	spread = 3.5, -- grados que se desvía cada bala al azar (más = falla más)
	damageMultiplier = 0.7, -- sus balas hacen el 70 % del daño normal
	sightRange = 160, -- studs: más lejos de eso no te ve
	preferredDistance = 35, -- studs: con un arma de fuego intenta quedarse a esta distancia

	-- Contra la IA (botón del menú): todos los jugadores en un equipo y los bots en el otro.
	-- Bots = jugadores × perPlayer, pero nunca menos de minBots ni más de maxBots.
	-- En Infección, esos bots son los zombis.
	vsAI = { minBots = 3, perPlayer = 2, maxBots = 10 },

	-- Créditos de la tienda por eliminar a un bot (false = no dan créditos)
	creditsForKills = true,
}
