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
	-- Aviso de acierto: solo lo oye quien dispara
	hit = "rbxasset://sounds/electronicpingshort.wav",
	headshot = "rbxasset://sounds/electronicpingshort.wav",
}
