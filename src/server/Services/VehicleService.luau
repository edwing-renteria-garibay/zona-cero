-- Jeeps con torreta: los construye, los mueve según lo que pulsa el conductor,
-- les quita vida, los hace explotar y los vuelve a aparecer.
--
-- Conducción "arcade": en lugar de simular motor y ruedas, dos restricciones de física
-- empujan el chasis. LinearVelocity lo lleva hacia delante o atrás sin derrapar y
-- AngularVelocity lo hace girar y lo mantiene derecho para que no vuelque.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local ExplosionService = require(script.Parent.ExplosionService)
local HealthService = require(script.Parent.HealthService)

local stats = Vehicles.TurretJeep

-- Dónde aparecen los jeeps si el mapa no tiene una carpeta Workspace.VehicleSpawns
local DEFAULT_SPAWNS = {
	CFrame.new(25, 3, 0),
	CFrame.new(-25, 3, 0),
}

local OLIVE = Color3.fromRGB(85, 92, 60)
local DARK = Color3.fromRGB(35, 35, 35)

local VehicleService = {}

local jeeps: { [Model]: boolean } = {}

-- Crea una pieza soldada al chasis. offset es su posición relativa al chasis
local function addPart(model: Model, chassis: BasePart, props: { [string]: any }, offset: CFrame): BasePart
	local part = Instance.new(props.ClassName or "Part") :: BasePart
	props.ClassName = nil
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Massless = true -- solo el chasis pesa; así el manejo es predecible
	part.CFrame = chassis.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = chassis
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

