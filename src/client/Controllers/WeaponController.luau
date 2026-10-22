-- Controla el arma del jugador local: apuntar, disparar, recargar y dibujar trazadoras.
-- El cliente nunca hace daño: solo le dice al servidor hacia dónde disparó.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Aim = require(script.Parent.Aim)
local Sfx = require(script.Parent.Sfx)

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
	return head.Position, Aim.GetTarget() - head.Position
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
		Sfx.PlayLocal(Sounds.empty)
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

-- Color del destello del impacto según lo que tocó la bala
local IMPACT_COLORS = {
	shield = Color3.fromRGB(90, 200, 255), -- azul: el escudo absorbió el disparo
	flesh = Color3.fromRGB(200, 30, 30), -- rojo: el disparo llegó a la vida
	metal = Color3.fromRGB(255, 200, 80), -- chispas amarillas: el jeep o algo de metal
	wood = Color3.fromRGB(140, 95, 50), -- astillas
	concrete = Color3.fromRGB(150, 140, 120), -- polvo: el suelo o una pared
}

-- Una línea brillante que se desvanece entre el arma y el impacto
local function drawTracer(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local tracer = Instance.new("Part")
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.CastShadow = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(255, 220, 120)
	tracer.Size = Vector3.new(0.12, 0.12, length)
	tracer.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	tracer.Parent = workspace
	TweenService:Create(tracer, TweenInfo.new(0.1), { Transparency = 1 }):Play()
	Debris:AddItem(tracer, 0.1)
end

-- Una bolita que crece y se desvanece donde pegó la bala
local function drawImpact(position: Vector3, surface: string?)
	local impact = Instance.new("Part")
	impact.Shape = Enum.PartType.Ball
	impact.Anchored = true
	impact.CanCollide = false
	impact.CanQuery = false
	impact.CastShadow = false
	impact.Material = Enum.Material.Neon
	impact.Color = IMPACT_COLORS[surface or "concrete"] or IMPACT_COLORS.concrete
	impact.Size = Vector3.one * 0.3
	impact.Position = position
	impact.Parent = workspace
	-- Los impactos en jugadores y jeeps se ven más grandes
	local grow = if surface == "shield" or surface == "flesh" or surface == "metal" then 1.6 else 0.8
	TweenService:Create(impact, TweenInfo.new(0.2), { Size = Vector3.one * grow, Transparency = 1 }):Play()
	Debris:AddItem(impact, 0.2)
end

local function onShotFired(
	from: Vector3,
	to: Vector3,
	hit: boolean?,
	surface: string?,
	weaponName: string?,
	source: BasePart?
)
	local fireSound = weaponName and Sounds.fire[weaponName]
	if weaponName and Sounds.burst[weaponName] and source then
		Sfx.KeepBurst(fireSound, source)
	else
		Sfx.PlayAt(fireSound, from)
	end
	drawTracer(from, to)
	if hit then
		drawImpact(to, surface)
		-- En el escenario o en un jeep suena el material; en un jugador, el aviso de acierto
		Sfx.PlayAt(surface and Sounds.impact[surface], to, 0.5)
	end
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

	shotFired.OnClientEvent:Connect(onShotFired)
end

return WeaponController
