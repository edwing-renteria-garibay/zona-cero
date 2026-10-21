-- Datos de cada arma. Para balancear el juego se cambian estos números, no la lógica.
-- El nombre de cada entrada debe ser igual al nombre de la herramienta (Tool) en StarterPack.
-- damage: daño por disparo en el cuerpo · headshotMultiplier: multiplica el daño en la cabeza
-- fireRate: disparos por segundo · magazine: balas por cargador
-- reloadTime: segundos que tarda en recargar · range: alcance en studs
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
