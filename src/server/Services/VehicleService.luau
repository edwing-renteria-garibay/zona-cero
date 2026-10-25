-- Jeeps (con ametralladora o con lanzacohetes): los construye, los mueve según lo que pulsa el conductor,
-- les quita vida, los hace explotar y los vuelve a aparecer.
--
-- Conducción "arcade": en lugar de simular motor y ruedas, dos restricciones de física
-- empujan el chasis. LinearVelocity lo lleva hacia delante o atrás sin derrapar y
-- AngularVelocity lo hace girar y lo mantiene derecho para que no vuelque.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Combatants = require(script.Parent.Combatants)
local ExplosionService = require(script.Parent.ExplosionService)
local HealthService = require(script.Parent.HealthService)

local knockbackRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Knockback") :: RemoteEvent

-- Dónde aparece un jeep y de qué tipo es ("TurretJeep" o "RocketJeep", ver Config/Vehicles)
type SpawnPoint = { cframe: CFrame, kind: string }

-- Dónde aparecen los jeeps si el mapa no tiene una carpeta Workspace.VehicleSpawns
local DEFAULT_SPAWNS: { SpawnPoint } = {
	{ cframe = CFrame.new(25, 3, 0), kind = "TurretJeep" },
	{ cframe = CFrame.new(-25, 3, 0), kind = "TurretJeep" },
}

local OLIVE = Color3.fromRGB(85, 92, 60)
local OLIVE_DARK = Color3.fromRGB(64, 70, 46)
local DARK = Color3.fromRGB(35, 35, 35)
local STEEL = Color3.fromRGB(120, 124, 128)

local VehicleService = {}

local jeeps: { [Model]: boolean } = {}
local spawnPoints: { SpawnPoint } = {} -- dónde aparece cada jeep
local vehiclesEnabled = true
local spawnGeneration = 0 -- cambia cada vez que se apagan o prenden los jeeps
local lastRunOver: { [Humanoid]: number } = setmetatable({}, { __mode = "k" }) :: any -- cuándo atropellaron a cada quien por última vez

-- Los datos (Config/Vehicles) del tipo de jeep que es model
local function statsOf(model: Model): { [string]: any }
	return Vehicles[model:GetAttribute("Vehicle") :: string] or Vehicles.TurretJeep
end

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

-- Una pieza de adorno: no choca con nada (solo el chasis y las llantas chocan), así la
-- forma del jeep no cambia cómo se maneja. Las balas sí le pegan y dañan al jeep.
local function addDetail(model: Model, chassis: BasePart, props: { [string]: any }, offset: CFrame): BasePart
	props.Material = props.Material or Enum.Material.Metal
	local part = addPart(model, chassis, props, offset)
	part.CanCollide = false
	part.CanTouch = false
	return part
end

