-- El arma en primera persona: el rifle, la pistola o el lanzacohetes con dos brazos, pegados a
-- la cámara. Solo lo ve el jugador local; los demás ven el arma normal en tu mano.
--
-- Cada fotograma se calcula dónde va el arma: la posición base (view en Shared/WeaponModels)
-- más varios movimientos que se suman:
--   retroceso: al disparar se va hacia atrás y sube, y regresa sola
--   balanceo: se mueve un poco al caminar
--   inercia: al girar la cámara, el arma se queda un poquito atrás
--   recarga: baja y se inclina mientras recargas
--   al sacarla: sube desde abajo
-- Mientras se ve este modelo, el arma de la mano se esconde (solo para ti) para no verla doble.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WeaponModels = require(ReplicatedStorage.Shared.WeaponModels)
local CameraController = require(script.Parent.CameraController)

local player = Players.LocalPlayer
local rad = math.rad

local SLEEVE = Color3.fromRGB(70, 76, 56) -- manga del uniforme
local GLOVE = Color3.fromRGB(32, 32, 32)
local FLASH = Color3.fromRGB(255, 205, 110)
local FLASH_TIME = 0.05 -- segundos que dura el fogonazo

-- Dónde empiezan los brazos (fuera de la pantalla), medido desde la mano derecha
local RIGHT_SHOULDER = Vector3.new(0.6, -1.2, 1.4)
local LEFT_SHOULDER = Vector3.new(-1.1, -1.1, 0.6)

local ViewModel = {}

type Built = {
	name: string,
	spec: WeaponModels.Spec,
	folder: Folder,
	parts: { BasePart },
	offsets: { CFrame },
	flash: { BasePart },
}

local current: Built? = nil
local scoped = false -- con la mira del francotirador no se ve el arma
local hiddenTool: Tool? = nil

-- Movimientos (todos regresan solos a 0)
local kick, kickAngle, kickYaw = 0, 0, 0
local swayYaw, swayPitch = 0, 0
local bobTime = 0
local reloadAmount = 0
local equipAmount = 1
local bashAmount = 0
local flashUntil = 0
local lastYaw: number?, lastPitch: number? = nil, nil

