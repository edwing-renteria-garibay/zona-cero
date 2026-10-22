-- Armas del mapa: plataformas que dan un arma al tocarlas y reaparecen después de un tiempo.
-- Cada plataforma es una pieza dentro de Map.WeaponPickups con el atributo "Weapon"
-- (el nombre del arma). La herramienta se copia de ServerStorage.Weapons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local DEFAULT_RESPAWN = 60 -- segundos, si el arma no indica pickupRespawn

local PickupService = {}

-- Un modelo que gira sobre la plataforma para que se vea qué arma hay ahí
local function makeDisplay(pad: BasePart, weaponName: string): BasePart
	local template = ServerStorage.Weapons[weaponName] :: Tool
	local display = (template:FindFirstChild("Handle") :: BasePart):Clone()
	display.Name = "Display"
	display.Anchored = true
	display.CanCollide = false
	display.CanTouch = false
	display.CanQuery = false
	display.Parent = pad

	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromOffset(140, 24)
	label.StudsOffset = Vector3.new(0, 2, 0)
	label.MaxDistance = 80
	label.Parent = display
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextSize = 16
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.4
	text.Text = template.ToolTip
	text.Parent = label
	return display
end

local function setupPad(pad: BasePart)
	local weaponName = pad:GetAttribute("Weapon") :: string?
	if not weaponName or not ServerStorage.Weapons:FindFirstChild(weaponName) then
		warn("[Pickup] Arma desconocida en", pad:GetFullName())
		return
	end
	local stats = Weapons[weaponName]
	local respawnTime = stats and stats.pickupRespawn or DEFAULT_RESPAWN
	local display = makeDisplay(pad, weaponName)
	local available = true

	-- Girar y flotar un poco
	local spin = 0
	RunService.Heartbeat:Connect(function(dt)
		spin += dt
		display.CFrame = pad.CFrame
			* CFrame.new(0, 2 + math.sin(spin * 2) * 0.3, 0)
			* CFrame.Angles(0, spin, 0)
		display.Transparency = if available then 0 else 1
	end)

	pad.Touched:Connect(function(hit: BasePart)
		if not available then
			return
		end
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local backpack = player and player:FindFirstChildOfClass("Backpack")
		if not player or not humanoid or humanoid.Health <= 0 or not backpack then
			return
		end
		-- Si ya la tiene (en la mano o en la mochila), no la gasta
		if character:FindFirstChild(weaponName) or backpack:FindFirstChild(weaponName) then
			return
		end
		available = false
		local tool = ServerStorage.Weapons[weaponName]:Clone()
		tool.Parent = backpack
		task.delay(respawnTime, function()
			available = true
		end)
	end)
end

function PickupService.Start(map: Instance)
	local pickups = map:FindFirstChild("WeaponPickups")
	if not pickups then
		return
	end
	for _, pad in pickups:GetChildren() do
		if pad:IsA("BasePart") then
			setupPad(pad)
		end
	end
end

return PickupService