-- La carrocería: capó, defensas, guardafangos, parabrisas, jaula antivuelco y luces.
-- El frente del jeep es su lado -Z
local function buildBody(model: Model, chassis: BasePart)
	local function box(size: Vector3, color: Color3, offset: CFrame, extra: { [string]: any }?): BasePart
		local props: { [string]: any } = { Size = size, Color = color }
		if extra then
			for key, value in extra do
				props[key] = value
			end
		end
		return addDetail(model, chassis, props, offset)
	end
	local plate = { Material = Enum.Material.DiamondPlate }

	-- Capó, con una cresta al centro, y la parrilla al frente
	box(Vector3.new(6.6, 1.2, 3), OLIVE, CFrame.new(0, 1.35, -3.8))
	box(Vector3.new(2, 0.3, 3), OLIVE_DARK, CFrame.new(0, 2.05, -3.8))
	box(Vector3.new(6, 1.6, 0.3), DARK, CFrame.new(0, 0.95, -5.45), plate)
	-- Faros y calaveras
	for _, x in { -2.3, 2.3 } do
		box(Vector3.new(1, 0.6, 0.2), Color3.fromRGB(255, 244, 214), CFrame.new(x, 1.35, -5.65), {
			Material = Enum.Material.Neon,
		})
	end
	for _, x in { -3, 3 } do
		box(Vector3.new(0.8, 0.5, 0.2), Color3.fromRGB(200, 30, 30), CFrame.new(x, 1.1, 5.65), {
			Material = Enum.Material.Neon,
		})
	end
	-- Defensas gruesas: la de enfrente con tubo de empuje
	box(Vector3.new(7.6, 0.9, 0.9), DARK, CFrame.new(0, -0.2, -6), plate)
	box(Vector3.new(7.6, 0.9, 0.9), DARK, CFrame.new(0, -0.2, 6), plate)
	for _, x in { -1.8, 1.8 } do
		box(Vector3.new(0.4, 2, 0.4), DARK, CFrame.new(x, 0.9, -6.2))
	end
	box(Vector3.new(4, 0.4, 0.4), DARK, CFrame.new(0, 1.9, -6.2))
	-- Costados, panel de atrás y guardafangos sobre cada llanta
	for _, x in { -3.55, 3.55 } do
		box(Vector3.new(0.3, 1.2, 6), OLIVE, CFrame.new(x, 1.35, 1.5))
		for _, z in { -3.8, 3.8 } do
			box(Vector3.new(2.2, 0.5, 4.2), OLIVE_DARK, CFrame.new(x * 1.1, 1.25, z))
		end
	end
	box(Vector3.new(7, 1.4, 0.3), OLIVE, CFrame.new(0, 1.45, 5.45))
	-- Llanta de refacción atrás
	addDetail(model, chassis, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 2.8, 2.8),
		Color = DARK,
		Material = Enum.Material.Rubber,
	}, CFrame.new(0, 1.8, 6.25) * CFrame.Angles(0, math.pi / 2, 0))
	-- Parabrisas: marco y vidrio (los rayos lo atraviesan para que no estorbe al apuntar)
	for _, x in { -3.1, 3.1 } do
		box(Vector3.new(0.3, 2.2, 0.3), DARK, CFrame.new(x, 2.85, -2.2))
	end
	box(Vector3.new(6.5, 0.3, 0.3), DARK, CFrame.new(0, 3.95, -2.2))
	local glass = box(Vector3.new(5.9, 1.9, 0.15), Color3.fromRGB(150, 180, 190), CFrame.new(0, 2.8, -2.2), {
		Material = Enum.Material.Glass,
		Transparency = 0.6,
	})
	glass.CanQuery = false
	-- Jaula antivuelco detrás de los asientos: dos postes y la barra de arriba
	for _, x in { -3.1, 3.1 } do
		box(Vector3.new(0.4, 2.75, 0.4), DARK, CFrame.new(x, 2.1, 1))
	end
	box(Vector3.new(6.6, 0.4, 0.4), DARK, CFrame.new(0, 3.5, 1))
end

-- El motor: un sonido que se repite mientras hay conductor (updateJeep ajusta qué tan
-- fuerte y agudo suena), y el arranque cuando se sube el conductor
local function addSounds(model: Model, chassis: BasePart)
	local engine = Instance.new("Sound")
	engine.Name = "Engine"
	engine.SoundId = Sounds.vehicle.engine
	engine.Looped = true
	engine.Volume = 0
	engine.RollOffMaxDistance = 250
	engine.Parent = chassis
	local start = Instance.new("Sound")
	start.Name = "Start"
	start.SoundId = Sounds.vehicle.start
	start.RollOffMaxDistance = 200
	start.Parent = chassis

	local seat = model:FindFirstChild("DriverSeat") :: VehicleSeat
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if seat.Occupant then
			start:Play()
			engine:Play()
		else
			engine:Stop()
		end
	end)
end

-- Los zombis (Infección) no manejan ni se suben: si uno se sienta, lo bajan en seguida.
-- El asiento se apaga un momento para que no se vuelva a sentar al seguir tocándolo
local function keepZombiesOut(model: Model)
	for _, seat in model:GetChildren() do
		if not seat:IsA("Seat") and not seat:IsA("VehicleSeat") then
			continue
		end
		local anySeat = seat :: any
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			local humanoid = anySeat.Occupant :: Humanoid?
			local who = humanoid and Combatants.FromCharacter(humanoid.Parent)
			if not humanoid or not who or who:GetAttribute("Side") ~= "Zombie" then
				return
			end
			local weld = seat:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
			humanoid.Sit = false
			humanoid.Jump = true
			anySeat.Disabled = true
			task.delay(1.5, function()
				anySeat.Disabled = false
			end)
		end)
	end
end

