-- Datos de cada vehículo. Para balancear se cambian estos números, no la lógica.
-- health: vida · respawnTime: segundos hasta que reaparece tras ser destruido
-- maxSpeed / reverseSpeed: studs por segundo · turnRate: radianes por segundo al girar
local Vehicles = {
	TurretJeep = {
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
		-- La ametralladora de la torreta no gasta munición
		turret = { damage = 12, fireRate = 10, range = 400 },
	},
}

return Vehicles
