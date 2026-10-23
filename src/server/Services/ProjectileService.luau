-- Proyectiles: cohetes y granadas. A diferencia de las balas (un raycast instantáneo),
-- estos viajan por el mundo y explotan al llegar.
--
-- Cohete: el servidor lo mueve en cada paso de la simulación (Heartbeat) y hace un
-- raycast corto desde donde está hasta donde va a estar. Si toca algo, explota ahí.
-- Granada: una bola con física real de Roblox; explota al chocar con algo o al acabarse la mecha.
-- En "Lluvia de SimiOs" (rules.grenadeStyle = "Simi") se lanza un muñeco de Doctor SimiO.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Grenades = require(ReplicatedStorage.Shared.Config.Grenades)
local Rules = require(script.Parent.Rules)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local ExplosionService = require(script.Parent.ExplosionService)
local VehicleService = require(script.Parent.VehicleService)

local remotes = ReplicatedStorage.Remotes
local hitConfirmed = remotes.HitConfirmed :: RemoteEvent
local throwGrenade = remotes.ThrowGrenade :: RemoteEvent

local ProjectileService = {}

local lastThrow: { [Player]: number } = {}

-- Explota, daña jugadores y jeeps cercanos, y avisa al atacante de cada enemigo que dañó
local function explodeAt(position: Vector3, attacker: Player, blast: ExplosionService.Blast)
	local hits = ExplosionService.Blast(position, attacker, blast)
	VehicleService.BlastVehicles(position, attacker, blast)
	for _, hit in hits do
		if hit.player ~= attacker then
			local surface = if hit.toHealth > 0 then "flesh" else "shield"
			hitConfirmed:FireClient(attacker, "hit", hit.toShield + hit.toHealth, hit.position, surface)
		end
	end
end