local function newPart(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- Un brazo: la manga va del hombro a la muñeca y el guante queda en la mano
local function addArm(built: Built, shoulder: Vector3, hand: Vector3)
	local length = (hand - shoulder).Magnitude
	local sleeve = newPart("Sleeve", Vector3.new(0.34, 0.34, length), SLEEVE, Enum.Material.Fabric)
	table.insert(built.parts, sleeve)
	table.insert(built.offsets, CFrame.lookAt((shoulder + hand) / 2, hand))
	local glove = newPart("Glove", Vector3.new(0.26, 0.3, 0.34), GLOVE, Enum.Material.SmoothPlastic)
	table.insert(built.parts, glove)
	table.insert(built.offsets, CFrame.lookAt(hand, hand + (hand - shoulder)))
end

local function build(name: string): Built
	local spec = WeaponModels.Specs[name]
	local parts, offsets = WeaponModels.BuildLoose(name)
	local built: Built = {
		name = name,
		spec = spec,
		folder = Instance.new("Folder"),
		parts = parts,
		offsets = offsets,
		flash = {},
	}
	built.folder.Name = "ViewModel"

	addArm(built, RIGHT_SHOULDER, Vector3.new(0, -0.02, 0.05))
	addArm(built, LEFT_SHOULDER, spec.leftHand.Position)

	-- Fogonazo: una bola y un destello alargado en la boca del cañón, invisibles hasta disparar
	local ball = newPart("Flash", Vector3.one * 0.45, FLASH, Enum.Material.Neon)
	ball.Shape = Enum.PartType.Ball
	local flare = newPart("Flare", Vector3.new(0.12, 0.12, 0.8), FLASH, Enum.Material.Neon)
	for _, part in { ball, flare } do
		part.Transparency = 1
		table.insert(built.parts, part)
		table.insert(built.flash, part)
	end
	table.insert(built.offsets, spec.muzzle)
	table.insert(built.offsets, spec.muzzle * CFrame.new(0, 0, -0.35))

	for _, part in built.parts do
		part.Parent = built.folder
	end
	return built
end

-- Esconde (o vuelve a mostrar) el arma de la mano, solo para este jugador
local function hideTool(tool: Tool?)
	if hiddenTool == tool then
		return
	end
	if hiddenTool then
		for _, part in hiddenTool:GetDescendants() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 0
			end
		end
	end
	hiddenTool = tool
	if tool then
		for _, part in tool:GetDescendants() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 1
			end
		end
	end
end

-- Acerca un valor a su objetivo; rate más alto = más rápido (igual con cualquier FPS)
local function approach(value: number, target: number, rate: number, dt: number): number
	return target + (value - target) * math.exp(-rate * dt)
end

-- El ángulo más corto entre dos giros (para que dar la vuelta completa no dé un salto)
local function angleDelta(a: number, b: number): number
	return (a - b + math.pi) % (2 * math.pi) - math.pi
end

local function equippedSpec(): (Tool?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not humanoid or humanoid.Health <= 0 or humanoid.SeatPart then
		return nil, nil
	end
	if not tool or not WeaponModels.Specs[tool.Name] then
		return nil, nil
	end
	return tool, humanoid
end

local function update(dt: number)
	local tool, humanoid = equippedSpec()
	local camera = workspace.CurrentCamera
	if not tool or not humanoid or not CameraController.IsFirstPerson() then
		hideTool(nil)
		if current then
			current.folder.Parent = nil
		end
		equipAmount = 1 -- la próxima vez que se vea, sube desde abajo
		return
	end

	if not current or current.name ~= tool.Name then
		if current then
			current.folder:Destroy()
		end
		current = build(tool.Name)
		equipAmount = 1
	end
	local built = current :: Built
	hideTool(tool)
	if scoped then
		built.folder.Parent = nil
		return
	end
	built.folder.Parent = camera

	-- Inercia: qué tan rápido gira la cámara
	local pitch, yaw = camera.CFrame:ToOrientation()
	if lastYaw and lastPitch and dt > 0 then
		local yawSpeed = angleDelta(yaw, lastYaw) / dt
		local pitchSpeed = angleDelta(pitch, lastPitch) / dt
		swayYaw = approach(swayYaw, math.clamp(yawSpeed * 0.015, -0.08, 0.08), 10, dt)
		swayPitch = approach(swayPitch, math.clamp(pitchSpeed * 0.015, -0.06, 0.06), 10, dt)
	end
	lastYaw, lastPitch = yaw, pitch

	-- Balanceo al caminar (solo en el suelo)
	local root = humanoid.RootPart
	local velocity = if root then root.AssemblyLinearVelocity else Vector3.zero
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local walking = if humanoid.FloorMaterial ~= Enum.Material.Air then math.clamp(speed / 16, 0, 1) else 0
	bobTime += dt * speed * 0.55
	local bobX = math.sin(bobTime) * 0.035 * walking
	local bobY = (math.cos(bobTime * 2) - 1) * 0.02 * walking
	local breathe = math.sin(os.clock() * 1.6) * 0.006

	kick = approach(kick, 0, 14, dt)
	kickAngle = approach(kickAngle, 0, 12, dt)
	kickYaw = approach(kickYaw, 0, 12, dt)
	equipAmount = approach(equipAmount, 0, 9, dt)
	bashAmount = approach(bashAmount, 0, 9, dt)
	reloadAmount = approach(reloadAmount, if tool:GetAttribute("Reloading") then 1 else 0, 10, dt)

	local grip = camera.CFrame
		* built.spec.view
		* CFrame.new(
			bobX - bashAmount * 0.35,
			bobY + breathe - reloadAmount * 0.35 - equipAmount * 0.9,
			kick + reloadAmount * 0.15 - bashAmount * 0.6
		)
		* CFrame.Angles(
			rad(kickAngle) + swayPitch - reloadAmount * rad(25) - equipAmount * rad(35),
			swayYaw + rad(kickYaw) + bashAmount * rad(20),
			reloadAmount * rad(18)
		)

	local shown = os.clock() < flashUntil
	for _, part in built.flash do
		part.Transparency = if shown then 0.15 else 1
	end
	local spin = CFrame.Angles(0, 0, math.random() * math.pi)
	local cframes = table.create(#built.parts)
	for i, offset in built.offsets do
		cframes[i] = grip * offset
	end
	-- El destello gira un poco cada disparo para que no se vea siempre igual
	local count = #built.parts
	cframes[count] = cframes[count] * spin
	workspace:BulkMoveTo(built.parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Lo llama WeaponController cada vez que disparas
function ViewModel.Kick()
	if not current then
		return
	end
	local spec = current.spec
	kick += spec.kick
	kickAngle = math.min(kickAngle + spec.kickAngle * (0.8 + math.random() * 0.4), spec.kickAngle * 4)
	kickYaw += (math.random() - 0.5) * spec.kickAngle * 0.4
	flashUntil = os.clock() + FLASH_TIME
end

-- Lo llama SpecialWeapons al apuntar con la mira del francotirador
function ViewModel.SetScoped(value: boolean)
	scoped = value
end

-- Lo llama MeleeController al golpear: el arma se va hacia el frente y a la izquierda
function ViewModel.Bash()
	bashAmount = 1
end

-- Dónde está la boca del cañón en primera persona (nil si no se está viendo)
function ViewModel.GetMuzzle(): Vector3?
	if not current or not current.folder.Parent then
		return nil
	end
	local built = current :: Built
	local flash = built.flash[1]
	return flash.Position
end

function ViewModel.Start()
	-- Después de la cámara (CameraController usa Camera + 1)
	RunService:BindToRenderStep("ZonaCeroViewModel", Enum.RenderPriority.Camera.Value + 2, update)
end

return ViewModel
