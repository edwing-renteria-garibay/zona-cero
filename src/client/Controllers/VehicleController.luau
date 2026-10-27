-- Controles del jeep en el cliente. Conducir no necesita código aquí: el asiento
-- de conductor (VehicleSeat) ya envía W/A/S/D al servidor. Este archivo se encarga
-- de la torreta: mientras mantienes el clic, pide al servidor que dispare. La torreta
-- es una ametralladora o un lanzacohetes, según el jeep (Config/Vehicles).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Aim = require(script.Parent.Aim)
local Sfx = require(script.Parent.Sfx)

local fireTurret = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FireTurret") :: RemoteEvent

local player = Players.LocalPlayer

local VehicleController = {}

local triggerHeld = false
local lastShot = 0

-- El asiento en el que vas, si es el de una torreta
local function getTurretSeat(): Seat?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat and seat:GetAttribute("Turret") then
		return seat :: Seat
	end
	return nil
end

-- ¿Vas sentado en la torreta? (para la mira)
function VehicleController.IsInTurret(): boolean
	return getTurretSeat() ~= nil
end

-- El arma de la torreta de un jeep: (sus datos, y si es de cohetes)
function VehicleController.GetTurretWeapon(vehicle: Model): ({ [string]: any }, boolean)
	local stats = Vehicles[vehicle:GetAttribute("Vehicle")] or Vehicles.TurretJeep
	return stats.rockets or stats.turret, stats.rockets ~= nil
end

-- ¿Puede la torreta disparar hacia target? Solo hacia el frente del jeep: hasta turretArc
-- grados a cada lado (el servidor revisa lo mismo)
function VehicleController.InTurretArc(vehicle: Model, target: Vector3): boolean
	local mount = vehicle:FindFirstChild("TurretMount") :: BasePart?
	local barrel = vehicle:FindFirstChild("TurretBarrel") :: BasePart?
	local stats = Vehicles[vehicle:GetAttribute("Vehicle")] or Vehicles.TurretJeep
	if not mount or not barrel then
		return false
	end
	-- La misma dirección que recibe el servidor: de la punta del cañón al objetivo
	local tip = (barrel.CFrame * CFrame.new(0, 0, -2)).Position
	local localDirection = mount.CFrame:VectorToObjectSpace(target - tip)
	local yaw = math.atan2(-localDirection.X, -localDirection.Z)
	return math.abs(yaw) <= math.rad(stats.turretArc)
end

-- Balas (o cohetes) que le quedan a la torreta de un jeep (el servidor guarda el valor real)
function VehicleController.GetTurretAmmo(vehicle: Model): number
	return vehicle:GetAttribute("TurretAmmo") or VehicleController.GetTurretWeapon(vehicle).magazine
end

-- El asiento actual del jugador (para el HUD)
function VehicleController.GetVehicle(): Model?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local model = seat and seat.Parent
	if model and model:GetAttribute("Vehicle") then
		return model :: Model
	end
	return nil
end

-- En celular la torreta dispara con el botón "Disparar" (UI/TouchButtons), no tocando la
-- pantalla: el dedo en la pantalla es para mover la cámara
local function isTrigger(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2
end

-- El botón "Disparar" en celular
function VehicleController.SetTrigger(held: boolean)
	triggerHeld = held
end

-- Sentado en la torreta, el cañón (o la caja de cohetes) y su base tapan la vista: solo en tu
-- pantalla se vuelven casi transparentes (LocalTransparencyModifier); los demás los ven normal
local TURRET_FADE = 0.85
local fadedVehicle: Model? = nil

local function fadeTurret(vehicle: Model?, amount: number)
	if not vehicle then
		return
	end
	for _, name in { "TurretBarrel", "TurretMount" } do
		local part = vehicle:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.LocalTransparencyModifier = amount
			for _, child in part:GetDescendants() do
				if child:IsA("BasePart") then
					child.LocalTransparencyModifier = amount
				end
			end
		end
	end
end

function VehicleController.Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and isTrigger(input) then
			triggerHeld = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isTrigger(input) then
			triggerHeld = false
		end
	end)

	RunService.Heartbeat:Connect(function()
		local seat = getTurretSeat()
		local seatVehicle = if seat then seat.Parent :: Model else nil
		if seatVehicle ~= fadedVehicle then
			fadeTurret(fadedVehicle, 0) -- te bajaste: se ve normal otra vez
			fadeTurret(seatVehicle, TURRET_FADE)
			fadedVehicle = seatVehicle
		end
		if not seat then
			return
		end
		-- En la torreta no se usa el rifle: se guarda para que el clic no dispare los dos
		local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid:UnequipTools()

		local vehicle = seat.Parent :: Model
		local turret = VehicleController.GetTurretWeapon(vehicle)
		local now = os.clock()
		if not triggerHeld or now - lastShot < 1 / turret.fireRate then
			return
		end
		if vehicle:GetAttribute("TurretReloading") then
			return
		end
		if VehicleController.GetTurretAmmo(vehicle) <= 0 then
			Sfx.PlayLocal(Sounds.empty)
			triggerHeld = false -- un solo clic de "sin balas" por cada vez que aprietas
			return
		end
		local barrel = vehicle:FindFirstChild("TurretBarrel") :: BasePart?
		if not barrel then
			return
		end
		local target = Aim.GetTarget()
		-- Hacia atrás no dispara: hay que girar el jeep
		if not VehicleController.InTurretArc(vehicle, target) then
			return
		end
		lastShot = now
		local tip = (barrel.CFrame * CFrame.new(0, 0, -2)).Position
		fireTurret:FireServer(target - tip)
	end)
end

return VehicleController
