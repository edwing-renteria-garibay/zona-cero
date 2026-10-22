-- Punto de entrada del servidor: prepara a cada jugador y arranca la partida.

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

local Services = script.Services
local CombatService = require(Services.CombatService)
local HealthService = require(Services.HealthService)
local MatchService = require(Services.MatchService)
local ProjectileService = require(Services.ProjectileService)
local VehicleService = require(Services.VehicleService)

Players.RespawnTime = 5

-- Crear los dos equipos
for name, color in { Rojo = BrickColor.new("Bright red"), Azul = BrickColor.new("Bright blue") } do
	local team = Instance.new("Team")
	team.Name = name
	team.TeamColor = color
	team.AutoAssignable = true
	team.Parent = Teams
end

CombatService.Start()
VehicleService.Start()
ProjectileService.Start()

Players.PlayerAdded:Connect(function(player)
	-- "leaderstats" es una carpeta especial: Roblox muestra sus valores en la lista de jugadores
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local kills = Instance.new("IntValue")
	kills.Name = "Bajas"
	kills.Parent = leaderstats
	leaderstats.Parent = player

	player.CharacterAdded:Connect(function(character)
		HealthService.SetupCharacter(player, character)
		ProjectileService.SetupCharacter(character)
		-- Protección breve al reaparecer
		character:SetAttribute("SpawnProtected", true)
		task.delay(2, function()
			character:SetAttribute("SpawnProtected", nil)
		end)
	end)
end)

task.spawn(MatchService.Run, "TeamSlayer")