local function buildJeep(spawnCFrame: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "TurretJeep"
	model:SetAttribute("Vehicle", "TurretJeep")
	model:SetAttribute("Health", stats.health)

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(7, 1.5, 11)
	chassis.Color = OLIVE
	chassis.Material = Enum.Material.Metal
	chassis.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0)
	chassis.CFrame = spawnCFrame
	chassis.RootPriority = 1 -- el chasis manda en la física aunque se suban jugadores
	chassis.Parent = model
	model.PrimaryPart = chassis

	-- Ruedas: cilindros soldados; tocan el suelo un poco por debajo del chasis
	local wheelProps = function()
		return {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, 3, 3),
			Color = DARK,
			Material = Enum.Material.Rubber,
			CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0),
		}
	end
	-- Cada llanta tiene su propia vida; "Front" marca las delanteras (las que dirigen)
	for _, x in { -3.9, 3.9 } do
		for _, z in { -3.8, 3.8 } do
			local wheel = addPart(model, chassis, wheelProps(), CFrame.new(x, -0.8, z))
			wheel.Name = "Wheel"
			wheel:SetAttribute("TireHealth", stats.tireHealth)
			wheel:SetAttribute("Front", z < 0)
		end
	end
	model:SetAttribute("FlatTires", 0)
	model:SetAttribute("FlatFrontTires", 0)

	-- Carrocería: capó delante y barra antivuelco detrás de los asientos
	addPart(
		model,
		chassis,
		{ Size = Vector3.new(6.6, 1.2, 3), Color = OLIVE, Material = Enum.Material.Metal },
		CFrame.new(0, 1.35, -3.8)
	)
	addPart(
		model,
		chassis,
		{ Size = Vector3.new(6.6, 0.4, 0.4), Color = DARK, Material = Enum.Material.Metal },
		CFrame.new(0, 3.5, 1)
	)

	-- Asientos. El frente de un asiento es su lado -Z, igual que el del chasis
	addPart(model, chassis, {
		ClassName = "VehicleSeat",
		Name = "DriverSeat",
		Size = Vector3.new(2, 1, 2),
		Color = DARK,
		MaxSpeed = 0, -- la velocidad la controla este script, no el asiento
	}, CFrame.new(-1.5, 1.25, -0.8))
	addPart(model, chassis, {
		ClassName = "Seat",
		Name = "PassengerSeat",
		Size = Vector3.new(2, 1, 2),
		Color = DARK,
	}, CFrame.new(1.5, 1.25, -0.8))
	local turretSeat = addPart(model, chassis, {
		ClassName = "Seat",
		Name = "TurretSeat",
		Size = Vector3.new(2, 1, 2),
		Color = DARK,
	}, CFrame.new(0, 1.75, 3.6))
	turretSeat:SetAttribute("Turret", true)

	-- Torreta: una base fija y un cañón que gira (Weld con C0 que cambiamos al apuntar)
	-- Va delante de la cabeza del artillero, por encima de la barra antivuelco
	local mount = addPart(model, chassis, {
		Name = "TurretMount",
		Size = Vector3.new(1.2, 1.2, 1.2),
		Color = DARK,
		Material = Enum.Material.Metal,
		CanCollide = false,
	}, CFrame.new(0, 4.4, 2.2))
	local barrel = Instance.new("Part")
	barrel.Name = "TurretBarrel"
	barrel.Size = Vector3.new(0.5, 0.5, 4)
	barrel.Color = DARK
	barrel.Material = Enum.Material.Metal
	barrel.Massless = true
	barrel.CanCollide = false
	barrel.CFrame = mount.CFrame * CFrame.new(0, 0, -2)
	local turretWeld = Instance.new("Weld")
	turretWeld.Name = "TurretWeld"
	turretWeld.Part0 = mount
	turretWeld.Part1 = barrel
	turretWeld.C0 = CFrame.new(0, 0, -2)
	turretWeld.Parent = barrel
	barrel.Parent = model

	-- Motor: restricciones que el servidor ajusta en cada fotograma
	local attachment = Instance.new("Attachment")
	attachment.Parent = chassis

	-- La velocidad se calcula en coordenadas del mundo en cada fotograma (updateJeep).
	-- PerAxis con fuerza 0 en Y deja libre la vertical para que la gravedad funcione.
	local drive = Instance.new("LinearVelocity")
	drive.Name = "Drive"
	drive.Attachment0 = attachment
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	drive.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	drive.MaxAxesForce = Vector3.new(1e6, 0, 1e6)
	drive.VectorVelocity = Vector3.zero
	drive.Parent = chassis

	local steering = Instance.new("AngularVelocity")
	steering.Name = "Steering"
	steering.Attachment0 = attachment
	steering.RelativeTo = Enum.ActuatorRelativeTo.World
	steering.MaxTorque = 1e7
	steering.AngularVelocity = Vector3.zero
	steering.Parent = chassis

	-- Barra de vida sobre el jeep, visible para todos los jugadores cercanos
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBar"
	billboard.Size = UDim2.fromOffset(120, 10)
	billboard.StudsOffset = Vector3.new(0, 7, 0)
	billboard.MaxDistance = 150
	billboard.Adornee = chassis
	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	background.BorderSizePixel = 0
	background.Parent = billboard
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 200, 90)
	fill.BorderSizePixel = 0
	fill.Parent = background
	billboard.Parent = chassis

	model.Parent = workspace
	-- El servidor maneja la física del jeep, aunque haya jugadores cerca
	chassis:SetNetworkOwner(nil)

	return model
end

-- Los jugadores sentados en el jeep
function VehicleService.GetOccupants(model: Model): { Player }
	local occupants = {}
	for _, seat in model:GetChildren() do
		if seat:IsA("Seat") or seat:IsA("VehicleSeat") then
			local humanoid = (seat :: any).Occupant :: Humanoid?
			local player = humanoid and Players:GetPlayerFromCharacter(humanoid.Parent)
			if player then
				table.insert(occupants, player)
			end
		end
	end
	return occupants
end

-- Si alguien del equipo del atacante (o él mismo) va dentro, no se puede dañar
local function canDamage(model: Model, attacker: Player?): boolean
	if not attacker then
		return true
	end
	for _, occupant in VehicleService.GetOccupants(model) do
		if occupant == attacker then
			return false
		end
		if not attacker.Neutral and not occupant.Neutral and occupant.Team == attacker.Team then
			return false
		end
	end
	return true
