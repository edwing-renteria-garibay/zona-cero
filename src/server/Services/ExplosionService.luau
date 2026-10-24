-- Explosiones: el jeep al ser destruido, los cohetes y las granadas usan la misma.
-- La explosión de Roblox (Instance "Explosion") es solo visual: no rompe nada ni empuja.
-- El daño lo calculamos nosotros para que respete escudos, equipos y bajas.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Combatants = require(script.Parent.Combatants)
local HealthService = require(script.Parent.HealthService)

export type Blast = {
	damage: number, -- daño completo, dentro de innerRadius
	innerRadius: number, -- studs con daño completo
	radius: number, -- studs hasta donde llega el daño (0 en el borde)
	vehicleDamage: number?, -- daño máximo a un jeep (si no se indica, el mismo que a un jugador)
	sound: string?, -- qué sonido de Sounds.explosion usar ("rocket", "grenade" o "jeep");
	-- también es la causa de muerte en el registro de bajas
}

-- Un jugador (o bot) al que le llegó la explosión (para avisar al atacante)
export type BlastHit = {
	player: Combatants.Combatant,
	toShield: number,
	toHealth: number,
	position: Vector3,
}

local ExplosionService = {}

-- Daño según la distancia al centro: completo cerca, 0 en el borde del radio
function ExplosionService.DamageAt(blast: Blast, distance: number, maxDamage: number?): number
	local falloff = (distance - blast.innerRadius) / (blast.radius - blast.innerRadius)
	return (maxDamage or blast.damage) * (1 - math.clamp(falloff, 0, 1))
end

-- Reproduce un sonido de Config/Sounds en un punto del mundo; todos lo oyen
function ExplosionService.PlaySoundAt(soundId: string?, position: Vector3)
	if not soundId or soundId == "" then
		return
	end
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position
	anchor.Parent = workspace.Terrain
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.RollOffMaxDistance = 600
	sound.Parent = anchor
	sound:Play()
	Debris:AddItem(anchor, 6)
end

-- Explota en center: efecto visual, sonido y daño a los jugadores (y bots) cercanos.
-- No daña a los compañeros del atacante, pero sí al atacante si está demasiado cerca.
-- Los jeeps cercanos los daña VehicleService.BlastVehicles (para no depender uno del otro).
function ExplosionService.Blast(center: Vector3, attacker: Player?, blast: Blast): { BlastHit }
	local explosion = Instance.new("Explosion")
	explosion.Position = center
	explosion.BlastRadius = blast.radius
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Parent = workspace
	ExplosionService.PlaySoundAt(Sounds.explosion[blast.sound or "rocket"], center)

	local hits: { BlastHit } = {}
	for _, player in Combatants.All() do -- jugadores y bots
		local character = Combatants.Character(player)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		-- A los compañeros no les hace daño (en Infección, a los de su mismo lado)
		local teammate = attacker and player ~= attacker and not Combatants.IsEnemy(attacker, player)
		if humanoid and root and not teammate then
			local distance = (root.Position - center).Magnitude
			if distance < blast.radius then
				local toShield, toHealth = HealthService.Damage(
					humanoid,
					ExplosionService.DamageAt(blast, distance),
					attacker,
					blast.sound or "rocket"
				)
				if toShield + toHealth > 0 then
					table.insert(hits, {
						player = player,
						toShield = toShield,
						toHealth = toHealth,
						position = root.Position,
					})
				end
			end
		end
	end
	return hits
end

return ExplosionService
