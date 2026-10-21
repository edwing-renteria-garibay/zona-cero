-- Disparos y recarga. El cliente solo avisa "disparé desde aquí hacia allá";
-- el servidor comprueba que el disparo sea posible (arma en la mano, munición,
-- cadencia, origen cerca del jugador) y es el único que hace daño.
-- Así nadie puede hacer trampa enviando disparos imposibles.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local HealthService = require(script.Parent.HealthService)
local VehicleService = require(script.Parent.VehicleService)

local remotes = ReplicatedStorage.Remotes
local fireWeapon = remotes.FireWeapon :: RemoteEvent
local fireTurret = remotes.FireTurret :: RemoteEvent
local reloadWeapon = remotes.ReloadWeapon :: RemoteEvent
local shotFired = remotes.ShotFired :: RemoteEvent

local MAX_ORIGIN_DISTANCE = 10 -- studs permitidos entre la cabeza y el origen del disparo
local FIRE_RATE_TOLERANCE = 0.8 -- acepta disparos un poco más seguidos por la latencia de la red

local CombatService = {}

local lastShot: { [Player]: number } = {}
local lastTurretShot: { [Player]: number } = {}
local reloading: { [Player]: boolean } = {}

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

-- Aplica el daño de un impacto: a un jeep, o a un personaje enemigo
local function applyHit(attacker: Player, result: RaycastResult, damage: number, headshotMultiplier: number?)
	local model = result.Instance:FindFirstAncestorOfClass("Model")
	if not model then
		return
	end
	local vehicle = VehicleService.GetVehicle(result.Instance)
	if vehicle then
		VehicleService.Damage(vehicle, damage, attacker, result.Instance :: BasePart)
		return
	end
	local targetHumanoid = model:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid or not isEnemy(attacker, Players:GetPlayerFromCharacter(model)) then
		return
	end
	if result.Instance.Name == "Head" and headshotMultiplier then
		damage *= headshotMultiplier
	end
	HealthService.Damage(targetHumanoid, damage, attacker)
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

	-- Todos los jugadores dibujan la trazadora desde el arma hasta el impacto
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	shotFired:FireAllClients(if handle then handle.Position else origin, hitPosition)

	if result then
		applyHit(player, result, stats.damage, stats.headshotMultiplier)
	end
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
	shotFired:FireAllClients(origin, if result then result.Position else origin + ray)
	if result then
		applyHit(player, result, turret.damage)
	end
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

function CombatService.Start()
	fireWeapon.OnServerEvent:Connect(onFire)
	fireTurret.OnServerEvent:Connect(onFireTurret)
	reloadWeapon.OnServerEvent:Connect(onReload)
	Players.PlayerRemoving:Connect(function(player)
		lastShot[player] = nil
		lastTurretShot[player] = nil
		reloading[player] = nil
	end)
end

return CombatService
