-- Escudo + vida, al estilo Halo.
-- El escudo (100) absorbe el daño primero y se recarga si pasan 4 s sin recibir daño.
-- La vida es la del Humanoid (100) y no se recarga sola.
-- Solo el servidor llama a Damage(): así el cliente no puede hacer trampa con la vida.

local RunService = game:GetService("RunService")

local MAX_SHIELD = 100
local REGEN_DELAY = 4 -- segundos sin daño antes de recargar
local REGEN_RATE = 40 -- puntos de escudo por segundo

local HealthService = {}

-- Se dispara cuando alguien muere: (victima: Player, asesino: Player?)
local killedEvent = Instance.new("BindableEvent")
HealthService.Killed = killedEvent.Event

local lastHit: { [Humanoid]: number } = {}
local lastAttacker: { [Humanoid]: Player? } = {}

function HealthService.SetupCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	-- Desactivamos la regeneración de vida que Roblox trae por defecto
	local defaultHealth = character:FindFirstChild("Health")
	if defaultHealth then
		defaultHealth:Destroy()
	end
	character:SetAttribute("Shield", MAX_SHIELD)
	lastHit[humanoid] = 0

	humanoid.Died:Connect(function()
		killedEvent:Fire(player, lastAttacker[humanoid])
		lastHit[humanoid] = nil
		lastAttacker[humanoid] = nil
	end)
end

-- Devuelve cuánto daño se llevó el escudo y cuánto la vida (0, 0 si no se pudo dañar)
function HealthService.Damage(humanoid: Humanoid, amount: number, attacker: Player?): (number, number)
	local character = humanoid.Parent :: Model
	if humanoid.Health <= 0 or character:GetAttribute("SpawnProtected") then
		return 0, 0
	end
	lastHit[humanoid] = os.clock()
	lastAttacker[humanoid] = attacker

	local shield = character:GetAttribute("Shield") or 0
	local absorbed = math.min(shield, amount)
	character:SetAttribute("Shield", shield - absorbed)
	humanoid:TakeDamage(amount - absorbed)
	return absorbed, amount - absorbed
end

-- Recarga de escudo en cada paso de la simulación
RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for humanoid, hitTime in lastHit do
		local character = humanoid.Parent
		if character and now - hitTime >= REGEN_DELAY then
			local shield = character:GetAttribute("Shield") or 0
			if shield < MAX_SHIELD then
				character:SetAttribute("Shield", math.min(MAX_SHIELD, shield + REGEN_RATE * dt))
			end
		end
	end
end)

return HealthService
