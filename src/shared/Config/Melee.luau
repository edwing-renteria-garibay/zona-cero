-- Golpe cuerpo a cuerpo (tecla F, R3 en control, o el botón "Golpe" en móvil): todos llevan
-- un machete al cinto y lo sacan para dar un machetazo. Con las manos vacías o con un arma
-- de golpe en la mano (machete, pollo de hule), el clic también golpea.
-- damage: daño de un golpe normal · backstabDamage: golpe por la espalda (mata de un golpe)
-- range: alcance en studs desde el pecho · cooldown: segundos entre golpes
-- aimCone: qué tan de lado puede estar el enemigo y aun así le pegas (1 = solo justo
-- enfrente, 0 = hasta 90° a cada lado). Más bajo = más fácil atinarle.
local Melee = {
	damage = 70,
	backstabDamage = 200,
	range = 8,
	cooldown = 0.8,
	aimCone = 0.4,
}

-- Armas de golpe: herramientas que no disparan (su forma está en Shared/WeaponModels).
-- Cada una cambia los valores de arriba mientras la llevas en la mano.
-- knockback: qué tan fuerte sale volando quien recibe el golpe (0 = nada)
-- sound: sonido de Config/Sounds.melee que se oye al pegar
Melee.weapons = {
	Machete = {
		name = "Machete",
		damage = 60, -- 2 golpes sin escudo
		backstabDamage = 200,
		range = 7,
		cooldown = 0.7,
		knockback = 0,
	},
	RubberChicken = {
		name = "Pollo de hule",
		damage = 35, -- pega poco, pero rápido y te avienta lejos
		backstabDamage = 200,
		range = 7,
		cooldown = 0.4,
		knockback = 70,
		sound = "RubberChicken",
	},
}

return Melee