end

-- La explosión del jeep, en el formato de ExplosionService
local jeepBlast: ExplosionService.Blast = {
	damage = stats.blastDamage,
	innerRadius = stats.blastInnerRadius,
	radius = stats.blastRadius,
}

local function explode(model: Model, attacker: Player?)
	local chassis = model.PrimaryPart :: BasePart
	-- Quien vaya dentro muere, y la baja es para quien destruyó el jeep
	for _, occupant in VehicleService.GetOccupants(model) do
		local humanoid = occupant.Character and occupant.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			HealthService.Damage(humanoid, 1000, attacker)
		end
	end
	local center = chassis.Position
	local spawnCFrame = model:GetAttribute("SpawnCFrame") :: CFrame
	jeeps[model] = nil
	model:Destroy()

	-- Daño a quien esté cerca, y a otros jeeps (puede haber explosiones en cadena)
	ExplosionService.Blast(center, attacker, jeepBlast)
	VehicleService.BlastVehicles(center, attacker, jeepBlast)
	task.delay(stats.respawnTime, function()
		VehicleService.Spawn(spawnCFrame)
	end)
end

local function updateHealthBar(model: Model, health: number)
	local chassis = model.PrimaryPart :: BasePart
	local billboard = chassis:FindFirstChild("HealthBar")
	local fill = billboard and billboard:FindFirstChild("Fill", true) :: Frame?
	if fill then
		local ratio = math.clamp(health / stats.health, 0, 1)
		fill.Size = UDim2.fromScale(ratio, 1)
		-- Verde con mucha vida, rojo con poca
		fill.BackgroundColor3 = Color3.fromRGB(90, 200, 90):Lerp(Color3.fromRGB(220, 60, 50), 1 - ratio)
	end
end

-- Una llanta recibe daño; al llegar a 0 se poncha: se ve aplastada y el jeep va más lento
local function damageTire(model: Model, wheel: BasePart, amount: number)
	local tireHealth = wheel:GetAttribute("TireHealth") :: number?
	if not tireHealth or tireHealth <= 0 then
		return
	end
	tireHealth -= amount
	wheel:SetAttribute("TireHealth", math.max(tireHealth, 0))
	if tireHealth > 0 then
		return
	end
	wheel.Size = Vector3.new(1.2, 2.3, 2.3)
	wheel.Color = Color3.fromRGB(70, 70, 70)
	model:SetAttribute("FlatTires", (model:GetAttribute("FlatTires") :: number) + 1)
	if wheel:GetAttribute("Front") then
		model:SetAttribute("FlatFrontTires", (model:GetAttribute("FlatFrontTires") :: number) + 1)
	end
end

-- hitPart es la pieza del jeep que recibió el disparo (para saber si fue una llanta).
-- Devuelve true si el daño se aplicó (false si el jeep es de tu equipo)
function VehicleService.Damage(model: Model, amount: number, attacker: Player?, hitPart: BasePart?): boolean
	if not jeeps[model] or not canDamage(model, attacker) then
		return false
	end
	if hitPart and hitPart.Name == "Wheel" then
		damageTire(model, hitPart, amount)
		amount *= stats.tireHitShare
	end
	local health = (model:GetAttribute("Health") :: number) - amount
	model:SetAttribute("Health", math.max(health, 0))
	updateHealthBar(model, health)
	if health <= 0 then
		explode(model, attacker)
	end
	return true
end

-- Daña a los jeeps cerca de una explosión (de un jeep, un cohete o una granada)
function VehicleService.BlastVehicles(center: Vector3, attacker: Player?, blast: ExplosionService.Blast)
	for model in jeeps do
		local chassis = model.PrimaryPart
		if chassis then
			local distance = (chassis.Position - center).Magnitude
			if distance < blast.radius then
				VehicleService.Damage(
					model,
					ExplosionService.DamageAt(blast, distance, blast.vehicleDamage),
					attacker
				)
			end
		end
	end
