-- Granada de fragmentación: se lanza con G, rebota y explota a los pocos segundos.
-- Cada vida empiezas con count granadas.
return {
	count = 2, -- granadas al aparecer
	throwSpeed = 65, -- studs por segundo al soltarla
	fuse = 2.5, -- segundos desde que la lanzas hasta que explota
	cooldown = 1, -- segundos entre lanzamientos
	blast = {
		damage = 180, -- casi mata; una granada más unos tiros, sí
		innerRadius = 3,
		radius = 12,
		vehicleDamage = 150,
	},
}
