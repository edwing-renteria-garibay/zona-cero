-- Punto de entrada del cliente: arranca los controles del arma, del jeep, el HUD y la mira.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleController = require(script.Controllers.VehicleController)
local WeaponController = require(script.Controllers.WeaponController)
local Crosshair = require(script.UI.Crosshair)
local HUD = require(script.UI.HUD)

WeaponController.Start()
VehicleController.Start()
HUD.Start()
Crosshair.Start()

local matchState = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MatchState") :: RemoteEvent

matchState.OnClientEvent:Connect(function(state, data)
	print("[Partida]", state, data)
end)
