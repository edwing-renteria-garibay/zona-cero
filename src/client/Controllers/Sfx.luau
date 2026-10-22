-- Ayudantes para reproducir sonidos de src/shared/Config/Sounds.luau.
-- Un texto vacío ("") en la configuración significa "sin sonido".

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Sfx = {}

-- Sonido en un punto del mundo: se oye más fuerte cerca y se apaga a lo lejos
function Sfx.PlayAt(soundId: string?, position: Vector3, volume: number?)
	if not soundId or soundId == "" then
		return
	end
	-- Un Attachment en el Terrain marca el punto de donde sale el sonido
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position
	anchor.Parent = workspace.Terrain
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.6
	sound.RollOffMaxDistance = 400
	-- Un poco de variación para que una ráfaga no suene como el mismo audio repetido
	sound.PlaybackSpeed = 0.95 + math.random() * 0.1
	sound.Parent = anchor
	sound:Play()
	Debris:AddItem(anchor, 3)
end

-- Sonido que solo oye este jugador, sin posición (por ejemplo, el clic sin balas)
local cache: { [string]: Sound } = {}
function Sfx.PlayLocal(soundId: string?)
	if not soundId or soundId == "" then
		return
	end
	local sound = cache[soundId]
	if not sound then
		sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = 0.6
		sound.Parent = SoundService
		cache[soundId] = sound
	end
	SoundService:PlayLocalSound(sound)
end

-- Sonido de ráfaga pegado a una pieza (por ejemplo, el cañón de la torreta).
-- Cada disparo lo mantiene sonando; si dejan de llegar disparos, se corta.
local BURST_STOP_AFTER = 0.25 -- segundos sin disparos para cortar la ráfaga
local bursts: { [BasePart]: { sound: Sound, lastShot: number } } = {}

function Sfx.KeepBurst(soundId: string?, part: BasePart)
	if not soundId or soundId == "" then
		return
	end
	local burst = bursts[part]
	if not burst then
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Looped = true
		sound.Volume = 0.6
		sound.RollOffMaxDistance = 400
		sound.Parent = part
		burst = { sound = sound, lastShot = 0 }
		bursts[part] = burst
	end
	burst.lastShot = os.clock()
	if not burst.sound.IsPlaying then
		burst.sound:Play()
	end
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for part, burst in bursts do
		if not part.Parent then
			bursts[part] = nil -- el jeep ya no existe (explotó)
		elseif burst.sound.IsPlaying and now - burst.lastShot > BURST_STOP_AFTER then
			burst.sound:Stop()
		end
	end
end)

return Sfx
