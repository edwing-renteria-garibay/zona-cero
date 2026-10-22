-- Datos de cada arma. Para balancear el juego se cambian estos números, no la lógica.
-- El nombre de cada entrada debe ser igual al nombre de la herramienta (Tool) en StarterPack.
-- damage: daño por disparo en el cuerpo · headshotMultiplier: multiplica el daño en la cabeza
-- fireRate: disparos por segundo · magazine: balas por cargador
-- reloadTime: segundos que tarda en recargar · range: alcance en studs
-- reserve: balas de repuesto (si no se indica, son infinitas)
-- pickupRespawn: segundos que tarda en reaparecer en el mapa (armas que se recogen)
-- Un jugador aguanta 200 en total (100 de escudo + 100 de vida).
local Weapons = {
	-- Rifle: rápido pero flojo en el cuerpo (29 balas); en la cabeza, 15
	AssaultRifle = {
		damage = 7,
		headshotMultiplier = 2,
		fireRate = 9,
		magazine = 32,
		reloadTime = 2,
		range = 300,
		automatic = true,
	},
	-- Pistola tipo Desert Eagle: lenta y precisa; 7 tiros en el cuerpo, 3 en la cabeza
	Pistol = {
		damage = 30,
		headshotMultiplier = 2.5,
		fireRate = 2.5,
		magazine = 8,
		reloadTime = 1.6,
		range = 400,
		automatic = false,
	},
	-- Lanzacohetes: se recoge en el puente del mapa. El cohete vuela (no es instantáneo)
	-- y explota al tocar algo. Trae 2 cohetes cargados y 4 de repuesto.
	-- projectile: en vez de un raycast, el servidor lanza un cohete que avanza speed studs/s.
	-- blast: la explosión; un impacto directo mata (300 > 200) y dos cohetes destruyen un jeep.
	RocketLauncher = {
		projectile = true,
		speed = 140,
		fireRate = 0.8,
		magazine = 2,
		reserve = 4,
		reloadTime = 3,
		range = 500,
		pickupRespawn = 120,
		automatic = false,
		blast = {
			damage = 300,
			innerRadius = 4,
			radius = 14,
			vehicleDamage = 350,
			sound = "rocket",
		},
	},
}

return Weapons
