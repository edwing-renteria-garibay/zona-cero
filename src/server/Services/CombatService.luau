-- Disparos, recarga y golpes cuerpo a cuerpo. El cliente solo avisa "disparé desde aquí hacia allá";
-- el servidor comprueba que el disparo sea posible (arma en la mano, munición,
-- cadencia, origen cerca del jugador) y es el único que hace daño.
-- Así nadie puede hacer trampa enviando disparos imposibles.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Melee = require(ReplicatedStorage.Shared.Config.Melee)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local ExplosionService = require(script.Parent.ExplosionService)
local HealthService = require(script.Parent.HealthService)
local ProjectileService = require(script.Parent.ProjectileService)
local Rules = require(script.Parent.Rules)
local VehicleService = require(script.Parent.VehicleService)

local remotes = ReplicatedStorage.Remotes
local fireWeapon = remotes.FireWeapon :: RemoteEvent
local fireTurret = remotes.FireTurret :: RemoteEvent
local reloadWeapon = remotes.ReloadWeapon :: RemoteEvent
local shotFired = remotes.ShotFired :: RemoteEvent
local hitConfirmed = remotes.HitConfirmed :: RemoteEvent
local meleeRemote = remotes.Melee :: RemoteEvent
local frozenRemote = remotes.Frozen :: RemoteEvent
local knockbackRemote = remotes.Knockback :: RemoteEvent

local MAX_ORIGIN_DISTANCE = 10 -- studs permitidos entre la cabeza y el origen del disparo
local FIRE_RATE_TOLERANCE = 0.8 -- acepta disparos un poco más seguidos por la latencia de la red

local CombatService = {}

local lastShot: { [Player]: number } = {}
local lastTurretShot: { [Player]: number } = {}
local reloading: { [Player]: boolean } = {}
local lastMelee: { [Player]: number } = {}
local burning: {
	[Humanoid]: { ends: number, attacker: Player, stacks: number, lastStack: number },
} = {}
local slowedUntil: { [Humanoid]: number } = {}

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
		if stats.reserve then
			tool:SetAttribute("Reserve", stats.reserve)
		end
	end
	return tool, stats
end

-- Materiales de Roblox que suenan a metal o a madera al recibir un disparo;
-- todo lo demás suena a concreto
local METAL_MATERIALS = {
	[Enum.Material.Metal] = true,
	[Enum.Material.CorrodedMetal] = true,
	[Enum.Material.DiamondPlate] = true,
	[Enum.Material.Foil] = true,
}
local WOOD_MATERIALS = {
	[Enum.Material.Wood] = true,
	[Enum.Material.WoodPlanks] = true,
}

local function materialSurface(material: Enum.Material): string
	if METAL_MATERIALS[material] then
		return "metal"
	elseif WOOD_MATERIALS[material] then
		return "wood"
	end
	return "concrete"
end

-- ¿Puede el tirador dañar a este objetivo? (target es nil para un muñeco de práctica)
local function isEnemy(shooter: Player, target: Player?): boolean
	if target == nil then
		return true
	end
	if target == shooter then
		return false
	end
	-- En Infección: zombis contra sobrevivientes
	local shooterSide, targetSide = shooter:GetAttribute("Side"), target:GetAttribute("Side")
	if shooterSide and targetSide then
		return shooterSide ~= targetSide
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
	headshotMultiplier: number?,
	cause: string
): string
	local model = result.Instance:FindFirstAncestorOfClass("Model")
	if not model then
		return materialSurface(result.Material)
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
		return materialSurface(result.Material)
	end
	local headshot = headshotMultiplier ~= nil and isHeadPart(result.Instance :: BasePart)
	if headshot then
		damage *= headshotMultiplier :: number
		if Rules.current.headshotKills then
			damage = math.max(damage, 1000) -- SWAT: un tiro a la cabeza mata
		end
	end
	local toShield, toHealth = HealthService.Damage(targetHumanoid, damage, attacker, cause, headshot)
	if toShield + toHealth <= 0 then
		return "shield" -- tenía protección de aparición: el escudo lo detiene todo
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

