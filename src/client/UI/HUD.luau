-- HUD sencillo: escudo, vida y vida del jeep abajo a la izquierda; munición abajo a la derecha.
-- En celular va todo en el centro, más pequeño y encima de la barra de armas: abajo a la
-- izquierda está el stick y abajo a la derecha los botones.
-- Se crea desde código para no depender de archivos de Studio.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GrenadeController = require(script.Parent.Parent.Controllers.GrenadeController)
local Mobile = require(script.Parent.Parent.Controllers.Mobile)
local VehicleController = require(script.Parent.Parent.Controllers.VehicleController)
local WeaponController = require(script.Parent.Parent.Controllers.WeaponController)

local player = Players.LocalPlayer

local HUD = {}

local function makeLabel(parent: Instance, anchor: Vector2, position: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.AnchorPoint = anchor
	label.Position = position
	label.Size = UDim2.fromOffset(360, 40)
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
	if Mobile.IsTouch() then
		-- Una encima de otra, centradas, arriba de la barra de armas de Roblox
		for i, label in { healthLabel, ammoLabel, vehicleLabel } do
			label.AnchorPoint = Vector2.new(0.5, 1)
			label.Position = UDim2.new(0.5, 0, 1, -62 - (i - 1) * 20)
			label.Size = UDim2.fromOffset(360, 20)
			label.TextSize = if label == ammoLabel then 17 else 15
			label.TextXAlignment = Enum.TextXAlignment.Center
		end
	end

	-- Se actualiza en cada fotograma; es barato porque solo cambia texto
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local shield = math.floor(character:GetAttribute("Shield") or 0)
			local grenadeName = character:GetAttribute("GrenadeName") or "Granadas"
			local grenades = if character:GetAttribute("InfiniteGrenades")
				then "∞"
				else tostring(GrenadeController.GetCount())
			healthLabel.Text = string.format(
				"Escudo %d  ·  Vida %d  ·  %s %s",
				shield,
				math.ceil(humanoid.Health),
				grenadeName,
				grenades
			)
		else
			healthLabel.Text = ""
		end

		local vehicle = VehicleController.GetVehicle()
		if vehicle then
			local flats = vehicle:GetAttribute("FlatTires") or 0
			vehicleLabel.Text = string.format(
				"Jeep %d  ·  Llantas %d/4",
				math.ceil(vehicle:GetAttribute("Health") or 0),
				4 - flats
			)
		else
			vehicleLabel.Text = ""
		end

		local tool, stats = WeaponController.GetEquipped()
		if vehicle and VehicleController.IsInTurret() then
			local turret, rockets = VehicleController.GetTurretWeapon(vehicle)
			local name = if rockets then "Cohetes" else "Torreta"
			ammoLabel.Text = if vehicle:GetAttribute("TurretReloading")
				then `Recargando {string.lower(name)}...`
				else string.format(
					"%s %d / %d",
					name,
					VehicleController.GetTurretAmmo(vehicle),
					turret.magazine
				)
		elseif not tool then
			ammoLabel.Text = ""
		elseif tool:GetAttribute("Reloading") then
			ammoLabel.Text = "Recargando..."
		else
			local reserve = tool:GetAttribute("Reserve")
			ammoLabel.Text = if reserve
				then string.format("%d  ·  repuesto %d", WeaponController.GetAmmo(tool, stats), reserve)
				else string.format("%d / %d", WeaponController.GetAmmo(tool, stats), stats.magazine)
		end
	end)
end

return HUD
