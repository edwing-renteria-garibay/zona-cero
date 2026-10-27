-- Correr: mantén Shift (L3 en control) para ir más rápido. En móvil, el botón "Correr"
-- (UI/TouchButtons) se toca una vez para correr y otra para dejar de correr.
-- Los zombis no corren: ya son rápidos (Config/Modes, zombieSpeed).
--
-- La velocidad de tu personaje la controla tu propio cliente, así que basta con cambiar
-- WalkSpeed aquí. Solo la subimos si estás a la velocidad normal: si el arma de hielo te
-- frenó, el servidor manda y no corres.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Movement = require(ReplicatedStorage.Shared.Config.Movement)

local player = Players.LocalPlayer

local SprintController = {}

local function getHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function canSprint(humanoid: Humanoid): boolean
	return player:GetAttribute("Side") ~= "Zombie" and humanoid.SeatPart == nil and humanoid.Health > 0
end

local function onAction(_name: string, state: Enum.UserInputState)
	local humanoid = getHumanoid()
	if not humanoid then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		if canSprint(humanoid) and humanoid.WalkSpeed == Movement.walkSpeed then
			humanoid.WalkSpeed = Movement.sprintSpeed
		end
	elseif humanoid.WalkSpeed == Movement.sprintSpeed then
		-- Soltaste el botón (o se canceló): de vuelta a caminar
		humanoid.WalkSpeed = Movement.walkSpeed
	end
	return Enum.ContextActionResult.Pass
end

function SprintController.Start()
	-- El botón de móvil es de UI/TouchButtons (por eso el "false")
	ContextActionService:BindAction("Sprint", onAction, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("Sprint", "Correr")

	-- Si te vuelves zombi mientras corres, dejas de correr
	player:GetAttributeChangedSignal("Side"):Connect(function()
		local humanoid = getHumanoid()
		if humanoid and not canSprint(humanoid) and humanoid.WalkSpeed == Movement.sprintSpeed then
			humanoid.WalkSpeed = Movement.walkSpeed
		end
	end)
end

return SprintController