-- De dónde sale el disparo que ven todos: la boca del cañón (Attachment "Muzzle" de
-- Shared/WeaponModels), o la Handle si el arma no tiene
local function muzzleOf(tool: Tool, fallback: Vector3): Vector3
	local muzzle = tool:FindFirstChild("Muzzle", true) :: Attachment?
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	return if muzzle then muzzle.WorldPosition elseif handle then handle.Position else fallback
end

-- Una dirección un poco desviada al azar, hasta degrees grados (para los perdigones)
local function spreadDirection(direction: Vector3, degrees: number): Vector3
	local angle = math.rad(degrees) * math.sqrt(math.random())
	local around = math.random() * 2 * math.pi
	return (CFrame.lookAt(Vector3.zero, direction) * CFrame.Angles(0, 0, around) * CFrame.Angles(angle, 0, 0)).LookVector
end

-- Una bala con caída: va recta hasta dropStart studs y después empieza a bajar, cada vez más
-- (drop dice qué tan rápido). Se revisa en tramos cortos para seguir la curva. Si no toca nada
-- en range studs, se pierde. Devuelve lo que tocó (o nil) y dónde terminó.
local SEGMENT = 25 -- studs por tramo
local function castBullet(origin: Vector3, direction: Vector3, stats, params): (RaycastResult?, Vector3)
	local unit = direction.Unit
	local dropStart = stats.dropStart or math.huge
	local drop = stats.drop or 0
	local function pointAt(distance: number): Vector3
		local beyond = math.max(0, distance - dropStart)
		return origin + unit * distance - Vector3.yAxis * drop * beyond * beyond
	end
	local travelled = 0
	local from = origin
	while travelled < stats.range do
		-- Mientras va recta, un solo raycast hasta donde empieza a caer
		local nextDistance = if travelled < dropStart
			then math.min(dropStart, stats.range)
			else math.min(travelled + SEGMENT, stats.range)
		local to = pointAt(nextDistance)
		local result = workspace:Raycast(from, to - from, params)
		if result then
			return result, result.Position
		end
		from = to
		travelled = nextDistance
	end
	return nil, from
end

-- El jugador dueño de una pieza golpeada (nil si es el escenario o un muñeco)
local function humanoidOf(part: Instance): Humanoid?
	local model = part:FindFirstAncestorOfClass("Model")
	return model and model:FindFirstChildOfClass("Humanoid")
end

-- Quemadura del lanzallamas: daño cada medio segundo mientras dura. Se acumula: mientras más
-- tiempo te alcanza la llama, más fuerte quema (una capa más cada stackEvery segundos, hasta
-- maxStacks), y se alarga con cada llamarada.
local function ignite(humanoid: Humanoid, attacker: Player, burn)
	local now = os.clock()
	local entry = burning[humanoid]
	if entry then
		entry.ends = now + burn.duration
		entry.attacker = attacker
		if now - entry.lastStack >= burn.stackEvery then
			entry.stacks = math.min(entry.stacks + 1, burn.maxStacks)
			entry.lastStack = now
		end
		return
	end
	burning[humanoid] = { ends = now + burn.duration, attacker = attacker, stacks = 1, lastStack = now }
	local root = humanoid.RootPart
	local fire = Instance.new("Fire") -- fuego visible sobre el personaje
	fire.Heat = 6
	fire.Size = 4
	fire.Parent = root
	task.spawn(function()
		while true do
			task.wait(0.5)
			local current = burning[humanoid]
			if not current or humanoid.Health <= 0 or not humanoid.Parent or os.clock() > current.ends then
				break
			end
			fire.Size = 3 + current.stacks -- más capas, más fuego
			HealthService.Damage(
				humanoid,
				burn.damagePerStack * current.stacks * 0.5,
				current.attacker,
				"fire"
			)
		end
		burning[humanoid] = nil
		fire:Destroy()
	end)
end