-- Lo que gira arriba del jeep: el cañón de la ametralladora o la caja del lanzacohetes.
-- Se llama "TurretBarrel" en los dos, y su punta (donde salen balas o cohetes) está
-- 2 studs delante de su centro
local function buildWeapon(kind: string, mount: BasePart): BasePart
	local barrel = Instance.new("Part")
	barrel.Name = "TurretBarrel"
	barrel.Color = DARK
	barrel.Material = Enum.Material.Metal
	barrel.Massless = true
	barrel.CanCollide = false
	barrel.CFrame = mount.CFrame * CFrame.new(0, 0, -2)
	if kind == "RocketJeep" then
		-- Caja de 6 tubos (3 × 2), con una franja amarilla a los lados para reconocerla de lejos
		barrel.Size = Vector3.new(2.6, 1.6, 4)
		barrel.Color = OLIVE_DARK
		local function attach(props: { [string]: any }, offset: CFrame)
			local part = Instance.new("Part")
			for key, value in props do
				(part :: any)[key] = value
			end
			part.Massless = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false -- las balas pegan en la caja, no en estos adornos
			part.CFrame = barrel.CFrame * offset
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = barrel
			weld.Part1 = part
			weld.Parent = part
			part.Parent = barrel
		end
		for _, x in { -0.8, 0, 0.8 } do
			for _, y in { -0.38, 0.38 } do
				attach({
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(0.3, 0.6, 0.6),
					Color = Color3.fromRGB(20, 20, 20),
					Material = Enum.Material.Metal,
				}, CFrame.new(x, y, -2.05) * CFrame.Angles(0, math.pi / 2, 0))
			end
		end
		for _, x in { -1.32, 1.32 } do
			attach({
				Size = Vector3.new(0.1, 0.4, 3.6),
				Color = Color3.fromRGB(230, 180, 40),
				Material = Enum.Material.SmoothPlastic,
			}, CFrame.new(x, 0, 0))
		end
	else
		barrel.Size = Vector3.new(0.5, 0.5, 4)
	end
	return barrel
end

local function buildJeep(spawnCFrame: CFrame, kind: string): Model
	local stats = Vehicles[kind]
	local model = Instance.new("Model")
	model.Name = kind
	model:SetAttribute("Vehicle", kind)
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
			Size = Vector3.new(1.4, 3.4, 3.4),
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
			-- Rin de metal, un poco más ancho que la llanta para que se vea de los dos lados
			addDetail(model, chassis, {
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.5, 1.5, 1.5),
				Color = STEEL,
				Material = Enum.Material.DiamondPlate,
			}, CFrame.new(x, -0.8, z))
		end
	end
	model:SetAttribute("FlatTires", 0)
	model:SetAttribute("FlatFrontTires", 0)

	buildBody(model, chassis)

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

	-- Torreta: una base fija y un arma que gira (Weld con C0 que cambiamos al apuntar)
	-- Va delante de la cabeza del artillero, por encima de la barra antivuelco
	local mount = addPart(model, chassis, {
		Name = "TurretMount",
		Size = Vector3.new(1.2, 1.2, 1.2),
		Color = DARK,
		Material = Enum.Material.Metal,
		CanCollide = false,
	}, CFrame.new(0, 4.4, 2.2))
	local barrel = buildWeapon(kind, mount)
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

	addSounds(model, chassis)
	keepZombiesOut(model)

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
local function jeepBlast(stats): ExplosionService.Blast
	return {
		damage = stats.blastDamage,
		innerRadius = stats.blastInnerRadius,
		radius = stats.blastRadius,
		sound = "jeep",
	}
end

local function explode(model: Model, attacker: Player?)
	local chassis = model.PrimaryPart :: BasePart
	-- Quien vaya dentro muere, y la baja es para quien destruyó el jeep
	for _, occupant in VehicleService.GetOccupants(model) do
		local humanoid = occupant.Character and occupant.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			HealthService.Damage(humanoid, 1000, attacker, "jeep")
		end
	end
	local center = chassis.Position
	local stats = statsOf(model)
	local spawnPoint = {
		cframe = model:GetAttribute("SpawnCFrame") :: CFrame,
		kind = model:GetAttribute("Vehicle") :: string,
	}
	jeeps[model] = nil
	model:Destroy()

	-- Daño a quien esté cerca, y a otros jeeps (puede haber explosiones en cadena)
	local blast = jeepBlast(stats)
	ExplosionService.Blast(center, attacker, blast)
	VehicleService.BlastVehicles(center, attacker, blast)
	local generation = spawnGeneration
	task.delay(stats.respawnTime, function()
		-- Si mientras tanto se apagaron o reiniciaron los jeeps, este ya no vuelve
		if generation == spawnGeneration then
			VehicleService.Spawn(spawnPoint)
		end
	end)
end

