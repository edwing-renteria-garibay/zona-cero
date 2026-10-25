-- Música de fondo de cada modo. Suena bajita mientras se juega, para que se sigan
-- oyendo los disparos, y se apaga poco a poco al terminar la partida.
-- Cada valor es el SoundId de un audio de Roblox (ver Config/Sounds para copiar uno).
-- Un texto vacío ("") significa "sin música" en ese modo.

return {
	volume = 0.3, -- 0 = muda, 1 = al máximo; los disparos suenan a 0.6
	fadeTime = 2, -- segundos para subir o bajar la música al cambiar
	byMode = {
		SWATExplosive = "rbxassetid://128469069192692",
		SWAT = "rbxassetid://1845149698",
		CaptureTheFlag = "rbxassetid://1845092181",
		MeleeWeapons = "rbxassetid://111737108754664", -- Pollos y machetes
		SimiRain = "rbxassetid://139818146051220", -- Lluvia de SimiOs
		Infection = "rbxassetid://9048538224",
		-- Todavía sin canción
		TeamSlayer = "",
		FreeForAll = "",
		Brawl = "",
		Assault = "",
		KingOfTheHill = "",
	},
}
