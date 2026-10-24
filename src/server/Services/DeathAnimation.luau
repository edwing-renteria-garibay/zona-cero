-- Cómo cae el cuerpo al morir, según con qué te mataron:
--   * Machete, pollo, golpe o puñalada: el cuerpo se deshace en pedazos (lo de siempre en Roblox).
--   * Tiro a la cabeza: el monito gira sobre sí mismo y cae como muñeco de trapo.
--   * Otro disparo: cae como muñeco de trapo hacia atrás, empujado desde donde vino el tiro.
--   * Explosión (cohete, granada, SimiO, cañón de iones, bomba): sale volando.
--   * Jeep: sale disparado hacia donde iba el golpe.
--
-- "Muñeco de trapo" (ragdoll): cada articulación del cuerpo (Motor6D) se cambia por una rótula
-- (BallSocketConstraint) con límites, así brazos, piernas y cabeza cuelgan como de verdad.
-- Para que el empujón funcione, el servidor se queda con la física del cuerpo
-- (SetNetworkOwner(nil)): si la tuviera el jugador, ignoraría el empujón del servidor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Melee = require(ReplicatedStorage.Shared.Config.Melee)

local DeathAnimation = {}

local EXPLOSIONS = { rocket = true, grenade = true, ion = true, simi = true, bomb = true }

-- Qué tipo de muerte fue, según la causa (ver HealthService.Killed)
local function kindOf(cause: string?, headshot: boolean): string
	if cause == "Machete" or cause == "Backstab" or cause == "Melee" or (cause and Melee.weapons[cause]) then
		return "shatter"
	elseif cause and EXPLOSIONS[cause] then
		return "blast"
	elseif cause == "jeep" then
		return "runover"
	elseif headshot then
		return "spin"
	end
	return "shot"
end

-- Se deshace en pedazos: se quitan todas las articulaciones
local function shatter(character: Model)
	for _, joint in character:GetDescendants() do
		if joint:IsA("Motor6D") then
			joint:Destroy()
		end
	end
end

-- Cambia las articulaciones por rótulas. La del HumanoidRootPart se queda (la cámara lo sigue)
local function ragdoll(character: Model)
	for _, motor in character:GetDescendants() do
		if not motor:IsA("Motor6D") or not motor.Part0 or not motor.Part1 then
			continue
		end
		if motor.Part0.Name == "HumanoidRootPart" or motor.Part1.Name == "HumanoidRootPart" then
			continue
		end
		local a0 = Instance.new("Attachment")
		a0.Name = "RagdollA0"
		a0.CFrame = motor.C0
		a0.Parent = motor.Part0
		local a1 = Instance.new("Attachment")
		a1.Name = "RagdollA1"
		a1.CFrame = motor.C1
		a1.Parent = motor.Part1
		local socket = Instance.new("BallSocketConstraint")
		socket.Attachment0 = a0
		socket.Attachment1 = a1
		socket.LimitsEnabled = true
		socket.UpperAngle = if motor.Name == "Neck" then 30 else 60
		socket.TwistLimitsEnabled = true
		socket.TwistLowerAngle = -30
		socket.TwistUpperAngle = 30
		socket.Parent = motor.Part1
		motor.Enabled = false
	end
	-- Los brazos y piernas de un R15 no chocan con el piso mientras está vivo: ahora sí
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") then
			part.CanCollide = part.Name ~= "HumanoidRootPart"
		end
	end
end

-- character: el cuerpo de quien murió. from: dónde estaba quien lo mató (si se sabe)
function DeathAnimation.Play(character: Model, cause: string?, headshot: boolean, from: Vector3?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	if not humanoid or not root or not torso then
		return
	end
	local kind = kindOf(cause, headshot)
	if kind == "shatter" then
		shatter(character)
		return
	end
	ragdoll(character)
	humanoid.PlatformStand = true -- que no intente pararse

	-- Hacia dónde lo empujan: lejos de quien lo mató (o hacia atrás si no se sabe)
	local away = -root.CFrame.LookVector
	if from then
		local offset = root.Position - from
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude > 0.1 then
			away = flat.Unit
		end
	end
	local side = away:Cross(Vector3.yAxis) -- eje para que se vaya de espaldas
	local velocity, spin
	if kind == "spin" then
		-- Gira sobre sí mismo y cae de lado
		velocity, spin = away * 6 + Vector3.yAxis * 8, Vector3.yAxis * 14 + side * 3
	elseif kind == "blast" then
		velocity, spin = away * 30 + Vector3.yAxis * 50, side * 8
	elseif kind == "runover" then
		velocity, spin = away * 45 + Vector3.yAxis * 20, side * 6
	else
		velocity, spin = away * 10 + Vector3.yAxis * 3, side * 3
	end
	-- Cada pedazo con la misma velocidad: todo el cuerpo sale junto
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and not part.Anchored then
			pcall(part.SetNetworkOwner, part, nil)
			part.AssemblyLinearVelocity = velocity
			part.AssemblyAngularVelocity = spin
		end
	end
end

-- Antes de morir: que Roblox no rompa el cuerpo solo (lo decide Play)
function DeathAnimation.Prepare(humanoid: Humanoid)
	humanoid.BreakJointsOnDeath = false
end

return DeathAnimation