local function updateHealthBar(model: Model, health: number)
	local chassis = model.PrimaryPart :: BasePart
	local billboard = chassis:FindFirstChild("HealthBar")
	local fill = billboard and billboard:FindFirstChild("Fill", true) :: Frame?
	if fill then
		local ratio = math.clamp(health / statsOf(model).health, 0, 1)
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
	wheel.Size = Vector3.new(1.4, 2.6, 2.6)
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
		amount *= statsOf(model).tireHitShare
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

-- El arma del jeep: (los datos de su ametralladora o de su lanzacohetes, y si es de cohetes)
function VehicleService.GetWeapon(model: Model): ({ [string]: any }, boolean)
	local stats = statsOf(model)
	return stats.rockets or stats.turret, stats.rockets ~= nil
end

-- Cuánto gira la torreta (en radianes) para apuntar en la dirección dada: 0 es de frente,
-- positivo a la izquierda y negativo a la derecha
local function turretYaw(model: Model, direction: Vector3): number?
	local mount = model:FindFirstChild("TurretMount") :: BasePart?
	if not mount then
		return nil
	end
	local localDirection = mount.CFrame:VectorToObjectSpace(direction)
	return math.atan2(-localDirection.X, -localDirection.Z)
end

-- ¿La dirección queda dentro de lo que la torreta puede cubrir? (turretArc a cada lado del frente)
function VehicleService.InTurretArc(model: Model, direction: Vector3): boolean
	local yaw = turretYaw(model, direction)
	return yaw ~= nil and math.abs(yaw) <= math.rad(statsOf(model).turretArc)
end

-- Mueve el cañón para que apunte (solo de lado a lado) en la dirección dada. Nunca pasa
-- del límite: si apuntas hacia atrás, se queda en el borde
function VehicleService.AimTurret(model: Model, direction: Vector3)
	local barrel = model:FindFirstChild("TurretBarrel")
	local weld = barrel and barrel:FindFirstChild("TurretWeld") :: Weld?
	local yaw = turretYaw(model, direction)
	if not weld or not yaw then
		return
	end
	local limit = math.rad(statsOf(model).turretArc)
	weld.C0 = CFrame.Angles(0, math.clamp(yaw, -limit, limit), 0) * CFrame.new(0, 0, -2)
end

function VehicleService.Spawn(spawnPoint: SpawnPoint): Model
	local model = buildJeep(spawnPoint.cframe, spawnPoint.kind)
	model:SetAttribute("SpawnCFrame", spawnPoint.cframe)
	jeeps[model] = true
	return model
end

-- ¿Son enemigos? (en los modos sin equipos, todos lo son)
local function areEnemies(a: Player, b: Combatants.Combatant): boolean
	return Combatants.IsEnemy(a, b)
end

-- Atropellar: los enemigos que toca el jeep yendo rápido pierden vida (sin morir) y salen
-- volando hacia donde va el jeep. Se buscan con una caja un poco más grande que el chasis,
-- así se les avienta antes de que el jeep se les suba encima.
local function runOver(model: Model, driver: Player, speed: number)
	local chassis = model.PrimaryPart :: BasePart
	local stats = statsOf(model)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	local area = chassis.CFrame * CFrame.new(0, 1, 0)
	local now = os.clock()
	local hit: { [Humanoid]: boolean } = {}
	for _, part in workspace:GetPartBoundsInBox(area, Vector3.new(8.5, 5, 14), params) do
		local character = part.Parent
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local victim = humanoid and Combatants.FromCharacter(character) -- jugador o bot
		if
			humanoid
			and victim
			and not hit[humanoid]
			and humanoid.Health > 0
			and not humanoid.SeatPart
			and areEnemies(driver, victim)
			and now - (lastRunOver[humanoid] or 0) >= stats.runOver.cooldown
		then
			hit[humanoid] = true
			lastRunOver[humanoid] = now
			-- Con la vida y el escudo llenos, el primer atropello no lo mata (le deja al menos 1);
			-- si ya venía lastimado, sí puede morir
			local shield = (character :: Model):GetAttribute("Shield") or 0
			local maxShield = (character :: Model):GetAttribute("MaxShield") or 0
			local full = shield >= maxShield and humanoid.Health >= humanoid.MaxHealth
			local amount = if full
				then math.min(stats.runOver.damage, shield + humanoid.Health - 1)
				else stats.runOver.damage
			if amount > 0 then
				HealthService.Damage(humanoid, amount, driver, "jeep")
			end
			ExplosionService.PlaySoundAt(Sounds.vehicle.runOver, chassis.Position)
			-- Lo avienta hacia donde va el jeep y hacia un lado (el lado donde ya estaba)
			local forward = chassis.CFrame.LookVector * math.sign(speed)
			local side = chassis.CFrame.RightVector
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and chassis.CFrame:PointToObjectSpace(root.Position).X < 0 then
				side = -side
			end
			local push = Vector3.new(forward.X + side.X, 0, forward.Z + side.Z).Unit * stats.runOver.knockback
			push += Vector3.yAxis * stats.runOver.knockback * 0.5
			if victim:IsA("Player") then
				knockbackRemote:FireClient(victim, push)
			elseif root then
				root.AssemblyLinearVelocity = push -- a un bot lo mueve el servidor
			end
		end
	end
