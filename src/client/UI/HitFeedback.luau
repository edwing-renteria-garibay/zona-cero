-- Aviso de acierto para quien dispara: un número de daño que flota sobre el impacto
-- y un sonido corto (se elige en src/shared/Config/Sounds.luau). Así sabes que hiciste daño aunque el enemigo todavía tenga escudo.
-- Azul = el escudo se llevó todo el daño; blanco = llegó a la vida; naranja = a la cabeza.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local hitConfirmed = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("HitConfirmed") :: RemoteEvent

local SHIELD_COLOR = Color3.fromRGB(90, 200, 255)
local HEALTH_COLOR = Color3.new(1, 1, 1)
local HEAD_COLOR = Color3.fromRGB(255, 170, 0)
local FLOAT_TIME = 0.7 -- segundos que tarda el número en subir y desvanecerse

local HitFeedback = {}

local function showDamage(amount: number, position: Vector3, color: Color3, big: boolean)
	-- Un Attachment en el Terrain marca un punto del mundo donde colgar el número
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position
	anchor.Parent = workspace.Terrain

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(80, 30)
	billboard.AlwaysOnTop = true -- se ve aunque algo lo tape
	billboard.LightInfluence = 0
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = tostring(math.round(amount))
	label.TextSize = if big then 30 else 22
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard

	-- Pequeño desvío al azar para que los números seguidos no se tapen entre sí
	local side = (math.random() - 0.5) * 1.5
	local info = TweenInfo.new(FLOAT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(billboard, info, { StudsOffsetWorldSpace = Vector3.new(side, 2.5, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(FLOAT_TIME, anchor.Destroy, anchor)
end

function HitFeedback.Start()
	local function makeSound(soundId: string): Sound
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = 0.5
		sound.Parent = SoundService
		return sound
	end
	local hitSound = makeSound(Sounds.hit)
	local headshotSound = makeSound(Sounds.headshot)
	-- Si los dos son el mismo audio, el de la cabeza suena más agudo para distinguirlo
	if Sounds.headshot == Sounds.hit then
		headshotSound.PlaybackSpeed = 1.5
	end

	hitConfirmed.OnClientEvent:Connect(
		function(kind: string, amount: number?, position: Vector3?, surface: string?)
			local headshot = kind == "head"
			local sound = if headshot then headshotSound else hitSound
			if sound.SoundId ~= "" then
				SoundService:PlayLocalSound(sound)
			end
			if amount and position then
				local color = if headshot
					then HEAD_COLOR
					elseif surface == "shield" then SHIELD_COLOR
					else HEALTH_COLOR
				showDamage(amount, position, color, headshot)
			end
		end
	)
end

return HitFeedback
