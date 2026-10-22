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
	},
	-- Armas cuyo audio es una ráfaga larga y no un solo disparo: el audio se repite
	-- mientras disparas y se corta al soltar el gatillo, en vez de sonar entero cada bala
	burst = {
		Turret = true,
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
	-- Clic al intentar disparar sin balas (todas las armas y la torreta)
	empty = "rbxassetid://136205387185309",
}
