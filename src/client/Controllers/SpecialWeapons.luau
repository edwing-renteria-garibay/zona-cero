-- Lo especial de algunas armas, del lado del jugador:
--   Francotirador: clic derecho (o L2 en mando) para apuntar con zoom
--   Cañón de iones: un láser rojo marca a dónde va a caer el rayo
--   Arma de hielo: si te da, la pantalla se pone azul y oyes el sonido de congelado

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Aim = require(script.Parent.Aim)
local Sfx = require(script.Parent.Sfx)
local ViewModel = require(script.Parent.ViewModel)

local frozenRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Frozen") :: RemoteEvent

local player = Players.LocalPlayer

local NORMAL_FOV = 70

local SpecialWeapons = {}

local scoped = false
local gui: ScreenGui
local scopeFrame: Frame
local frost: Frame
local pointer: Part
local dot: Part

-- El arma en la mano y sus datos, si está vivo
local function equipped(): (Tool?, any)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not humanoid or humanoid.Health <= 0 or not tool then
		return nil, nil
	end
	return tool, Weapons[tool.Name]
end

local function setScoped(value: boolean)
	scoped = value
	scopeFrame.Visible = value
	ViewModel.SetScoped(value)
	if not value then
		UserInputService.MouseDeltaSensitivity = 1
	end
end

local function onScope(_name: string, state: Enum.UserInputState)
	local tool, stats = equipped()
	if not tool or not stats or not stats.zoom then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		setScoped(not scoped)
	end
	return Enum.ContextActionResult.Sink
end

local function newPart(name: string, shape: Enum.PartType, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = Color3.fromRGB(255, 40, 40)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- La mira: un círculo transparente rodeado de negro (un borde muy grueso) y una cruz
local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "SpecialWeapons"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	scopeFrame = Instance.new("Frame")
	scopeFrame.Name = "Scope"
	scopeFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	scopeFrame.Position = UDim2.fromScale(0.5, 0.5)
	scopeFrame.Size = UDim2.fromScale(0.9, 0.9)
	scopeFrame.BackgroundTransparency = 1
	scopeFrame.Visible = false
	scopeFrame.Parent = gui
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = scopeFrame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = scopeFrame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2000
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = scopeFrame
	for _, size in { UDim2.new(1, 0, 0, 2), UDim2.new(0, 2, 1, 0) } do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5, 0.5)
		line.Size = size
		line.BackgroundColor3 = Color3.new(0, 0, 0)
		line.BorderSizePixel = 0
		line.Parent = scopeFrame
	end

	frost = Instance.new("Frame")
	frost.Name = "Frost"
	frost.Size = UDim2.fromScale(1, 1)
	frost.BackgroundColor3 = Color3.fromRGB(150, 220, 255)
	frost.BackgroundTransparency = 1
	frost.BorderSizePixel = 0
	frost.Parent = gui
end

local function onFrozen(duration: number)
	Sfx.PlayLocal(Sounds.frozen)
	frost.BackgroundTransparency = 0.6
	TweenService:Create(frost, TweenInfo.new(duration), { BackgroundTransparency = 1 }):Play()
end

-- La boca del arma: la de primera persona si se ve, si no la del arma en la mano
local function muzzlePosition(tool: Tool): Vector3?
	local view = ViewModel.GetMuzzle()
	if view then
		return view
	end
	local muzzle = tool:FindFirstChild("Muzzle", true) :: Attachment?
	return muzzle and muzzle.WorldPosition
end

local function update()
	local camera = workspace.CurrentCamera
	local tool, stats = equipped()

	-- Zoom: se quita solo si cambias de arma, recargas o mueres
	if scoped and (not stats or not stats.zoom or (tool :: Tool):GetAttribute("Reloading")) then
		setScoped(false)
	end
	local fov = if scoped then stats.zoom else NORMAL_FOV
	camera.FieldOfView += (fov - camera.FieldOfView) * 0.35
	if scoped then
		-- Con zoom el mouse gira más despacio, para poder apuntar fino
		UserInputService.MouseDeltaSensitivity = camera.FieldOfView / NORMAL_FOV
		-- La cruz de la mira va justo donde apunta el disparo (Aim.GetScreenPoint). Roblox
		-- fija el mouse en el centro del área de juego, que queda un poco más abajo que el
		-- centro de la pantalla por la barra de arriba: centrarla con escala 0.5 la movía.
		local point = Aim.GetScreenPoint()
		scopeFrame.Position = UDim2.fromOffset(point.X, point.Y)
	end

	-- Láser del cañón de iones
	local from = tool and stats and stats.kind == "ion" and muzzlePosition(tool)
	if from then
		local target = Aim.GetTarget()
		local length = (target - from).Magnitude
		pointer.Size = Vector3.new(0.05, 0.05, length)
		pointer.CFrame = CFrame.lookAt(from, target) * CFrame.new(0, 0, -length / 2)
		dot.Position = target
		pointer.Parent = workspace
		dot.Parent = workspace
	else
		pointer.Parent = nil
		dot.Parent = nil
	end
end

function SpecialWeapons.Start()
	buildGui()
	pointer = newPart("IonPointer", Enum.PartType.Block, Vector3.one * 0.05)
	pointer.Transparency = 0.3
	dot = newPart("IonDot", Enum.PartType.Ball, Vector3.one * 0.6)

	ContextActionService:BindAction(
		"Scope",
		onScope,
		false,
		Enum.UserInputType.MouseButton2,
		Enum.KeyCode.ButtonL2
	)
	frozenRemote.OnClientEvent:Connect(onFrozen)
	RunService:BindToRenderStep("ZonaCeroSpecialWeapons", Enum.RenderPriority.Camera.Value + 3, update)
end

return SpecialWeapons
