-- Sonidos del juego. Cada valor es el SoundId de un audio de Roblox.
-- Para elegir uno: en Studio abre la Caja de herramientas (Toolbox), ve a "Audio",
-- busca por ejemplo "gunshot" o "pistol", haz clic derecho en el sonido y elige
-- "Copiar ID del recurso". Pégalo aquí así: "rbxassetid://123456789".
-- Un texto vacío ("") significa "sin sonido".

return {
	-- Disparos: los oyen todos, desde donde está el arma
	fire = {
		AssaultRifle = "rbxassetid://128799811976358",
		Pistol = "rbxassetid://127604219525464",
		Turret = "rbxassetid://138382899505069",
		RocketLauncher = "rbxassetid://123619882242196",
		Shotgun = "rbxassetid://113543931016554",
		Flamethrower = "rbxassetid://129504465599355",
		LaserRifle = "rbxassetid://8561500387",
		Sniper = "rbxassetid://135333708100426",
		IceGun = "rbxassetid://103024837718208",
		IonCannon = "", -- el cañón no suena al disparar: suena la explosión del rayo
	},
	-- Recarga: la oye quien recarga (las armas que no están aquí recargan en silencio)
	reload = {
		Shotgun = "rbxassetid://138395973630666",
		Flamethrower = "rbxassetid://89922982008906",
		LaserRifle = "rbxassetid://128458446710828",
		Sniper = "rbxassetid://4649193317",
		IceGun = "rbxassetid://121572665498614",
	},
	-- Sin balas, para las armas con su propio clic (las demás usan empty, abajo)
	emptyBy = {
		Shotgun = "rbxassetid://136205387185309",
		Flamethrower = "rbxassetid://5278373892",
		LaserRifle = "rbxassetid://99056541220406",
		Sniper = "rbxassetid://122836641692660",
		IceGun = "rbxassetid://131592294669979",
	},
	-- Lo oye solo quien recibe un disparo del arma de hielo
	frozen = "rbxassetid://95721535003283",
	-- Armas cuyo audio es una ráfaga larga y no un solo disparo: el audio se repite
	-- mientras disparas y se corta al soltar el gatillo, en vez de sonar entero cada bala
	burst = {
		Turret = true,
		Flamethrower = true,
	},
	-- Impacto de la bala en el escenario o en un jeep: lo oyen todos, desde el impacto
	impact = {
		concrete = "rbxassetid://131554175554758", -- también suelo, piedra y todo lo demás
		metal = "rbxassetid://98609496290942",
		wood = "rbxassetid://131036980739699",
	},
	-- Aviso de acierto: solo lo oye quien dispara
	hit = "rbxasset://sounds/electronicpingshort.wav",
	headshot = "rbxassetid://93187250058836",
	-- Explosiones: cada una con su sonido (el jeep usa el del cohete)
	explosion = {
		rocket = "rbxassetid://134201956270955",
		grenade = "rbxassetid://87630300241395",
		jeep = "rbxassetid://134201956270955",
		ion = "rbxassetid://134201956270955", -- el rayo del cañón de iones
		simi = "rbxassetid://87630300241395", -- el Doctor SimiO (por ahora, el de la granada)
	},
	grenadeThrow = "rbxassetid://118254779238351",
	-- Jeep: los oyen todos, desde el jeep
	vehicle = {
		engine = "rbxassetid://532147820", -- motor al avanzar: se repite y suena más fuerte y agudo con la velocidad
		start = "rbxassetid://140685060", -- al encenderlo (cuando se sube el conductor)
		runOver = "rbxassetid://127729552755617", -- al atropellar a un enemigo
	},
	-- Armas de golpe (Config/Melee): suena en cada golpe, le pegue a alguien o no; lo oyen todos
	melee = {
		RubberChicken = "rbxassetid://7507574099",
	},
	-- Al terminar la partida, en la pantalla de resultados: cada quien oye si ganó o perdió
	matchEnd = {
		win = "rbxassetid://1836265515",
		lose = "rbxassetid://135261658507155",
	},
	-- Medallas por bajas seguidas: solo las oye quien las hace. Cuentan las bajas con menos de
	-- MatchService.MULTIKILL_WINDOW segundos (4) entre una y otra, como en Halo
	multikill = {
		[2] = "rbxassetid://131995992572692", -- muerte doble
		[3] = "rbxassetid://6410923021", -- muerte triple
		[4] = "rbxassetid://125621554040822", -- 4 o más (suena en cada baja de la racha)
	},
	-- Clic al intentar disparar sin balas (todas las armas y la torreta)
	empty = "rbxassetid://136205387185309",
}
