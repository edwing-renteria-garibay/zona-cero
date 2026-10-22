-- Disparos, recarga y golpes cuerpo a cuerpo. El cliente solo avisa "disparé desde aquí hacia allá";
-- el servidor comprueba que el disparo sea posible (arma en la mano, munición,
-- cadencia, origen cerca del jugador) y es el único que hace daño.
-- Así nadie puede hacer trampa enviando disparos imposibles.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Melee = require(ReplicatedStorage.Shared.Config.Melee)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local HealthService = require(script.Parent.HealthService)
local VehicleService = require(script.Parent.VehicleService)

local remotes = ReplicatedStorage.Remotes
local fireWeapon = remotes.FireWeapon :: RemoteEvent
local fireTurret = remotes.FireTurret :: RemoteEvent
local reloadWeapon = remotes.ReloadWeapon :: RemoteEvent
local shotFired = remotes.ShotFired :: RemoteEvent
local hitConfirmed = remotes.HitConfirmed :: RemoteEvent
local meleeRemote = remotes.Melee :: RemoteEvent

local MAX_ORIGIN_DISTANCE = 10 -- studs permitidos entre la cabeza y el origen del disparo
local FIRE_RATE_TOLERANCE = 0.8 -- acepta disparos un poco más seguidos por la latencia de la red

local CombatService = {}

local lastShot: { [Player]: number } = {}
local lastTurretShot: { [Player]: number } = {}
local reloading: { [Player]: boolean } = {}
local lastMelee: { [Player]: number } = {}

-- Devuelve el arma que el jugador tiene en la mano y sus datos de Config/Weapons
local function getEquippedWeapon(player: Player): (Tool?, any)
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local stats = tool and Weapons[tool.Name]
	if not tool or not stats then
		return nil, nil
	end
	-- La primera vez que se usa un arma se llena su cargador
	if tool:GetAttribute("Ammo") == nil then
		tool:SetAttribute("Ammo", stats.magazine)
	end
	return tool, stats
end

-- ¿Puede el tirador dañar a este objetivo? (target es nil para un muñeco de práctica)
local function isEnemy(shooter: Player, target: Player?): boolean
	if target == nil then
		return true
	end
	if target == shooter then
		return false
	end
	if shooter.Neutral or target.Neutral then
		return true
	end
	return shooter.Team ~= target.Team
end

-- ¿La pieza es la cabeza? También cuenta un sombrero o gorro (un Accessory)
-- pegado a la cabeza, para que el gorro no "proteja" del tiro a la cabeza
local function isHeadPart(part: BasePart): boolean
	if part.Name == "Head" then
		return true
	end
	if part.Parent and part.Parent:IsA("Accessory") then
		local weld = part:FindFirstChild("AccessoryWeld") :: Weld?
		local attachedTo = weld and weld.Part1
		return attachedTo ~= nil and attachedTo.Name == "Head"
	end
	return false
end

-- Aplica el daño de un impacto (a un jeep o a un personaje enemigo) y avisa al tirador
-- para que su mira cambie de color ("hit" en el cuerpo o en un jeep, "head" en la cabeza)
-- y vea cuánto daño hizo. Devuelve qué tocó la bala, para el efecto del impacto:
-- "shield" (escudo), "flesh" (vida), "metal" (jeep) o nil (el escenario o un compañero).
local function applyHit(
	attacker: Player,
	result: RaycastResult,
	damage: number,
	headshotMultiplier: number?
): string?
	local model = result.Instance:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	local vehicle = VehicleService.GetVehicle(result.Instance)
	if vehicle then
		if VehicleService.Damage(vehicle, damage, attacker, result.Instance :: BasePart) then
			hitConfirmed:FireClient(attacker, "hit", damage, result.Position, "metal")
		end
		return "metal"
	end
	local targetHumanoid = model:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid or not isEnemy(attacker, Players:GetPlayerFromCharacter(model)) then
		return nil
	end
	local headshot = headshotMultiplier ~= nil and isHeadPart(result.Instance :: BasePart)
	if headshot then
		damage *= headshotMultiplier :: number
	end
	local toShield, toHealth = HealthService.Damage(targetHumanoid, damage, attacker)
	if toShield + toHealth <= 0 then
		return nil -- tenía protección de aparición
	end
	local surface = if toHealth > 0 then "flesh" else "shield"
	hitConfirmed:FireClient(
		attacker,
		if headshot then "head" else "hit",
		toShield + toHealth,
		result.Position,
		surface
	)
	return surface
end

local function onFire(player: Player, origin: any, direction: any)
	-- Lo que llega del cliente puede ser cualquier cosa: primero se revisa el tipo
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end
	-- direction ~= direction detecta valores inválidos (NaN)
	if direction ~= direction or direction.Magnitude < 0.01 then
		return
	end

	local tool, stats = getEquippedWeapon(player)
	if not tool or reloading[player] then
		return
	end
	local character = player.Character :: Model
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local head = character:FindFirstChild("Head") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not head then
		return
	end

	local now = os.clock()
	if now - (lastShot[player] or 0) < FIRE_RATE_TOLERANCE / stats.fireRate then
		return
	end
	local ammo = tool:GetAttribute("Ammo") :: number
	if ammo <= 0 then
		return
	end
	if (origin - head.Position).Magnitude > MAX_ORIGIN_DISTANCE then
		return
	end

	lastShot[player] = now
	tool:SetAttribute("Ammo", ammo - 1)

	-- Raycast: una línea invisible desde el origen; devuelve lo primero que toca
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	-- No dispararse a uno mismo ni al jeep en el que vas sentado
	local filter: { Instance } = { character }
	local myVehicle = VehicleService.GetVehicle(humanoid.SeatPart)
	if myVehicle then
		table.insert(filter, myVehicle)
	end
	params.FilterDescendantsInstances = filter
	local ray = direction.Unit * stats.range
	local result = workspace:Raycast(origin, ray, params)
	local hitPosition = if result then result.Position else origin + ray

	local surface = if result then applyHit(player, result, stats.damage, stats.headshotMultiplier) else nil

	-- Todos los jugadores dibujan la trazadora desde el arma hasta el impacto,
	-- un destello en el impacto según lo que tocó (escudo, cuerpo, metal o escenario)
	-- y el sonido del arma (tool.Name dice cuál)
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	shotFired:FireAllClients(
		if handle then handle.Position else origin,
		hitPosition,
		result ~= nil,
		surface,
		tool.Name
	)