-- Cañón de iones: un círculo rojo marca el lugar y, tras stats.delay segundos, cae un rayo
-- del cielo que explota (stats.blast). Todos ven el aviso, así que da tiempo de huir.
function ProjectileService.IonStrike(point: Vector3, attacker: Player, stats)
	local radius = stats.blast.radius
	local marker = Instance.new("Part")
	marker.Name = "IonMarker"
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.2, radius * 2, radius * 2)
	marker.CFrame = CFrame.new(point + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	marker.Color = Color3.fromRGB(255, 60, 60)
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.6
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.CastShadow = false
	marker.Parent = workspace
	-- El círculo se va cerrando hasta el centro: cuando llega, cae el rayo
	TweenService:Create(marker, TweenInfo.new(stats.delay, Enum.EasingStyle.Linear), {
		Size = Vector3.new(0.2, 2, 2),
		Transparency = 0.2,
	}):Play()

	task.delay(stats.delay, function()
		marker:Destroy()
		local height = 300
		local beam = Instance.new("Part")
		beam.Name = "IonBeam"
		beam.Shape = Enum.PartType.Cylinder
		beam.Size = Vector3.new(height, 5, 5)
		beam.CFrame = CFrame.new(point + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		beam.Color = Color3.fromRGB(255, 120, 120)
		beam.Material = Enum.Material.Neon
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.CastShadow = false
		beam.Parent = workspace
		TweenService
			:Create(beam, TweenInfo.new(0.5), { Size = Vector3.new(height, 0.5, 0.5), Transparency = 1 })
			:Play()
		Debris:AddItem(beam, 0.5)
		explodeAt(point, attacker, stats.blast)
	end)
end

-- Lanza un cohete desde origin hacia direction. ignore: lo que el cohete atraviesa
-- (el propio tirador y su jeep). stats es la entrada de Config/Weapons.
function ProjectileService.FireRocket(
	player: Player,
	origin: Vector3,
	direction: Vector3,
	stats,
	ignore: { Instance }
)
	local velocity = direction.Unit * stats.speed

	local rocket = Instance.new("Part")
	rocket.Name = "Rocket"
	rocket.Size = Vector3.new(0.5, 0.5, 2)
	rocket.Color = Color3.fromRGB(85, 92, 60)
	rocket.Material = Enum.Material.Metal
	rocket.Anchored = true -- lo movemos nosotros, no la física
	rocket.CanCollide = false
	rocket.CanQuery = false -- que los raycasts (también el suyo) no lo toquen
	rocket.CanTouch = false
	rocket.CFrame = CFrame.lookAt(origin, origin + velocity)
	local fire = Instance.new("Fire") -- estela de fuego
	fire.Size = 2
	fire.Heat = 0
	fire.Parent = rocket
	rocket.Parent = workspace

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore

	local traveled = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		local position = rocket.Position
		local step = velocity * dt
		local result = workspace:Raycast(position, step, params)
		traveled += step.Magnitude
		if result or traveled >= stats.range then
			connection:Disconnect()
			rocket:Destroy()
			explodeAt(if result then result.Position else position + step, player, stats.blast)
			return
		end
		rocket.CFrame = CFrame.lookAt(position + step, position + step + velocity)
	end)
end

-- Una pieza del muñeco; solo la primera (el cuerpo) choca con las cosas
local function simiPart(name: string, size: Vector3, color: Color3, ball: boolean?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	if ball then
		part.Shape = Enum.PartType.Ball
	end
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	return part
end

-- El Doctor SimiO: cuerpo de doctor (bata blanca y corbata) con cara de chango: cabeza de
-- pelo café, cara clara, orejas, ojitos y nariz. Las medidas son desde el centro del cuerpo;
-- Z negativo = su frente.
local FUR = Color3.fromRGB(110, 70, 40)
local FACE = Color3.fromRGB(225, 185, 140)
local COAT = Color3.fromRGB(245, 245, 245)
local DARK = Color3.fromRGB(30, 30, 35)
local TIE = Color3.fromRGB(40, 90, 190)
local SIMI_PARTS = {
	{ "Head", Vector3.one * 1.0, FUR, true, CFrame.new(0, 0.95, 0) },
	{ "Face", Vector3.new(0.7, 0.6, 0.4), FACE, true, CFrame.new(0, 0.9, -0.32) },
	{ "Snout", Vector3.new(0.5, 0.32, 0.3), FACE, true, CFrame.new(0, 0.78, -0.5) },
	{ "Nose", Vector3.new(0.16, 0.08, 0.06), DARK, false, CFrame.new(0, 0.84, -0.66) },
	{ "LeftEar", Vector3.new(0.12, 0.34, 0.34), FACE, true, CFrame.new(-0.55, 0.98, 0) },
	{ "RightEar", Vector3.new(0.12, 0.34, 0.34), FACE, true, CFrame.new(0.55, 0.98, 0) },
	{ "LeftEye", Vector3.one * 0.12, DARK, true, CFrame.new(-0.15, 1.04, -0.5) },
	{ "RightEye", Vector3.one * 0.12, DARK, true, CFrame.new(0.15, 1.04, -0.5) },
	{ "Tie", Vector3.new(0.16, 0.45, 0.08), TIE, false, CFrame.new(0, 0.2, -0.66) },
	{
		"LeftArm",
		Vector3.new(0.28, 0.6, 0.28),
		COAT,
		false,
		CFrame.new(-0.72, 0, 0) * CFrame.Angles(0, 0, math.rad(-20)),
	},
	{
		"RightArm",
		Vector3.new(0.28, 0.6, 0.28),
		COAT,
		false,
		CFrame.new(0.72, 0, 0) * CFrame.Angles(0, 0, math.rad(20)),
	},
	{ "LeftHand", Vector3.one * 0.24, FUR, true, CFrame.new(-0.84, -0.3, 0) },
	{ "RightHand", Vector3.one * 0.24, FUR, true, CFrame.new(0.84, -0.3, 0) },
	{ "LeftLeg", Vector3.new(0.3, 0.32, 0.34), DARK, false, CFrame.new(-0.28, -0.72, 0) },
	{ "RightLeg", Vector3.new(0.3, 0.32, 0.34), DARK, false, CFrame.new(0.28, -0.72, 0) },
}

local function makeSimi(cframe: CFrame): BasePart
	local body = simiPart("DoctorSimiO", Vector3.one * 1.4, COAT, true)
	body.CanCollide = true
	body.CanTouch = true
	body.Massless = false
	body.CFrame = cframe
	for _, info in SIMI_PARTS do
		local part = simiPart(info[1], info[2], info[3], info[4])
		part.CFrame = cframe * info[5]
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = part
		weld.Parent = part
		part.Parent = body
	end
	return body
end

local function makeGrenade(cframe: CFrame): BasePart
	local grenade = Instance.new("Part")
	grenade.Name = "Grenade"
	grenade.Shape = Enum.PartType.Ball
	grenade.Size = Vector3.one * 0.8
	grenade.Color = Color3.fromRGB(60, 70, 45)
	grenade.Material = Enum.Material.Metal
	grenade.CFrame = cframe
	local light = Instance.new("PointLight") -- luz roja para verla en el suelo
	light.Color = Color3.fromRGB(255, 60, 40)
	light.Range = 6
	light.Parent = grenade
	return grenade
end

-- velocity: la velocidad inicial que calculó el cliente para que caiga donde apuntaste
local function onThrowGrenade(player: Player, velocity: any)
	if typeof(velocity) ~= "Vector3" or velocity ~= velocity or velocity.Magnitude < 0.01 then
		return
	end
	-- Un tramposo podría mandar una velocidad enorme: se recorta al máximo permitido
	if velocity.Magnitude > Grenades.maxThrowSpeed then
		velocity = velocity.Unit * Grenades.maxThrowSpeed
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head") :: BasePart?
	-- Hay que estar vivo y a pie (desde el jeep no se lanzan granadas)
	if not humanoid or not head or humanoid.Health <= 0 or humanoid.SeatPart then
		return
	end
	local now = os.clock()
	if now - (lastThrow[player] or 0) < Grenades.cooldown then
		return
	end
	local count = (character :: Model):GetAttribute("Grenades") or 0
	if count <= 0 then
		return
	end
	lastThrow[player] = now
	if not Rules.current.infiniteGrenades then
		(character :: Model):SetAttribute("Grenades", count - 1)
	end

	-- Sale por encima de la cabeza (el cliente calcula el arco desde el mismo punto),
	-- mirando hacia donde va
	local origin = head.Position + Vector3.yAxis * Grenades.throwHeight
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local start = if flat.Magnitude > 0.01 then CFrame.lookAt(origin, origin + flat) else CFrame.new(origin)
	local simi = Rules.current.grenadeStyle == "Simi"
	local grenade = if simi then makeSimi(start) else makeGrenade(start)
	local blast = if simi then Grenades.simi.blast else Grenades.blast
	grenade.AssemblyLinearVelocity = velocity
	if simi then
		-- Da maromas hacia el frente mientras vuela
		grenade.AssemblyAngularVelocity = start.RightVector * -Grenades.simi.spin
	end
	grenade.Parent = workspace
	-- El servidor calcula su física: así todos la ven en el mismo sitio
	grenade:SetNetworkOwner(nil)
	ExplosionService.PlaySoundAt(Sounds.grenadeThrow, head.Position)

	-- Explota una sola vez: al chocar con algo o al acabarse la mecha, lo que pase primero
	local exploded = false
	local function detonate()
		if exploded or not grenade.Parent then
			return
		end
		exploded = true
		local position = grenade.Position
		grenade:Destroy()
		explodeAt(position, player, blast)
	end
	-- Touched se dispara al chocar; se ignora a quien la lanzó (sale de su mano)
	grenade.Touched:Connect(function(other: BasePart)
		if not other:IsDescendantOf(character :: Model) then
			detonate()
		end
	end)
	task.delay(Grenades.fuse, detonate)
end

-- Cada vida empieza con las granadas de Config/Grenades (o las que diga el modo)
function ProjectileService.SetupCharacter(character: Model)
	character:SetAttribute("Grenades", Rules.current.grenades or Grenades.count)
	-- Para el HUD: "SimiOs ∞" en vez de "Granadas 2"
	character:SetAttribute("InfiniteGrenades", Rules.current.infiniteGrenades or nil)
	character:SetAttribute("GrenadeName", if Rules.current.grenadeStyle == "Simi" then "SimiOs" else nil)
end

function ProjectileService.Start()
	throwGrenade.OnServerEvent:Connect(onThrowGrenade)
	Players.PlayerRemoving:Connect(function(player)
		lastThrow[player] = nil
	end)
end

return ProjectileService
