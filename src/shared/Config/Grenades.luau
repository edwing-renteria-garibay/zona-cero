-- Granada de fragmentación: se lanza con G y explota al chocar con algo
-- (el suelo, una pared, un jugador o un jeep). Si no toca nada, explota sola tras fuse segundos.
-- Cada vida empiezas con count granadas.
-- Para apuntar: mantén G y verás el arco y dónde caerá; suelta G para lanzarla.
return {
	count = 2, -- granadas al aparecer
	max = 4, -- máximo que se puede cargar
	pickupAmount = 2, -- granadas que da la plataforma de granadas del mapa
	pickupRespawn = 30, -- segundos que tarda en volver esa plataforma
	maxRange = 70, -- studs: no se puede lanzar más lejos (si apuntas más lejos, cae a esta distancia)
	maxThrowSpeed = 170, -- studs/s: el servidor recorta lanzamientos más fuertes (antitrampas)
	throwHeight = 1.5, -- studs sobre la cabeza desde donde sale la granada
	fuse = 1.5, -- segundos hasta que explota si no ha chocado con nada
	cooldown = 1, -- segundos entre lanzamientos
	blast = {
		damage = 180, -- casi mata; una granada más unos tiros, sí
		innerRadius = 3,
		radius = 12,
		vehicleDamage = 150,
		sound = "grenade",
	},
	-- El Doctor SimiO: en el modo "Lluvia de SimiOs" se lanza en vez de la granada (con G, igual).
	-- Vuela dando vueltas y explota al chocar, como la granada.
	simi = {
		spin = 12, -- qué tan rápido da vueltas en el aire
		blast = {
			damage = 180,
			innerRadius = 3,
			radius = 12,
			vehicleDamage = 150,
			sound = "simi", -- sonido de Sounds.explosion y causa en el registro de bajas
		},
	},
}
