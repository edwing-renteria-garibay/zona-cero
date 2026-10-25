-- Música y efectos se pueden apagar por separado (menú > Sonido). Cada sonido que suena para
-- este jugador va a uno de dos grupos (SoundGroup): "Musica" (MusicController) o "Efectos"
-- (todo lo demás: disparos, explosiones, jeeps, pasos...). Apagar un grupo baja su volumen a
-- 0 solo para este jugador.
-- Lo que elige el jugador se guarda en su perfil (ShopService, acción "mute"), y el servidor
-- lo devuelve en los atributos MusicMuted y EffectsMuted al entrar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local shopRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop") :: RemoteFunction

local player = Players.LocalPlayer

local AudioSettings = {}

local function newGroup(name: string): SoundGroup
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Parent = SoundService
	return group
end

AudioSettings.music = newGroup("Musica")
AudioSettings.effects = newGroup("Efectos")

local groups = { Music = AudioSettings.music, Effects = AudioSettings.effects }

-- kind: "Music" o "Effects"
function AudioSettings.IsMuted(kind: string): boolean
	return player:GetAttribute(kind .. "Muted") == true
end

function AudioSettings.SetMuted(kind: string, muted: boolean)
	player:SetAttribute(kind .. "Muted", muted) -- se ve al instante; el servidor lo guarda
	task.spawn(function()
		pcall(shopRemote.InvokeServer, shopRemote, "mute", kind, muted)
	end)
end

local function apply(kind: string)
	groups[kind].Volume = if AudioSettings.IsMuted(kind) then 0 else 1
end

-- Todo sonido sin grupo va a "Efectos" (la música ya llega con el suyo)
local function claim(instance: Instance)
	if instance:IsA("Sound") and instance.SoundGroup == nil then
		instance.SoundGroup = AudioSettings.effects
	end
end

function AudioSettings.Start()
	for kind in groups do
		apply(kind)
		player:GetAttributeChangedSignal(kind .. "Muted"):Connect(function()
			apply(kind)
		end)
	end
	for _, root in { workspace, SoundService } do
		for _, instance in root:GetDescendants() do
			claim(instance)
		end
		root.DescendantAdded:Connect(function(instance)
			-- Un momento después, para que quien lo creó alcance a ponerle su grupo
			task.defer(claim, instance)
		end)
	end
end

return AudioSettings
