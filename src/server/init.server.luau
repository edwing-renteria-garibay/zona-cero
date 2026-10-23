-- Punto de entrada del servidor: prepara a cada jugador y arranca la partida.

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

local Services = script.Services
local AssaultService = require(Services.AssaultService)
local CombatService = require(Services.CombatService)
local FlagService = require(Services.FlagService)
local HealthService = require(Services.HealthService)
local HillService = require(Services.HillService)
local InfectionService = require(Services.InfectionService)
local LoadoutService = require(Services.LoadoutService)
local MapService = require(Services.MapService)
local MatchService = require(Services.MatchService)
local PickupService = require(Services.PickupService)
local ProjectileService = require(Services.ProjectileService)
local ShopService = require(Services.ShopService)
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
LoadoutService.Start() -- antes que las plataformas: les da forma a las armas
PickupService.Start(map)
FlagService.Setup(map)
AssaultService.Setup(map)
HillService.Setup(map)
InfectionService.Start()
CombatService.Start()
VehicleService.Start()
ProjectileService.Start()
ShopService.Start() -- créditos, compras y lo que cada quien lleva puesto

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
		InfectionService.SetupCharacter(player, character) -- zombis: sin armas y más rápidos
		task.spawn(LoadoutService.SetupCharacter, player) -- armas según el modo
		task.spawn(TeamMarkers.SetupCharacter, player, character) -- brazaletes del equipo
		task.spawn(MatchService.SetupCharacter, player, character) -- en solitario: punto al azar
		-- Protección breve al reaparecer
		character:SetAttribute("SpawnProtected", true)
		task.delay(2, function()
			character:SetAttribute("SpawnProtected", nil)
		end)
	end)
end)

-- Entre partidas cambia el mapa (Config/Maps); lo que depende de él se vuelve a preparar
local function changeMap()
	local newMap = MapService.Next()
	if not newMap then
		return
	end
	PickupService.Start(newMap)
	FlagService.Setup(newMap)
	AssaultService.Setup(newMap)
	HillService.Setup(newMap)
	VehicleService.Reset()
end

task.spawn(MatchService.Run, changeMap) -- el modo se elige en Config/Modes
