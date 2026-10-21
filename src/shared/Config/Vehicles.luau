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
		-- La ametralladora de la torreta no gasta munición
		turret = { damage = 12, fireRate = 10, range = 400 },
	},
}

return Vehicles
