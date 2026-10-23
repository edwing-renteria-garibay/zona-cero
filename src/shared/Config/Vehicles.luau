-- Datos de cada vehículo. Para balancear se cambian estos números, no la lógica.
-- health: vida · respawnTime: segundos hasta que reaparece tras ser destruido
-- maxSpeed / reverseSpeed: studs por segundo · turnRate: radianes por segundo al girar
--
-- Hay dos jeeps: TurretJeep (ametralladora) y RocketJeep (lanzacohetes). Manejan igual y
-- aguantan lo mismo (comparten la tabla base); solo cambia el arma de atrás.
local base = {
	health = 600,
	respawnTime = 45,
	maxSpeed = 60,
	reverseSpeed = 25,
	turnRate = 2.4,
	-- Llantas: cada una aguanta tireHealth de daño antes de poncharse.
	-- Cada llanta ponchada quita flatSpeedPenalty de la velocidad máxima (0.2 = 20 %)
	-- y cada delantera ponchada quita flatTurnPenalty del giro.
	-- Un disparo a una llanta daña al jeep con tireHitShare de su daño (0.5 = la mitad).
	tireHealth = 60,
	flatSpeedPenalty = 0.2,
	flatTurnPenalty = 0.3,
	tireHitShare = 0.5,
	-- Explosión al ser destruido: blastDamage completo hasta blastInnerRadius (studs)
	-- desde el centro del jeep, y luego baja hasta 0 en blastRadius.
	-- Un jugador tiene 200 en total (100 de escudo + 100 de vida). También daña a otros jeeps.
	blastDamage = 250,
	blastInnerRadius = 6,
	blastRadius = 16,
	-- Atropellar: a partir de minSpeed (studs por segundo), un enemigo que toca el jeep
	-- pierde damage (primero el escudo, luego la vida) y sale volando con fuerza
	-- knockback. Nunca lo mata: siempre le deja al menos 1 de vida. A la misma persona
	-- solo se le puede volver a atropellar después de cooldown segundos.
	runOver = {
		minSpeed = 15,
		damage = 80,
		knockback = 45,
		cooldown = 1,
	},
}

-- Copia la tabla base y le agrega el arma del jeep
local function jeep(weapon: { [string]: any }): { [string]: any }
	local stats = table.clone(base)
	for key, value in weapon do
		stats[key] = value
	end
	return stats
end

local Vehicles = {
	TurretJeep = jeep({
		-- La ametralladora de la torreta no gasta munición
		turret = {
			damage = 10,
			headshotMultiplier = 2,
			fireRate = 10,
			range = 400,
			magazine = 100, -- balas antes de recargar
			reloadTime = 5, -- segundos; se recarga sola al vaciarse, o con R
		},
	}),
	-- Lanzacohetes: dispara cohetes como el lanzacohetes de mano, pero más seguido y con
	-- 6 en el cargador. Cada cohete hace un poco menos daño que el de mano.
	RocketJeep = jeep({
		rockets = {
			fireRate = 1.5, -- cohetes por segundo
			speed = 130,
			range = 500,
			magazine = 6,
			reloadTime = 6,
			blast = {
				damage = 220,
				innerRadius = 3,
				radius = 12,
				vehicleDamage = 300, -- 2 cohetes destruyen un jeep (600 de vida)
				sound = "rocket",
			},
		},
	}),
}

return Vehicles
