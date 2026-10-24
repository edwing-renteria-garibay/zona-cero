-- Datos de cada arma. Para balancear el juego se cambian estos números, no la lógica.
-- El nombre de cada entrada debe ser igual al nombre de la herramienta (Tool) en
-- ServerStorage.Weapons. Con qué armas se aparece lo dice cada modo (Config/Modes, loadout).
-- damage: daño por disparo en el cuerpo · headshotMultiplier: multiplica el daño en la cabeza
-- fireRate: disparos por segundo · magazine: balas por cargador
-- reloadTime: segundos que tarda en recargar · range: alcance en studs
-- reserve: balas de repuesto (si no se indica, son infinitas)
-- pickupRespawn: segundos que tarda en reaparecer en el mapa (armas que se recogen)
-- Un jugador aguanta 200 en total (100 de escudo + 100 de vida).
-- kind: cómo dispara, si no es una bala normal:
--   "pellets" = varios perdigones a la vez (pellets cuántos, spread qué tan abiertos, en grados)
--   "flame" = llamas de corto alcance en cono (cone en grados) que además queman (burn)
--   "ion" = marca un punto; tras delay segundos cae un rayo que explota (blast)
-- beam: cómo se ve el disparo ("laser" verde, "ice" azul); sin beam, una trazadora normal
-- zoom: campo de visión al apuntar con clic derecho (francotirador)
-- dropStart y drop: la bala va recta hasta dropStart studs y luego cae (drop = qué tan rápido);
-- si no toca nada antes de range, se pierde
-- recoil: grados que sube la mira al disparar (solo escopeta, lanzacohetes y francotirador)
-- slow: el disparo ralentiza al enemigo (factor de velocidad y segundos)
local Weapons = {
	-- Rifle: rápido pero flojo en el cuerpo (29 balas); en la cabeza, 15
	AssaultRifle = {
		damage = 7,
		headshotMultiplier = 2,
		fireRate = 9,
		magazine = 32,
		reloadTime = 2,
		range = 300,
		dropStart = 120,
		drop = 0.002,
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
		dropStart = 100,
		drop = 0.002,
		automatic = false,
	},
	-- Lanzacohetes: se recoge en lo alto del montículo central. El cohete vuela (no es instantáneo)
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
		recoil = 8,
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
	-- Escopeta: 8 perdigones; de cerca mata de un tiro (8 x 25 = 200), de lejos casi no hace nada
	Shotgun = {
		kind = "pellets",
		pellets = 8,
		spread = 6,
		damage = 25,
		fireRate = 1.1,
		magazine = 6,
		reserve = 18,
		reloadTime = 2.6,
		range = 55,
		dropStart = 30,
		drop = 0.006,
		recoil = 6,
		pickupRespawn = 60,
		automatic = false,
	},
	-- Lanzallamas: daña a todos los enemigos en un área corta y ancha y los deja quemándose
	Flamethrower = {
		kind = "flame",
		damage = 3,
		cone = 40,
		fireRate = 12,
		magazine = 120,
		reserve = 120,
		reloadTime = 3,
		range = 14,
		-- Se acumula: una capa más cada 0.3 s que la llama te alcanza (hasta 6); cada capa quema
		-- 4 por segundo. Dura 3 s después de la última llamarada.
		burn = { damagePerStack = 4, maxStacks = 6, stackEvery = 0.3, duration = 3 },
		pickupRespawn = 90,
		automatic = true,
	},
	-- Rayo de energía (estilo SE Ray): instantáneo y preciso; 2 tiros matan
	LaserRifle = {
		beam = "laser",
		damage = 75, -- antes 100
		headshotMultiplier = 1.5,
		fireRate = 1.2,
		magazine = 6,
		reserve = 12,
		reloadTime = 2.4,
		range = 600,
		dropStart = 250,
		drop = 0.001,
		pickupRespawn = 90,
		automatic = false,
	},
	-- Francotirador: clic derecho para apuntar con zoom; a la cabeza mata de un tiro
	Sniper = {
		damage = 120,
		headshotMultiplier = 2.5,
		fireRate = 0.8,
		magazine = 4,
		reserve = 12,
		reloadTime = 3,
		range = 1000,
		dropStart = 300,
		drop = 0.0008,
		recoil = 7,
		zoom = 18,
		pickupRespawn = 90,
		automatic = false,
	},
	-- Arma de hielo: poco daño, pero el enemigo queda lento un rato
	IceGun = {
		beam = "ice",
		damage = 15,
		headshotMultiplier = 1,
		fireRate = 3,
		magazine = 10,
		reserve = 30,
		reloadTime = 2,
		range = 160,
		dropStart = 80,
		drop = 0.003,
		slow = { factor = 0.45, duration = 2.5 },
		pickupRespawn = 60,
		automatic = false,
	},
	-- Cañón de iones: apuntas con el láser, disparas y 1.5 s después cae un rayo del cielo
	IonCannon = {
		kind = "ion",
		beam = "ion",
		fireRate = 0.4,
		magazine = 1,
		reserve = 2,
		reloadTime = 4,
		range = 500,
		delay = 1.5,
		pickupRespawn = 150,
		automatic = false,
		blast = {
			damage = 250,
			innerRadius = 5,
			radius = 14,
			vehicleDamage = 400,
			sound = "ion",
		},
	},
}

return Weapons
