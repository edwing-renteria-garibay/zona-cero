-- Controla el arma del jugador local: apuntar, disparar, recargar y dibujar trazadoras.
-- El cliente nunca hace daño: solo le dice al servidor hacia dónde disparó.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local fireWeapon = remotes:WaitForChild("FireWeapon") :: RemoteEvent
local reloadWeapon = remotes:WaitForChild("ReloadWeapon") :: RemoteEvent
local shotFired = remotes:WaitForChild("ShotFired") :: RemoteEvent

local player = Players.LocalPlayer

local WeaponController = {}

local triggerHeld = false
local lastShot = 0
local connectedTools: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- El arma que el jugador tiene en la mano, si es una de Config/Weapons
function WeaponController.GetEquipped(): (Tool?, any)
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local stats = tool and Weapons[tool.Name]
	if not tool or not stats then
		return nil, nil
	end
	return tool, stats
end

-- Balas en el cargador; el servidor guarda el valor real en el atributo "Ammo"
function WeaponController.GetAmmo(tool: Tool, stats): number
	local ammo = tool:GetAttribute("Ammo")
	return if ammo == nil then stats.magazine else ammo
end

-- Calcula hacia dónde dispara: desde la cabeza hacia el punto que señala el mouse
local function aim(): (Vector3?, Vector3?)
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil, nil
	end
	local camera = workspace.CurrentCamera
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	local target = if result then result.Position else ray.Origin + ray.Direction * 1000
	return head.Position, target - head.Position
end

local function tryFire()
	local tool, stats = WeaponController.GetEquipped()
	if not tool or tool:GetAttribute("Reloading") then
		return
	end
	local now = os.clock()
	if now - lastShot < 1 / stats.fireRate then
		return
	end
	if WeaponController.GetAmmo(tool, stats) <= 0 then
		reloadWeapon:FireServer() -- cargador vacío: recarga automática
		triggerHeld = false -- suelta el gatillo para no pedir la recarga en cada fotograma
		return
	end
	local origin, direction = aim()
	if not origin then
		return
	end
	lastShot = now
	fireWeapon:FireServer(origin, direction)
	if not stats.automatic then
		triggerHeld = false -- las armas semiautomáticas disparan una vez por clic
	end
end

-- Una línea brillante muy breve entre el arma y el impacto
local function drawTracer(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local tracer = Instance.new("Part")
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(255, 220, 120)
	tracer.Size = Vector3.new(0.1, 0.1, length)
	tracer.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	tracer.Parent = workspace
	Debris:AddItem(tracer, 0.05)
end

-- Tool.Activated funciona igual con clic, toque en móvil o gatillo del mando
local function connectTool(tool: Instance)
	if not tool:IsA("Tool") or connectedTools[tool] or not Weapons[tool.Name] then
		return
	end
	connectedTools[tool] = true
	tool.Activated:Connect(function()
		triggerHeld = true
	end)
	tool.Deactivated:Connect(function()
		triggerHeld = false
	end)
	tool.Unequipped:Connect(function()
		triggerHeld = false
	end)
end

function WeaponController.Start()
	player.CharacterAdded:Connect(function(character)
		character.ChildAdded:Connect(connectTool)
	end)
	if player.Character then
		player.Character.ChildAdded:Connect(connectTool)
	end

	UserInputService.InputBegan:Connect(function(input, typing)
		if not typing and input.KeyCode == Enum.KeyCode.R then
			reloadWeapon:FireServer()
		end
	end)

	RunService.Heartbeat:Connect(function()
		if triggerHeld then
			tryFire()
		end
	end)

	shotFired.OnClientEvent:Connect(drawTracer)
end

return WeaponController
