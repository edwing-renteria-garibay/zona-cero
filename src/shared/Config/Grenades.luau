-- Granada de fragmentación: se lanza con G y explota al chocar con algo
-- (el suelo, una pared, un jugador o un jeep). Si no toca nada, explota sola tras fuse segundos.
-- Cada vida empiezas con count granadas.
return {
	count = 2, -- granadas al aparecer
	throwSpeed = 65, -- studs por segundo al soltarla
	fuse = 1.5, -- segundos hasta que explota si no ha chocado con nada
	cooldown = 1, -- segundos entre lanzamientos
	blast = {
		damage = 180, -- casi mata; una granada más unos tiros, sí
		innerRadius = 3,
		radius = 12,
		vehicleDamage = 150,
		sound = "grenade",
	},
}
