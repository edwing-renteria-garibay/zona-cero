-- Lanzar granada: mantén G (B / Círculo en control, botón "Granada" en móvil) para apuntar
-- y suelta para lanzarla. Mientras apuntas se dibuja el arco y un círculo donde caerá.
-- En los modos de granadas infinitas (Lluvia de SimiOs) no hay armas: ahí también se lanzan
-- con el disparo normal (clic o RT / R2), para que nadie tenga que adivinar la G.
--
-- La granada cae donde señala tu mouse: el cliente calcula la velocidad inicial
-- con la fórmula del tiro parabólico y se la manda al servidor, que crea la granada.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Actions = require(script.Parent.Actions)
local Grenades = require(ReplicatedStorage.Shared.Config.Grenades)
local Modes = require(ReplicatedStorage.Shared.Config.Modes)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Aim = require(script.Parent.Aim)
local Sfx = require(script.Parent.Sfx)

local throwGrenade = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ThrowGrenade") :: RemoteEvent

local player = Players.LocalPlayer

local ARC_POINTS = 24 -- bolitas que dibujan el arco
local ARC_COLOR = Color3.fromRGB(255, 200, 80)

local GrenadeController = {}

local lastThrow = 0
local aiming = false
local arcFolder: Folder? = nil
local arcDots: { BasePart } = {}
local landingMarker: BasePart? = nil

-- Granadas que te quedan (el servidor guarda el valor real en el atributo "Grenades")
function GrenadeController.GetCount(): number
	local character = player.Character
	return character and character:GetAttribute("Grenades") or 0
end

-- Desde dónde sale la granada (igual que en el servidor)
local function getOrigin(): Vector3?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not head or not humanoid or humanoid.Health <= 0 or humanoid.SeatPart then
		return nil
	end
	return head.Position + Vector3.yAxis * Grenades.throwHeight
end

-- Tiro parabólico: ¿con qué velocidad hay que lanzarla para que caiga en target?
-- La posición en el tiempo t es: origen + v·t − ½·g·t²  (g = gravedad, hacia abajo).
-- Elegimos cuánto tarda en llegar (más lejos = más tiempo, así hace un arco bonito)
-- y despejamos v.
local function velocityTo(origin: Vector3, target: Vector3): Vector3
	local offset = target - origin
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude > Grenades.maxRange then
		-- Apuntas demasiado lejos: cae a la distancia máxima, en la misma dirección
		flat = flat.Unit * Grenades.maxRange
		offset = Vector3.new(flat.X, math.min(offset.Y, 0), flat.Z)
	end
	local flightTime = 0.3 + flat.Magnitude / 100 -- segundos en el aire
	local gravity = workspace.Gravity
	return offset / flightTime + Vector3.yAxis * (0.5 * gravity * flightTime)
end

local function makeDot(size: number, parent: Instance): BasePart
	local dot = Instance.new("Part")
	dot.Shape = Enum.PartType.Ball
	dot.Size = Vector3.one * size
	dot.Anchored = true
	dot.CanCollide = false
	dot.CanQuery = false
	dot.CanTouch = false
	dot.CastShadow = false
	dot.Material = Enum.Material.Neon
	dot.Color = ARC_COLOR
	dot.Parent = parent
	return dot
end

local function hideArc()
	if arcFolder then
		arcFolder:Destroy()
	end
	arcFolder = nil
	arcDots = {}
	landingMarker = nil
end

local function showArc()
	hideArc()
	local folder = Instance.new("Folder")
	folder.Name = "GrenadeArc"
	folder.Parent = workspace
	for _ = 1, ARC_POINTS do
		table.insert(arcDots, makeDot(0.3, folder))
	end
	-- Círculo plano donde caerá
	local marker = Instance.new("Part")
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.1, 4, 4)
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromRGB(255, 60, 40)
	marker.Transparency = 0.4
	marker.Parent = folder
	landingMarker = marker
	arcFolder = folder
end

-- Recorre el arco en pequeños tramos y para donde chocaría (ahí explota)
local function updateArc()
	local origin = getOrigin()
	if not origin or not landingMarker then
		return
	end
	local velocity = velocityTo(origin, Aim.GetTarget())
	local gravity = Vector3.yAxis * -workspace.Gravity
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Model, arcFolder :: Folder }

	local step = Grenades.fuse / ARC_POINTS
	local previous = origin
	local landed: RaycastResult? = nil
	for i, dot in arcDots do
		local t = i * step
		local point = origin + velocity * t + 0.5 * gravity * t * t
		if not landed then
			landed = workspace:Raycast(previous, point - previous, params)
		end
		dot.Transparency = if landed then 1 else 0.2
		dot.Position = point
		previous = point
	end
	if landed then
		-- El cilindro de Roblox se acuesta sobre su eje X: lo giramos según la superficie
		landingMarker.CFrame = CFrame.lookAt(landed.Position, landed.Position + landed.Normal)
			* CFrame.Angles(0, math.rad(90), 0)
		landingMarker.Transparency = 0.4
	else
		landingMarker.Transparency = 1 -- explotará en el aire
	end
end

local function throw()
	local origin = getOrigin()
	local now = os.clock()
	if not origin or now - lastThrow < Grenades.cooldown then
		return
	end
	lastThrow = now
	throwGrenade:FireServer(velocityTo(origin, Aim.GetTarget()))
end

local function onAction(_name: string, state: Enum.UserInputState)
	if player:GetAttribute("MenuOpen") then
		return Enum.ContextActionResult.Pass -- con la tienda abierta, B es para el menú
	end
	if state == Enum.UserInputState.Begin then
		if GrenadeController.GetCount() <= 0 then
			Sfx.PlayLocal(Sounds.empty)
		elseif getOrigin() then
			aiming = true
			showArc()
		end
		return Enum.ContextActionResult.Sink
	elseif state == Enum.UserInputState.End and aiming then
		aiming = false
		hideArc()
		throw()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

-- ¿El disparo lanza granadas? (modos con granadas infinitas, como Lluvia de SimiOs)
local fireThrows = false
function GrenadeController.FireThrows(): boolean
	return fireThrows
end

function GrenadeController.Start()
	-- En control usamos B: L1 y R1 ya los usa Roblox para cambiar de arma. El botón de móvil
	-- es de UI/TouchButtons (por eso el "false")
	Actions.Bind("Grenade", onAction, false, Enum.KeyCode.G, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("Grenade", "Granada")

	-- Granadas infinitas: el disparo también lanza (por encima del golpe con clic)
	local function updateFire()
		local mode = Modes[ReplicatedStorage:GetAttribute("MatchMode") or ""]
		local wanted = type(mode) == "table" and mode.infiniteGrenades == true
		if wanted == fireThrows then
			return
		end
		fireThrows = wanted
		if wanted then
			Actions.BindAtPriority(
				"GrenadeFire",
				onAction,
				false,
				Enum.ContextActionPriority.High.Value,
				Enum.UserInputType.MouseButton1,
				Enum.KeyCode.ButtonR2
			)
		else
			Actions.Unbind("GrenadeFire")
		end
		ContextActionService:SetTitle(
			"Grenade",
			if wanted and mode.grenadeStyle == "Simi" then "SimiO" else "Granada"
		)
	end
	ReplicatedStorage:GetAttributeChangedSignal("MatchMode"):Connect(updateFire)
	updateFire()

	RunService.RenderStepped:Connect(function()
		if not aiming then
			return
		end
		-- Si mueres o te subes a un jeep mientras apuntas, se cancela
		if not getOrigin() then
			aiming = false
			hideArc()
			return
		end
		updateArc()
	end)
end

return GrenadeController