end

-- Disparo de la ametralladora del jeep: sale del cañón, no de la cabeza
local function onFireTurret(player: Player, direction: any)
	if typeof(direction) ~= "Vector3" or direction ~= direction or direction.Magnitude < 0.01 then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	-- Solo quien está sentado en el asiento de la torreta puede dispararla
	local seat = humanoid.SeatPart
	local vehicle = VehicleService.GetVehicle(seat)
	if not vehicle or not (seat :: BasePart):GetAttribute("Turret") then
		return
	end

	local turret = Vehicles.TurretJeep.turret
	local now = os.clock()
	if now - (lastTurretShot[player] or 0) < FIRE_RATE_TOLERANCE / turret.fireRate then
		return
	end
	lastTurretShot[player] = now

	VehicleService.AimTurret(vehicle, direction)
	local barrel = vehicle:FindFirstChild("TurretBarrel") :: BasePart
	local origin = (barrel.CFrame * CFrame.new(0, 0, -2)).Position -- punta del cañón

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { vehicle, character :: Model }
	local ray = direction.Unit * turret.range
	local result = workspace:Raycast(origin, ray, params)
	local surface = if result then applyHit(player, result, turret.damage, turret.headshotMultiplier) else nil
	shotFired:FireAllClients(
		origin,
		if result then result.Position else origin + ray,
		result ~= nil,
		surface,
		"Turret"
	)
end

local function onReload(player: Player)
	local tool, stats = getEquippedWeapon(player)
	if not tool or reloading[player] or tool:GetAttribute("Ammo") == stats.magazine then
		return
	end
	reloading[player] = true
	tool:SetAttribute("Reloading", true)
	task.wait(stats.reloadTime)
	tool:SetAttribute("Ammo", stats.magazine)
	tool:SetAttribute("Reloading", nil)
	reloading[player] = nil
end

-- Golpe cuerpo a cuerpo: busca al enemigo más cercano justo delante del jugador.
-- Si lo golpeas por la espalda (él mira hacia el mismo lado que tú), muere de un golpe.
local function onMelee(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 or humanoid.SeatPart then
		return
	end
	local now = os.clock()
	if now - (lastMelee[player] or 0) < Melee.cooldown * FIRE_RATE_TOLERANCE then
		return
	end
	lastMelee[player] = now

	-- Si lleva un arma en la mano, Roblox reproduce la animación de "estocada"
	local tool = (character :: Model):FindFirstChildOfClass("Tool")
	if tool then
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Lunge"
		anim.Parent = tool
	end

	-- Una esfera invisible delante del pecho: ¿qué piezas toca?
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: Model }
	local center = root.Position + root.CFrame.LookVector * (Melee.range / 2)
	local parts = workspace:GetPartBoundsInRadius(center, Melee.range / 2, params)

	local target: Humanoid? = nil
	local targetRoot: BasePart? = nil
	local closest = math.huge
	for _, part in parts do
		local model = part:FindFirstAncestorOfClass("Model")
		local otherHumanoid = model and model:FindFirstChildOfClass("Humanoid")
		local otherRoot = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if otherHumanoid and otherRoot and otherHumanoid.Health > 0 then
			if isEnemy(player, Players:GetPlayerFromCharacter(model)) then
				local distance = (otherRoot.Position - root.Position).Magnitude
				if distance < closest then
					closest = distance
					target = otherHumanoid
					targetRoot = otherRoot
				end
			end
		end
	end
	if not target or not targetRoot then
		return
	end

	local toTarget = (targetRoot.Position - root.Position).Unit
	local backstab = targetRoot.CFrame.LookVector:Dot(toTarget) > 0.5
	local toShield, toHealth =
		HealthService.Damage(target, if backstab then Melee.backstabDamage else Melee.damage, player)
	if toShield + toHealth > 0 then
		local surface = if toHealth > 0 then "flesh" else "shield"
		hitConfirmed:FireClient(
			player,
			if backstab then "head" else "hit",
			toShield + toHealth,
			targetRoot.Position,
			surface
		)
	end
end

function CombatService.Start()
	fireWeapon.OnServerEvent:Connect(onFire)
	fireTurret.OnServerEvent:Connect(onFireTurret)
	reloadWeapon.OnServerEvent:Connect(onReload)
	meleeRemote.OnServerEvent:Connect(onMelee)
	Players.PlayerRemoving:Connect(function(player)
		lastShot[player] = nil
		lastTurretShot[player] = nil
		lastMelee[player] = nil
		reloading[player] = nil
	end)
end

return CombatService
