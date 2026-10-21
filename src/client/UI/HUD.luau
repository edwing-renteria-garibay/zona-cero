-- HUD sencillo: escudo, vida y vida del jeep abajo a la izquierda; munición abajo a la derecha.
-- Se crea desde código para no depender de archivos de Studio.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VehicleController = require(script.Parent.Parent.Controllers.VehicleController)
local WeaponController = require(script.Parent.Parent.Controllers.WeaponController)

local player = Players.LocalPlayer

local HUD = {}

local function makeLabel(parent: Instance, anchor: Vector2, position: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.AnchorPoint = anchor
	label.Position = position
	label.Size = UDim2.fromOffset(240, 40)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 24
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextXAlignment = if anchor.X > 0.5 then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

function HUD.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local healthLabel = makeLabel(gui, Vector2.new(0, 1), UDim2.new(0, 24, 1, -24))
	local ammoLabel = makeLabel(gui, Vector2.new(1, 1), UDim2.new(1, -24, 1, -24))
	local vehicleLabel = makeLabel(gui, Vector2.new(0, 1), UDim2.new(0, 24, 1, -64))

	-- Se actualiza en cada fotograma; es barato porque solo cambia texto
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local shield = math.floor(character:GetAttribute("Shield") or 0)
			healthLabel.Text = string.format("Escudo %d  ·  Vida %d", shield, math.ceil(humanoid.Health))
		else
			healthLabel.Text = ""
		end

		local vehicle = VehicleController.GetVehicle()
		if vehicle then
			vehicleLabel.Text = string.format("Jeep %d", math.ceil(vehicle:GetAttribute("Health") or 0))
		else
			vehicleLabel.Text = ""
		end

		local tool, stats = WeaponController.GetEquipped()
		if not tool then
			ammoLabel.Text = ""
		elseif tool:GetAttribute("Reloading") then
			ammoLabel.Text = "Recargando..."
		else
			ammoLabel.Text = string.format("%d / %d", WeaponController.GetAmmo(tool, stats), stats.magazine)
		end
	end)
end

return HUD