end

-- Cada fotograma: leer el asiento del conductor y ajustar el motor
local function updateJeep(model: Model)
	local chassis = model.PrimaryPart :: BasePart
	local seat = model:FindFirstChild("DriverSeat") :: VehicleSeat
	local drive = chassis:FindFirstChild("Drive") :: LinearVelocity
	local steering = chassis:FindFirstChild("Steering") :: AngularVelocity
	local stats = statsOf(model)

	-- Sin conductor no se acelera ni se gira. El asiento puede quedarse con lo último que
	-- pulsó quien se bajó, y el jeep seguía avanzando solo.
	local hasDriver = seat.Occupant ~= nil
	local throttle = if hasDriver then seat.ThrottleFloat else 0 -- W = 1, S = -1
	local steer = if hasDriver then seat.SteerFloat else 0 -- D = 1, A = -1
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

	-- El motor suena más fuerte y más agudo mientras más rápido vas; parado no suena
	local engine = chassis:FindFirstChild("Engine") :: Sound?
	if engine then
		local pace = math.clamp(math.abs(speed) / stats.maxSpeed, 0, 1)
		engine.Volume = math.clamp(math.abs(speed) / 8, 0, 1) * 0.7
		engine.PlaybackSpeed = 0.85 + 0.4 * pace
	end

	local driverHumanoid = seat.Occupant
	local driver = driverHumanoid and Players:GetPlayerFromCharacter(driverHumanoid.Parent)
	if driver and math.abs(speed) >= stats.runOver.minSpeed then
		runOver(model, driver, speed)
	end
end

-- Hay jeeps o no, según el modo (vehicles = false en Config/Modes). Al apagarlos se quitan
-- todos (quien iba sentado se baja); al prenderlos vuelven a sus lugares.
function VehicleService.SetEnabled(enabled: boolean)
	if enabled == vehiclesEnabled then
		return
	end
	vehiclesEnabled = enabled
	spawnGeneration += 1
	for model in jeeps do
		jeeps[model] = nil
		model:Destroy()
	end
	if enabled then
		for _, spawnPoint in spawnPoints do
			VehicleService.Spawn(spawnPoint)
		end
	end
end

-- Lee dónde aparecen los jeeps (la carpeta VehicleSpawns que llena cada mapa). El atributo
-- Vehicle de cada marca dice qué jeep sale ahí; sin él, sale el de ametralladora
local function loadSpawnPoints()
	spawnPoints = {}
	local spawnFolder = workspace:FindFirstChild("VehicleSpawns")
	if spawnFolder then
		for _, spawnPart in spawnFolder:GetChildren() do
			if spawnPart:IsA("BasePart") then
				spawnPart.Transparency = 1
				spawnPart.CanCollide = false
				local kind = spawnPart:GetAttribute("Vehicle")
				table.insert(spawnPoints, {
					cframe = spawnPart.CFrame + Vector3.new(0, 3, 0),
					kind = if typeof(kind) == "string" and Vehicles[kind] then kind else "TurretJeep",
				})
			end
		end
	else
		spawnPoints = table.clone(DEFAULT_SPAWNS)
	end
end

-- Al cambiar de mapa: quita los jeeps y los pone en los lugares del mapa nuevo
function VehicleService.Reset()
	spawnGeneration += 1
	for model in jeeps do
		jeeps[model] = nil
		model:Destroy()
	end
	loadSpawnPoints()
	if vehiclesEnabled then
		for _, spawnPoint in spawnPoints do
			VehicleService.Spawn(spawnPoint)
		end
	end
end

function VehicleService.Start()
	loadSpawnPoints()
	for _, spawnPoint in spawnPoints do
		VehicleService.Spawn(spawnPoint)
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