-- Arma de hielo: el enemigo camina más lento un rato y se ve azul. Solo él oye el sonido.
local function slowDown(humanoid: Humanoid, slow)
	local already = slowedUntil[humanoid] ~= nil
	slowedUntil[humanoid] = os.clock() + slow.duration
	local victim = Players:GetPlayerFromCharacter(humanoid.Parent)
	if victim then
		frozenRemote:FireClient(victim, slow.duration)
	end
	if already then
		return
	end
	local normalSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = normalSpeed * slow.factor
	local frost = Instance.new("Highlight")
	frost.FillColor = Color3.fromRGB(150, 220, 255)
	frost.FillTransparency = 0.5
	frost.OutlineTransparency = 1
	frost.Parent = humanoid.Parent
	task.spawn(function()
		while humanoid.Parent and os.clock() < (slowedUntil[humanoid] or 0) do
			task.wait(0.1)
		end
		slowedUntil[humanoid] = nil
		frost:Destroy()
		if humanoid.Parent and humanoid.Health > 0 then
			humanoid.WalkSpeed = normalSpeed
		end
	end)
end

-- Escopeta: varios perdigones, cada uno con su raycast y su trazadora
local function firePellets(player: Player, tool: Tool, stats, origin: Vector3, direction: Vector3, params)
	local from = muzzleOf(tool, origin)
	for i = 1, stats.pellets do
		local result, endPosition =
			castBullet(origin, spreadDirection(direction, stats.spread), stats, params)
		local surface = if result then applyHit(player, result, stats.damage, nil, tool.Name) else nil
		-- Solo el primer perdigón lleva el sonido del disparo ("ShotgunPellet" no suena)
		shotFired:FireAllClients(
			from,
			endPosition,
			result ~= nil,
			surface,
			if i == 1 then tool.Name else "ShotgunPellet",
			nil,
			player
		)
	end
end

-- Lanzallamas: daña a cada enemigo dentro del cono que no esté detrás de una pared
local function fireFlame(player: Player, tool: Tool, stats, origin: Vector3, direction: Vector3, params)
	local aim = direction.Unit
	local wall = workspace:Raycast(origin, aim * stats.range, params)
	local minDot = math.cos(math.rad(stats.cone))
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if root and humanoid.Health > 0 and isEnemy(player, other) then
			local toTarget = root.Position - origin
			if toTarget.Magnitude <= stats.range and aim:Dot(toTarget.Unit) >= minDot then
				local blocker = workspace:Raycast(origin, toTarget, params)
				if not blocker or blocker.Instance:IsDescendantOf(character :: Model) then
					local toShield, toHealth = HealthService.Damage(humanoid, stats.damage, player, tool.Name)
					if toShield + toHealth > 0 then
						ignite(humanoid, player, stats.burn)
						local surface = if toHealth > 0 then "flesh" else "shield"
						hitConfirmed:FireClient(player, "hit", toShield + toHealth, root.Position, surface)
					end
				end
			end
		end
	end
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	shotFired:FireAllClients(
		muzzleOf(tool, origin),
		if wall then wall.Position else origin + aim * stats.range,
		false,
		nil,
		tool.Name,
		handle, -- el sonido del lanzallamas se repite mientras dispara, pegado al arma
		player
	)
end

