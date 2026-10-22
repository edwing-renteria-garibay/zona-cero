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
		-- Explosión al ser destruido: blastDamage completo hasta blastInnerRadius (studs)
		-- desde el centro del jeep, y luego baja hasta 0 en blastRadius.
		-- Un jugador tiene 200 en total (100 de escudo + 100 de vida). También daña a otros jeeps.
		blastDamage = 250,
		blastInnerRadius = 6,
		blastRadius = 16,
		-- La ametralladora de la torreta no gasta munición
		turret = {
			damage = 10,
			headshotMultiplier = 2,
			fireRate = 10,
			range = 400,
			magazine = 100, -- balas antes de recargar
			reloadTime = 5, -- segundos; se recarga sola al vaciarse, o con R
		},
	},
}

return Vehicles
