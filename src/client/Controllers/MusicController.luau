-- Música de fondo: toca la canción del modo (Config/Music) mientras se juega la partida.
-- Al cambiar de modo, la canción anterior baja poco a poco y la nueva sube.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Music = require(ReplicatedStorage.Shared.Config.Music)

local MusicController = {}

local current: Sound? = nil

local function fadeOut(sound: Sound)
	local tween = TweenService:Create(sound, TweenInfo.new(Music.fadeTime), { Volume = 0 })
	tween.Completed:Connect(function()
		sound:Destroy()
	end)
	tween:Play()
end

local function update()
	local phase = ReplicatedStorage:GetAttribute("MatchPhase")
	local mode = ReplicatedStorage:GetAttribute("MatchMode")
	local soundId = if phase == "Playing" then Music.byMode[mode or ""] else nil
	if soundId == "" then
		soundId = nil
	end
	if current and current.SoundId == soundId then
		return
	end
	if current then
		fadeOut(current)
		current = nil
	end
	if soundId then
		local sound = Instance.new("Sound")
		sound.Name = "Musica"
		sound.SoundId = soundId
		sound.Looped = true
		sound.Volume = 0
		sound.Parent = SoundService
		sound:Play()
		TweenService:Create(sound, TweenInfo.new(Music.fadeTime), { Volume = Music.volume }):Play()
		current = sound
	end
end

function MusicController.Start()
	ReplicatedStorage:GetAttributeChangedSignal("MatchPhase"):Connect(update)
	ReplicatedStorage:GetAttributeChangedSignal("MatchMode"):Connect(update)
	update()
end

return MusicController