-- Cañón de iones: marca el punto al que apunta; ProjectileService hace caer el rayo
local function fireIon(player: Player, tool: Tool, stats, origin: Vector3, direction: Vector3, params)
	local ray = direction.Unit * stats.range
	local result = workspace:Raycast(origin, ray, params)
	local point = if result then result.Position else origin + ray
	shotFired:FireAllClients(muzzleOf(tool, origin), point, false, nil, tool.Name, nil, player)
	ProjectileService.IonStrike(point, player, stats)
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

	-- Armas que no disparan una sola bala
	if stats.kind == "pellets" then
		firePellets(player, tool, stats, origin, direction, params)
		return
	elseif stats.kind == "flame" then
		fireFlame(player, tool, stats, origin, direction, params)
		return
	elseif stats.kind == "ion" then
		fireIon(player, tool, stats, origin, direction, params)
		return
	end

	-- Armas de proyectil (lanzacohetes): en vez de un raycast, sale un cohete que vuela
	if stats.projectile then
		ExplosionService.PlaySoundAt(Sounds.fire[tool.Name], origin)
		ProjectileService.FireRocket(player, origin, direction, stats, filter)
		return
	end

	local result, hitPosition = castBullet(origin, direction, stats, params)

	local surface = if result
		then applyHit(player, result, stats.damage, stats.headshotMultiplier, tool.Name)
		else nil
	-- Arma de hielo: si le dio a un enemigo (a su escudo o a su vida), lo ralentiza
	if stats.slow and result and (surface == "shield" or surface == "flesh") then
		local target = humanoidOf(result.Instance)
		if target then
			slowDown(target, stats.slow)
		end
	end

	-- Todos los jugadores dibujan la trazadora desde el arma hasta el impacto,
	-- un destello en el impacto según lo que tocó (escudo, cuerpo, metal o escenario)
	-- y el sonido del arma (tool.Name dice cuál). Sale de la boca del cañón (el Attachment
	-- "Muzzle" de Shared/WeaponModels); player va al final para que quien disparó la dibuje
	-- desde su arma en primera persona
	shotFired:FireAllClients(
		muzzleOf(tool, origin),
		hitPosition,
		result ~= nil,
		surface,
		tool.Name,
		nil,
		player
	)
end

-- Recarga la torreta de un jeep (ametralladora o lanzacohetes). Mientras tanto no puede disparar.
local function reloadTurret(vehicle: Model)
	local turret = VehicleService.GetWeapon(vehicle)
	if
		vehicle:GetAttribute("TurretReloading")
		or (vehicle:GetAttribute("TurretAmmo") or turret.magazine) >= turret.magazine
	then
		return
	end
	vehicle:SetAttribute("TurretReloading", true)
	task.wait(turret.reloadTime)
	vehicle:SetAttribute("TurretAmmo", turret.magazine)
	vehicle:SetAttribute("TurretReloading", nil)
end

-- Disparo de la torreta del jeep: sale del cañón, no de la cabeza. La ametralladora es un
-- raycast como el rifle; el lanzacohetes lanza un cohete como el de mano
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

	-- Solo dispara hacia el frente (Config/Vehicles, turretArc)
	if not VehicleService.InTurretArc(vehicle, direction) then
		return
	end

	local turret, rockets = VehicleService.GetWeapon(vehicle)
	local now = os.clock()
	if now - (lastTurretShot[player] or 0) < FIRE_RATE_TOLERANCE / turret.fireRate then
		return
	end
	-- La munición es del jeep, no del jugador: si otro se sube, encuentra las balas que quedaron
	local ammo = vehicle:GetAttribute("TurretAmmo") or turret.magazine
	if vehicle:GetAttribute("TurretReloading") or ammo <= 0 then
		return
	end
	lastTurretShot[player] = now
	vehicle:SetAttribute("TurretAmmo", ammo - 1)
	if ammo - 1 <= 0 then
		task.spawn(reloadTurret, vehicle) -- se vació: recarga automática
	end

	VehicleService.AimTurret(vehicle, direction)
	local barrel = vehicle:FindFirstChild("TurretBarrel") :: BasePart
	local origin = (barrel.CFrame * CFrame.new(0, 0, -2)).Position -- punta del cañón

	if rockets then
		ExplosionService.PlaySoundAt(Sounds.fire.RocketLauncher, origin)
		ProjectileService.FireRocket(player, origin, direction, turret, { vehicle, character :: Model })
		return
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { vehicle, character :: Model }
	local ray = direction.Unit * turret.range
	local result = workspace:Raycast(origin, ray, params)
	local surface = if result
		then applyHit(player, result, turret.damage, turret.headshotMultiplier, "Turret")
		else nil
	shotFired:FireAllClients(
		origin,
		if result then result.Position else origin + ray,
		result ~= nil,
		surface,
		"Turret",
		barrel -- el sonido de ráfaga de la torreta se pega al cañón
	)
end

