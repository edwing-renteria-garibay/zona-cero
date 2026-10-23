-- Controla el arma del jugador local: apuntar, disparar, recargar y dibujar trazadoras.
-- El cliente nunca hace daño: solo le dice al servidor hacia dónde disparó.

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Aim = require(script.Parent.Aim)
local CameraController = require(script.Parent.CameraController)
local Sfx = require(script.Parent.Sfx)
local ViewModel = require(script.Parent.ViewModel)

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
		Sfx.PlayLocal(Sounds.emptyBy[tool.Name] or Sounds.empty)
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
	ViewModel.Kick() -- el arma se mueve y hace fogonazo en primera persona
	if stats.recoil then
		CameraController.Kick(stats.recoil) -- la mira sube (escopeta, lanzacohetes, francotirador)
	end
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

-- Fogonazo en la boca del arma de otro jugador (o la tuya en tercera persona): una luz que
-- dura un instante
local function drawMuzzleFlash(position: Vector3)
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 205, 110)
	flash.Size = Vector3.one * 0.5
	flash.Position = position
	local light = Instance.new("PointLight")
	light.Color = flash.Color
	light.Range = 10
	light.Brightness = 3
	light.Parent = flash
	flash.Parent = workspace
	Debris:AddItem(flash, 0.05)
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

-- Rayos de energía: más gruesos que una bala y de color (Config/Weapons, beam)
local BEAMS = {
	laser = { color = Color3.fromRGB(80, 255, 90), width = 0.3, time = 0.3 },
	ice = { color = Color3.fromRGB(150, 220, 255), width = 0.22, time = 0.25 },
	ion = { color = Color3.fromRGB(255, 60, 60), width = 0.08, time = 0.15 },
}

local function drawBeam(from: Vector3, to: Vector3, style)
	local length = (to - from).Magnitude
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = style.color
	beam.Size = Vector3.new(style.width, style.width, length)
	beam.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	beam.Parent = workspace
	TweenService:Create(beam, TweenInfo.new(style.time), {
		Transparency = 1,
		Size = Vector3.new(style.width * 0.2, style.width * 0.2, length),
	}):Play()
	Debris:AddItem(beam, style.time)
end

-- Llamas: bolas naranjas que salen del arma, crecen y se apagan
local FLAME_COLORS =
	{ Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 120, 30), Color3.fromRGB(230, 70, 20) }
local function drawFlame(from: Vector3, to: Vector3)
	for i = 1, 4 do
		local flame = Instance.new("Part")
		flame.Shape = Enum.PartType.Ball
		flame.Anchored = true
		flame.CanCollide = false
		flame.CanQuery = false
		flame.CanTouch = false
		flame.CastShadow = false
		flame.Material = Enum.Material.Neon
		flame.Color = FLAME_COLORS[(i - 1) % #FLAME_COLORS + 1]
		flame.Size = Vector3.one * 0.5
		flame.Position = from
		flame.Parent = workspace
		local time = 0.2 + i * 0.06
		-- Las llamas se abren a los lados: el lanzallamas quema un área ancha y corta
		local spread = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 7
		TweenService:Create(flame, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = from:Lerp(to, 0.5 + i * 0.12) + spread,
			Size = Vector3.one * (1.5 + i),
			Transparency = 1,
		}):Play()
		Debris:AddItem(flame, time)
	end
end

local function onShotFired(
	from: Vector3,
	to: Vector3,
	hit: boolean?,
	surface: string?,
	weaponName: string?,
	source: BasePart?,
	shooter: Player?
)
	-- Tus disparos en primera persona salen del arma que ves, no de la que está en tu mano
	local viewMuzzle = if shooter == player then ViewModel.GetMuzzle() else nil
	local stats = weaponName and Weapons[weaponName]
	-- Los perdigones de la escopeta después del primero no suenan ni hacen fogonazo
	local extraPellet = weaponName == "ShotgunPellet"
	if viewMuzzle then
		from = viewMuzzle
	elseif weaponName ~= "Turret" and not extraPellet and not (stats and stats.beam) then
		drawMuzzleFlash(from)
	end
	local fireSound = weaponName and Sounds.fire[weaponName]
	if weaponName and Sounds.burst[weaponName] and source then
		Sfx.KeepBurst(fireSound, source)
	elseif not extraPellet then
		Sfx.PlayAt(fireSound, from)
	end
	if stats and stats.kind == "flame" then
		drawFlame(from, to)
	elseif stats and stats.beam then
		drawBeam(from, to, BEAMS[stats.beam])
	else
		drawTracer(from, to)
	end
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
	-- Sonido de recarga (Config/Sounds, reload): el servidor marca "Reloading" al empezar
	tool:GetAttributeChangedSignal("Reloading"):Connect(function()
		if tool:GetAttribute("Reloading") and tool.Parent == player.Character then
			Sfx.PlayLocal(Sounds.reload[tool.Name])
		end
	end)
end

function WeaponController.Start()
	player.CharacterAdded:Connect(function(character)
		character.ChildAdded:Connect(connectTool)
	end)
	if player.Character then
		player.Character.ChildAdded:Connect(connectTool)
	end

	-- Recargar: R en teclado, X (Cuadrado en PlayStation) en control y botón "Recargar" en
	-- móvil (el "true" crea el botón táctil)
	ContextActionService:BindAction("Reload", function(_name, state)
		if state == Enum.UserInputState.Begin then
			reloadWeapon:FireServer()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("Reload", "Recargar")

	RunService.Heartbeat:Connect(function()
		if triggerHeld then
			tryFire()
		end
	end)

	shotFired.OnClientEvent:Connect(onShotFired)
end

return WeaponController
