-- Punto de entrada del cliente: arranca la cámara, los controles de armas, golpe, granada y jeep, el HUD, la mira
-- y los avisos de daño (números, barras sobre la cabeza).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraController = require(script.Controllers.CameraController)
local GrenadeController = require(script.Controllers.GrenadeController)
local MeleeController = require(script.Controllers.MeleeController)
local VehicleController = require(script.Controllers.VehicleController)
local WeaponController = require(script.Controllers.WeaponController)
local Crosshair = require(script.UI.Crosshair)
local HUD = require(script.UI.HUD)
local HitFeedback = require(script.UI.HitFeedback)
local OverheadBars = require(script.UI.OverheadBars)

CameraController.Start()
WeaponController.Start()
VehicleController.Start()
MeleeController.Start()
GrenadeController.Start()
HUD.Start()
Crosshair.Start()
HitFeedback.Start()
OverheadBars.Start()

local matchState = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MatchState") :: RemoteEvent

matchState.OnClientEvent:Connect(function(state, data)
	print("[Partida]", state, data)
end)
