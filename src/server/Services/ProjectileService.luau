-- Proyectiles: cohetes y granadas. A diferencia de las balas (un raycast instantáneo),
-- estos viajan por el mundo y explotan al llegar.
--
-- Cohete: el servidor lo mueve en cada paso de la simulación (Heartbeat) y hace un
-- raycast corto desde donde está hasta donde va a estar. Si toca algo, explota ahí.
-- Granada: una bola con física real de Roblox; rebota y explota cuando se acaba la mecha.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Grenades = require(ReplicatedStorage.Shared.Config.Grenades)
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

local function onThrowGrenade(player: Player, direction: any)
	if typeof(direction) ~= "Vector3" or direction ~= direction or direction.Magnitude < 0.01 then
		return
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
	lastThrow[player] = now;
	(character :: Model):SetAttribute("Grenades", count - 1)

	local aim = direction.Unit
	local grenade = Instance.new("Part")
	grenade.Name = "Grenade"
	grenade.Shape = Enum.PartType.Ball
	grenade.Size = Vector3.one * 0.8
	grenade.Color = Color3.fromRGB(60, 70, 45)
	grenade.Material = Enum.Material.Metal
	-- Pesada, con algo de rebote y bastante fricción para que no ruede demasiado lejos
	grenade.CustomPhysicalProperties = PhysicalProperties.new(2, 0.8, 0.3)
	grenade.CFrame = CFrame.new(head.Position + aim * 2)
	-- Un poco hacia arriba, para que haga un arco
	grenade.AssemblyLinearVelocity = aim * Grenades.throwSpeed + Vector3.new(0, 12, 0)
	local light = Instance.new("PointLight") -- luz roja para verla en el suelo
	light.Color = Color3.fromRGB(255, 60, 40)
	light.Range = 6
	light.Parent = grenade
	grenade.Parent = workspace
	-- El servidor calcula su física: así todos la ven en el mismo sitio
	grenade:SetNetworkOwner(nil)
	ExplosionService.PlaySoundAt(Sounds.grenadeThrow, head.Position)

	task.delay(Grenades.fuse, function()
		if grenade.Parent then
			local position = grenade.Position
			grenade:Destroy()
			explodeAt(position, player, Grenades.blast)
		end
	end)
end

-- Cada vida empieza con las granadas de Config/Grenades
function ProjectileService.SetupCharacter(character: Model)
	character:SetAttribute("Grenades", Grenades.count)
end

function ProjectileService.Start()
	throwGrenade.OnServerEvent:Connect(onThrowGrenade)
	Players.PlayerRemoving:Connect(function(player)
		lastThrow[player] = nil
	end)
end

return ProjectileService
