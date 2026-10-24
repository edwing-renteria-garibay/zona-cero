-- El soldado inclina el torso y los brazos (y con ellos el arma) hacia donde apunta la mira:
-- si apuntas hacia abajo desde una montaña, el arma apunta hacia abajo; si apuntas al cielo,
-- hacia arriba. Solo mientras lleva algo en la mano.
--
-- Cómo funciona:
--   * Tu ángulo sale de la cámara (hacia dónde miras) y se manda al servidor unas 10 veces
--     por segundo (RemoteEvent "AimPitch"). El servidor lo guarda en el atributo "AimPitch"
--     de tu personaje, y así les llega a todos (ver Services/AimPose). Los bots lo ponen solos.
--   * Cada cliente inclina a todos los soldados que ve girando tres articulaciones (Motor6D):
--     la cintura (Waist) y los dos hombros. Se cambia su C0, que es dónde se une la pieza;
--     las animaciones de Roblox usan otra propiedad (Transform), así que no se estorban.
--   * La mano izquierda la lleva TwoHands (servidor) a la agarradera, así que sigue al arma.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local aimPitch = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AimPitch") :: UnreliableRemoteEvent

local player = Players.LocalPlayer

local SEND_EVERY = 0.1 -- segundos entre envíos al servidor
local MAX_PITCH = 80 -- grados (igual que el servidor)
local WAIST_SHARE = 0.4 -- cuánto del ángulo pone la cintura...
local SHOULDER_SHARE = 0.6 -- ...y cuánto los hombros (entre los dos, el ángulo completo)
local SMOOTHING = 12 -- qué tan rápido sigue al ángulo nuevo (más = más rápido)

local AimPose = {}

-- El C0 original de cada articulación (para inclinar desde ahí, no acumular)
local baseC0: { [Motor6D]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
-- El ángulo que se ve ahora en cada personaje (va alcanzando al de verdad poco a poco)
local shown: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function tilt(motor: Instance?, degrees: number)
	if not motor or not motor:IsA("Motor6D") then
		return
	end
	local base = baseC0[motor]
	if not base then
		base = motor.C0
		baseC0[motor] = base
	end
	motor.C0 = base * CFrame.Angles(math.rad(degrees), 0, 0)
end

local function pose(character: Model, target: number, dt: number)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local upperTorso = character:FindFirstChild("UpperTorso")
	if not humanoid or not upperTorso or humanoid.Health <= 0 then
		return
	end
	-- Sin nada en la mano, o sentado en el jeep: derecho
	if humanoid.Sit or not character:FindFirstChildOfClass("Tool") then
		target = 0
	end
	local current = shown[character] or 0
	current += (target - current) * math.min(1, dt * SMOOTHING)
	shown[character] = current
	tilt(upperTorso:FindFirstChild("Waist"), current * WAIST_SHARE)
	tilt(upperTorso:FindFirstChild("RightShoulder"), current * SHOULDER_SHARE)
	tilt(upperTorso:FindFirstChild("LeftShoulder"), current * SHOULDER_SHARE)
end

-- Tu ángulo: hacia dónde mira la cámara (la mira está en medio de lo que ves)
local function myPitch(): number
	local look = workspace.CurrentCamera.CFrame.LookVector
	return math.clamp(math.deg(math.asin(math.clamp(look.Y, -1, 1))), -MAX_PITCH, MAX_PITCH)
end

function AimPose.Start()
	local lastSent, sentPitch = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		local mine = player.Character
		local pitch = myPitch()
		local now = os.clock()
		if mine and now - lastSent >= SEND_EVERY and math.abs(pitch - sentPitch) >= 1 then
			lastSent, sentPitch = now, pitch
			aimPitch:FireServer(pitch)
		end

		for _, other in Players:GetPlayers() do
			local character = other.Character
			if character then
				-- El tuyo con tu ángulo de este momento (sin esperar al servidor)
				local target = if other == player then pitch else character:GetAttribute("AimPitch") or 0
				pose(character, target, dt)
			end
		end
		local bots = workspace:FindFirstChild("Bots")
		if bots then
			for _, character in bots:GetChildren() do
				if character:IsA("Model") then
					pose(character, character:GetAttribute("AimPitch") or 0, dt)
				end
			end
		end
	end)
end

return AimPose