local function onReload(player: Player)
	-- Sentado en la torreta, la R recarga la torreta
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local vehicle = VehicleService.GetVehicle(seat)
	if vehicle and seat and seat:GetAttribute("Turret") then
		reloadTurret(vehicle)
		return
	end

	local tool, stats = getEquippedWeapon(player)
	if not tool or reloading[player] then
		return
	end
	-- Cuántas balas faltan; si el arma tiene repuesto limitado, no más de las que quedan
	local ammo = tool:GetAttribute("Ammo") :: number
	local missing = stats.magazine - ammo
	local reserve = tool:GetAttribute("Reserve") :: number?
	if reserve then
		missing = math.min(missing, reserve)
	end
	if missing <= 0 then
		return
	end
	reloading[player] = true
	tool:SetAttribute("Reloading", true)
	task.wait(stats.reloadTime)
	tool:SetAttribute("Ammo", (tool:GetAttribute("Ammo") :: number) + missing)
	if reserve then
		tool:SetAttribute("Reserve", (tool:GetAttribute("Reserve") :: number) - missing)
	end
	tool:SetAttribute("Reloading", nil)
	reloading[player] = nil
end

-- Los valores del golpe: los del arma de golpe que lleva en la mano (Config/Melee.weapons)
-- o, si no lleva ninguna, los del golpe normal
local function meleeStats(character: Model)
	local tool = character:FindFirstChildOfClass("Tool")
	return tool and Melee.weapons[tool.Name] or Melee
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
	local stats = meleeStats(character :: Model)
	local now = os.clock()
	if now - (lastMelee[player] or 0) < stats.cooldown * FIRE_RATE_TOLERANCE then
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

	-- Una esfera invisible alrededor del jugador, del tamaño del alcance: ¿qué piezas toca?
	-- Solo cuenta quien esté más o menos enfrente (Melee.aimCone), así no hace falta
	-- apuntar perfecto para atinar el machetazo
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: Model }
	local parts = workspace:GetPartBoundsInRadius(root.Position, stats.range, params)
	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit

	local target: Humanoid? = nil
	local targetRoot: BasePart? = nil
	local closest = math.huge
	for _, part in parts do
		local model = part:FindFirstAncestorOfClass("Model")
		local otherHumanoid = model and model:FindFirstChildOfClass("Humanoid")
		local otherRoot = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if otherHumanoid and otherRoot and otherHumanoid.Health > 0 then
			local offset = otherRoot.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local inFront = flat.Magnitude < 1 or flat.Unit:Dot(forward) >= Melee.aimCone
			if inFront and isEnemy(player, Players:GetPlayerFromCharacter(model)) then
				local distance = offset.Magnitude
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
	local damage = if backstab then stats.backstabDamage else stats.damage
	local cause = if backstab
		then "Backstab"
		elseif tool and Melee.weapons[tool.Name] then tool.Name
		else "Machete" -- el golpe normal es con el machete del cinto
	if player:GetAttribute("Side") == "Zombie" then
		damage = Rules.current.zombieMeleeDamage or damage -- el machete de un zombi mata
		cause = "Machete"
	end
	local toShield, toHealth = HealthService.Damage(target, damage, player, cause)
	if toShield + toHealth > 0 then
		local surface = if toHealth > 0 then "flesh" else "shield"
		hitConfirmed:FireClient(
			player,
			if backstab then "head" else "hit",
			toShield + toHealth,
			targetRoot.Position,
			surface
		)
		ExplosionService.PlaySoundAt(stats.sound and Sounds.melee[stats.sound], targetRoot.Position)
		-- El personaje lo mueve su propio jugador, así que el empujón lo aplica su cliente
		local victim = Players:GetPlayerFromCharacter(target.Parent)
		if stats.knockback and stats.knockback > 0 and victim and target.Health > 0 then
			local push = Vector3.new(toTarget.X, 0, toTarget.Z).Unit * stats.knockback
			knockbackRemote:FireClient(victim, push + Vector3.yAxis * stats.knockback * 0.5)
		end
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
