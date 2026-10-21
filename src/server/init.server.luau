-- Punto de entrada del servidor: prepara a cada jugador y arranca la partida.

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

local Services = script.Services
local HealthService = require(Services.HealthService)
local MatchService = require(Services.MatchService)

Players.RespawnTime = 5

-- Crear los dos equipos
for name, color in { Rojo = BrickColor.new("Bright red"), Azul = BrickColor.new("Bright blue") } do
	local team = Instance.new("Team")
	team.Name = name
	team.TeamColor = color
	team.AutoAssignable = true
	team.Parent = Teams
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		HealthService.SetupCharacter(player, character)
		-- Protección breve al reaparecer
		character:SetAttribute("SpawnProtected", true)
		task.delay(2, function()
			character:SetAttribute("SpawnProtected", nil)
		end)
	end)
end)

task.spawn(MatchService.Run, "TeamSlayer")
