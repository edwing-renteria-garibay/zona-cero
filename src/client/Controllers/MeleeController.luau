-- Golpe cuerpo a cuerpo: tecla F en PC, botón "Golpe" en móvil.
-- El cliente solo avisa; el servidor busca a quién golpear y aplica el daño.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Melee = require(ReplicatedStorage.Shared.Config.Melee)

local meleeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Melee") :: RemoteEvent

local MeleeController = {}

local lastMelee = 0

local function onAction(_name: string, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local now = os.clock()
	if now - lastMelee >= Melee.cooldown then
		lastMelee = now
		meleeRemote:FireServer()
	end
	return Enum.ContextActionResult.Sink
end

function MeleeController.Start()
	-- El "true" crea un botón táctil en móvil
	ContextActionService:BindAction("Melee", onAction, true, Enum.KeyCode.F, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("Melee", "Golpe")
end

return MeleeController
