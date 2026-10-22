-- Ayudantes para reproducir sonidos de src/shared/Config/Sounds.luau.
-- Un texto vacío ("") en la configuración significa "sin sonido".

local Debris = game:GetService("Debris")
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

return Sfx
