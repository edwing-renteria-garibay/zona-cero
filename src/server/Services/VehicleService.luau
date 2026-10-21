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
	for _, x in { -3.9, 3.9 } do
		for _, z in { -3.8, 3.8 } do
			addPart(model, chassis, wheelProps(), CFrame.new(x, -0.8, z))
		end
	end

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

	-- Dos líneas: una controla la velocidad hacia delante y la otra deja la lateral
	-- en 0 para que no derrape. La vertical queda libre para que la gravedad funcione.
	local function lineMotor(name: string, direction: Vector3): LinearVelocity
		local motor = Instance.new("LinearVelocity")
		motor.Name = name
		motor.Attachment0 = attachment
		motor.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		motor.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
		motor.LineDirection = direction
		motor.LineVelocity = 0
		motor.MaxForce = 1e6
		motor.Parent = chassis
		return motor
	end
	lineMotor("Drive", Vector3.new(0, 0, -1)) -- hacia delante del chasis
	lineMotor("Grip", Vector3.new(1, 0, 0)) -- hacia la derecha

	local steering = Instance.new("AngularVelocity")
	steering.Name = "Steering"
	steering.Attachment0 = attachment
	steering.RelativeTo = Enum.ActuatorRelativeTo.World
	steering.MaxTorque = 1e7
	steering.AngularVelocity = Vector3.zero
	steering.Parent = chassis

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

local function explode(model: Model, attacker: Player?)
	local chassis = model.PrimaryPart :: BasePart
	-- Quien vaya dentro muere, y la baja es para quien destruyó el jeep
	for _, occupant in VehicleService.GetOccupants(model) do
		local humanoid = occupant.Character and occupant.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			HealthService.Damage(humanoid, 1000, attacker)
		end
	end
	-- Explosión solo visual: no rompe nada ni empuja (el daño ya se aplicó arriba)
	local explosion = Instance.new("Explosion")
	explosion.Position = chassis.Position
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Parent = workspace

	local spawnCFrame = model:GetAttribute("SpawnCFrame") :: CFrame
	jeeps[model] = nil
	model:Destroy()
	task.delay(stats.respawnTime, function()
		VehicleService.Spawn(spawnCFrame)
	end)
end

function VehicleService.Damage(model: Model, amount: number, attacker: Player?)
	if not jeeps[model] or not canDamage(model, attacker) then
		return
	end
	local health = (model:GetAttribute("Health") :: number) - amount
	model:SetAttribute("Health", math.max(health, 0))
	if health <= 0 then
		explode(model, attacker)
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
	local forward = if throttle >= 0 then throttle * stats.maxSpeed else throttle * stats.reverseSpeed
	drive.LineVelocity = forward

	-- Como un coche: gira más cuanto más rápido va, y al revés en marcha atrás
	local speed = chassis.AssemblyLinearVelocity:Dot(chassis.CFrame.LookVector)
	local turnFactor = math.clamp(math.abs(speed) / 12, 0, 1) * math.sign(speed)
	steering.AngularVelocity = Vector3.new(0, -steer * stats.turnRate * turnFactor, 0)
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
