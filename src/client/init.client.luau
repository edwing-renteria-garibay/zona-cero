-- Punto de entrada del cliente: arranca la cámara, los controles de armas, golpe, granada y jeep, el HUD, la mira
-- los avisos de daño (números, barras sobre la cabeza), el marcador, el registro de bajas
-- y la pantalla de resultados.

local CameraController = require(script.Controllers.CameraController)
local GrenadeController = require(script.Controllers.GrenadeController)
local MeleeController = require(script.Controllers.MeleeController)
local VehicleController = require(script.Controllers.VehicleController)
local WeaponController = require(script.Controllers.WeaponController)
local Crosshair = require(script.UI.Crosshair)
local HUD = require(script.UI.HUD)
local HitFeedback = require(script.UI.HitFeedback)
local KillFeed = require(script.UI.KillFeed)
local OverheadBars = require(script.UI.OverheadBars)
local Results = require(script.UI.Results)
local Scoreboard = require(script.UI.Scoreboard)

CameraController.Start()
WeaponController.Start()
VehicleController.Start()
MeleeController.Start()
GrenadeController.Start()
HUD.Start()
Crosshair.Start()
HitFeedback.Start()
OverheadBars.Start()
Scoreboard.Start()
KillFeed.Start()
Results.Start()
