-- Punto de entrada del servidor: prepara a cada jugador y arranca la partida.

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

local Services = script.Services
local CombatService = require(Services.CombatService)
local HealthService = require(Services.HealthService)
local MapService = require(Services.MapService)
local MatchService = require(Services.MatchService)
local PickupService = require(Services.PickupService)
local ProjectileService = require(Services.ProjectileService)
local TeamMarkers = require(Services.TeamMarkers)
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

-- El mapa va primero: VehicleService busca ahí dónde aparecen los jeeps
local map = MapService.Build()
PickupService.Start(map)
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
	local deaths = Instance.new("IntValue")
	deaths.Name = "Muertes"
	deaths.Parent = leaderstats
	leaderstats.Parent = player

	player.CharacterAdded:Connect(function(character)
		HealthService.SetupCharacter(player, character)
		ProjectileService.SetupCharacter(character)
		task.spawn(TeamMarkers.SetupCharacter, player, character) -- brazaletes del equipo
		-- Protección breve al reaparecer
		character:SetAttribute("SpawnProtected", true)
		task.delay(2, function()
			character:SetAttribute("SpawnProtected", nil)
		end)
	end)
end)

task.spawn(MatchService.Run, "TeamSlayer")
