-- Datos de cada arma. Para balancear el juego se cambian estos números, no la lógica.
-- El nombre de cada entrada debe ser igual al nombre de la herramienta (Tool) en StarterPack.
-- damage: daño por disparo · fireRate: disparos por segundo · magazine: balas por cargador
-- reloadTime: segundos que tarda en recargar · range: alcance en studs
local Weapons = {
	AssaultRifle = { damage = 8, fireRate = 9, magazine = 32, reloadTime = 2, range = 300, automatic = true },
	Pistol = {
		damage = 22,
		fireRate = 3,
		magazine = 12,
		reloadTime = 1.5,
		range = 400,
		automatic = false,
		headshotMultiplier = 2,
	},
	RocketLauncher = {
		damage = 250,
		fireRate = 0.8,
		magazine = 2,
		reloadTime = 3,
		range = 500,
		automatic = false,
		blastRadius = 12,
	},
}

return Weapons
