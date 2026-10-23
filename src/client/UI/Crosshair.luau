-- Mira que sigue al mouse. Con el rifle es una cruz; en la torreta, un círculo.
-- Se pone roja un instante cuando el servidor confirma que acertaste,
-- y naranja (y más grande) si fue un tiro a la cabeza o un golpe por la espalda.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local VehicleController = require(script.Parent.Parent.Controllers.VehicleController)
local WeaponController = require(script.Parent.Parent.Controllers.WeaponController)

local hitConfirmed = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("HitConfirmed") :: RemoteEvent

local player = Players.LocalPlayer

local NORMAL_COLOR = Color3.new(1, 1, 1)
local HIT_COLOR = Color3.fromRGB(255, 60, 60)
local HEAD_COLOR = Color3.fromRGB(255, 170, 0)
local HIT_TIME = 0.25 -- segundos que dura el rojo al acertar

local Crosshair = {}

-- Un rectángulo pequeño, centrado en (x, y) respecto al centro de la mira
local function makeBar(parent: Instance, x: number, y: number, width: number, height: number): Frame
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromOffset(x, y)
	bar.Size = UDim2.fromOffset(width, height)
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = NORMAL_COLOR
	bar.Parent = parent
	return bar
end

function Crosshair.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Crosshair"
	gui.IgnoreGuiInset = true -- así las coordenadas coinciden con las del mouse
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Mira del rifle: cuatro rayitas con un hueco en el centro y un punto
	local rifle = Instance.new("Frame")
	rifle.BackgroundTransparency = 1
	rifle.Size = UDim2.fromOffset(0, 0)
	rifle.Parent = gui
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = rifle
	local rifleParts = {
		makeBar(rifle, 0, -10, 2, 8),
		makeBar(rifle, 0, 10, 2, 8),
		makeBar(rifle, -10, 0, 8, 2),
		makeBar(rifle, 10, 0, 8, 2),
		makeBar(rifle, 0, 0, 2, 2),
	}

	-- Mira de la torreta: un círculo con un punto
	local turret = Instance.new("Frame")
	turret.BackgroundTransparency = 1
	turret.Size = UDim2.fromOffset(0, 0)
	turret.Parent = gui
	local ring = makeBar(turret, 0, 0, 32, 32)
	ring.BackgroundTransparency = 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = NORMAL_COLOR
	stroke.Parent = ring
	local turretDot = makeBar(turret, 0, 0, 3, 3)
	local turretScale = Instance.new("UIScale")
	turretScale.Parent = turret

	local lastHit = -math.huge
	local lastHitColor = HIT_COLOR
	hitConfirmed.OnClientEvent:Connect(function(kind: string)
		lastHit = os.clock()
		lastHitColor = if kind == "head" then HEAD_COLOR else HIT_COLOR
	end)

	RunService.RenderStepped:Connect(function()
		local inTurret = VehicleController.IsInTurret()
		local hasWeapon = WeaponController.GetEquipped() ~= nil
		rifle.Visible = hasWeapon and not inTurret
		turret.Visible = inTurret
		-- Con mira visible se oculta la flecha del mouse (menos con un menú abierto)
		UserInputService.MouseIconEnabled = player:GetAttribute("MenuOpen") == true
			or not (rifle.Visible or turret.Visible)

		local mouse = UserInputService:GetMouseLocation()
		rifle.Position = UDim2.fromOffset(mouse.X, mouse.Y)
		turret.Position = UDim2.fromOffset(mouse.X, mouse.Y)

		local hitActive = os.clock() - lastHit < HIT_TIME
		local color = if hitActive then lastHitColor else NORMAL_COLOR
		-- En tiros a la cabeza la mira crece un poco para que se note más
		local scale = if hitActive and lastHitColor == HEAD_COLOR then 1.5 else 1
		uiScale.Scale = scale
		turretScale.Scale = scale
		for _, part in rifleParts do
			part.BackgroundColor3 = color
		end
		stroke.Color = color
		turretDot.BackgroundColor3 = color
	end)
end

return Crosshair
