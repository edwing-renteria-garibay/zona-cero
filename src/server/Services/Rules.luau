-- Las reglas del modo que se está jugando. MatchService las cambia al empezar cada partida
-- y los demás servicios las leen: con qué armas se aparece, si hay escudos, granadas,
-- objetos en el mapa o jeeps. Ver Config/Modes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modes = require(ReplicatedStorage.Shared.Config.Modes)

local Rules = {
	current = Modes.TeamSlayer :: any, -- cualquier modo de Config/Modes
}

return Rules
