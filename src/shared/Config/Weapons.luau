-- Datos de cada arma. Para balancear el juego se cambian estos números, no la lógica.
-- damage: daño por disparo · fireRate: disparos por segundo · range: alcance en studs
local Weapons = {
	AssaultRifle = { damage = 8, fireRate = 9, magazine = 32, range = 300, automatic = true },
	Pistol = { damage = 22, fireRate = 3, magazine = 12, range = 400, automatic = false, headshotMultiplier = 2 },
	RocketLauncher = { damage = 250, fireRate = 0.8, magazine = 2, range = 500, automatic = false, blastRadius = 12 },
}

return Weapons
