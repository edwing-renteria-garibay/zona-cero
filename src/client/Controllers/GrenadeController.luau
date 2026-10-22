-- Lanzar granada: tecla G en PC, botón L1 en mando, botón "Granada" en móvil.
-- El cliente solo dice hacia dónde apuntas; el servidor crea la granada y la hace explotar.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Grenades = require(ReplicatedStorage.Shared.Config.Grenades)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Aim = require(script.Parent.Aim)
local Sfx = require(script.Parent.Sfx)

local throwGrenade = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ThrowGrenade") :: RemoteEvent

local player = Players.LocalPlayer

local GrenadeController = {}

local lastThrow = 0

-- Granadas que te quedan (el servidor guarda el valor real en el atributo "Grenades")
function GrenadeController.GetCount(): number
	local character = player.Character
	return character and character:GetAttribute("Grenades") or 0
end

local function onAction(_name: string, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local now = os.clock()
	if head and now - lastThrow >= Grenades.cooldown then
		if GrenadeController.GetCount() <= 0 then
			Sfx.PlayLocal(Sounds.empty)
		else
			lastThrow = now
			throwGrenade:FireServer(Aim.GetTarget() - head.Position)
		end
	end
	return Enum.ContextActionResult.Sink
end

function GrenadeController.Start()
	-- El "true" crea un botón táctil en móvil
	ContextActionService:BindAction("Grenade", onAction, true, Enum.KeyCode.G, Enum.KeyCode.ButtonL1)
	ContextActionService:SetTitle("Grenade", "Granada")
end

return GrenadeController
