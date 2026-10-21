-- Punto de entrada del cliente: arranca los controles del arma y el HUD.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponController = require(script.Controllers.WeaponController)
local HUD = require(script.UI.HUD)

WeaponController.Start()
HUD.Start()

local matchState = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MatchState") :: RemoteEvent

matchState.OnClientEvent:Connect(function(state, data)
	print("[Partida]", state, data)
end)