end

-- El jeep al que pertenece un asiento (o una pieza), si es un jeep vivo
function VehicleService.GetVehicle(part: Instance?): Model?
	local model = part and part.Parent
	if model and model:IsA("Model") and jeeps[model] then
		return model
	end
	return nil
end

-- Mueve el cañón para que apunte (solo de lado a lado) en la dirección dada
function VehicleService.AimTurret(model: Model, direction: Vector3)
	local mount = model:FindFirstChild("TurretMount") :: BasePart?
	local barrel = model:FindFirstChild("TurretBarrel")
	local weld = barrel and barrel:FindFirstChild("TurretWeld") :: Weld?
	if not mount or not weld then
		return
	end
	local localDirection = mount.CFrame:VectorToObjectSpace(direction)
	local yaw = math.atan2(-localDirection.X, -localDirection.Z)
	weld.C0 = CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -2)
end

function VehicleService.Spawn(spawnCFrame: CFrame): Model
	local model = buildJeep(spawnCFrame)
	model:SetAttribute("SpawnCFrame", spawnCFrame)
	jeeps[model] = true
	return model
end

-- Cada fotograma: leer el asiento del conductor y ajustar el motor
local function updateJeep(model: Model)
	local chassis = model.PrimaryPart :: BasePart
	local seat = model:FindFirstChild("DriverSeat") :: VehicleSeat
	local drive = chassis:FindFirstChild("Drive") :: LinearVelocity
	local steering = chassis:FindFirstChild("Steering") :: AngularVelocity

	local throttle = seat.ThrottleFloat -- W = 1, S = -1
	local steer = seat.SteerFloat -- D = 1, A = -1
	-- Las llantas ponchadas restan velocidad y giro (nunca por debajo de 0)
	local flats = model:GetAttribute("FlatTires") :: number
	local flatFronts = model:GetAttribute("FlatFrontTires") :: number
	local speedScale = math.max(1 - flats * stats.flatSpeedPenalty, 0)
	local turnScale = math.max(1 - flatFronts * stats.flatTurnPenalty, 0)

	local forward = if throttle >= 0 then throttle * stats.maxSpeed else throttle * stats.reverseSpeed
	forward *= speedScale
	-- Hacia delante del chasis, pero sin componente vertical; la velocidad lateral
	-- queda en 0, así que el jeep no derrapa
	local look = chassis.CFrame.LookVector
	local flatForward = Vector3.new(look.X, 0, look.Z)
	if flatForward.Magnitude > 0.01 then
		drive.VectorVelocity = flatForward.Unit * forward
	end

	-- Como un coche: gira más cuanto más rápido va, y al revés en marcha atrás
	local speed = chassis.AssemblyLinearVelocity:Dot(chassis.CFrame.LookVector)
	local turnFactor = math.clamp(math.abs(speed) / 12, 0, 1) * math.sign(speed)
	steering.AngularVelocity = Vector3.new(0, -steer * stats.turnRate * turnScale * turnFactor, 0)
end

function VehicleService.Start()
	local spawnFolder = workspace:FindFirstChild("VehicleSpawns")
	if spawnFolder then
		for _, spawnPart in spawnFolder:GetChildren() do
			if spawnPart:IsA("BasePart") then
				spawnPart.Transparency = 1
				spawnPart.CanCollide = false
				VehicleService.Spawn(spawnPart.CFrame + Vector3.new(0, 3, 0))
			end
		end
	else
		for _, spawnCFrame in DEFAULT_SPAWNS do
			VehicleService.Spawn(spawnCFrame)
		end
	end

	RunService.Heartbeat:Connect(function()
		for model in jeeps do
			if model.PrimaryPart then
				updateJeep(model)
			end
		end
	end)
end

return VehicleService
