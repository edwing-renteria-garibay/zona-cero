-- Controles del jeep en el cliente. Conducir no necesita código aquí: el asiento
-- de conductor (VehicleSeat) ya envía W/A/S/D al servidor. Este archivo se encarga
-- de la torreta: mientras mantienes el clic, pide al servidor que dispare.

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
local turret = Vehicles.TurretJeep.turret

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

-- Balas que le quedan a la torreta de un jeep (el servidor guarda el valor real)
function VehicleController.GetTurretAmmo(vehicle: Model): number
	return vehicle:GetAttribute("TurretAmmo") or turret.magazine
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

local function isTrigger(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.ButtonR2
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
		if not seat then
			return
		end
		-- En la torreta no se usa el rifle: se guarda para que el clic no dispare los dos
		local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid:UnequipTools()

		local now = os.clock()
		if not triggerHeld or now - lastShot < 1 / turret.fireRate then
			return
		end
		local vehicle = seat.Parent :: Model
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
		lastShot = now
		local tip = (barrel.CFrame * CFrame.new(0, 0, -2)).Position
		fireTurret:FireServer(Aim.GetTarget() - tip)
	end)
end

return VehicleController
