-- Lo que se ve en el modo Infección:
--   · Al zombi, los sobrevivientes se le resaltan a través de las paredes (Highlight).
--   · Un aviso grande cuando te toca ser zombi o cuando empiezas como sobreviviente.
--   · A los zombis del principio, que esperan quietos unos segundos (atributo "Held" del
--     personaje, ver InfectionService), se les dice cuánto falta y, al soltarlos,
--     "¡A por los sobrevivientes!".
--   · La pócima de supervelocidad de los zombis: G (PC), Círculo/B (control) o un botón en
--     móvil. Abajo se ve si está lista o cuánto falta; quien la tomó echa chispas verdes.
-- El lado de cada jugador es su atributo "Side" (lo pone InfectionService en el servidor).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local zombieBoost = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ZombieBoost") :: RemoteEvent

local player = Players.LocalPlayer

local SURVIVOR_GLOW = Color3.fromRGB(120, 180, 255)
local ZOMBIE_TEXT = Color3.fromRGB(120, 220, 90)
local BANNER_TIME = 4

local InfectionView = {}

local function setHighlight(character: Model, on: boolean)
	local highlight = character:FindFirstChild("SurvivorHighlight")
	if on and not highlight then
		local new = Instance.new("Highlight")
		new.Name = "SurvivorHighlight"
		new.FillColor = SURVIVOR_GLOW
		new.FillTransparency = 0.6
		new.OutlineColor = Color3.new(1, 1, 1)
		new.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- se ve a través de las paredes
		new.Parent = character
	elseif not on and highlight then
		highlight:Destroy()
	end
end

function InfectionView.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "InfectionView"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.4)
	banner.Size = UDim2.fromOffset(700, 80)
	banner.BackgroundTransparency = 1
	banner.Font = Enum.Font.GothamBlack
	banner.TextSize = 32
	banner.TextStrokeTransparency = 0.3
	banner.TextWrapped = true
	banner.Visible = false
	banner.Parent = gui

	local shownAt = 0
	local function show(text: string, color: Color3)
		banner.Text = text
		banner.TextColor3 = color
		banner.Visible = true
		local myShow = os.clock()
		shownAt = myShow
		task.delay(BANNER_TIME, function()
			if shownAt == myShow then
				banner.Visible = false
			end
		end)
	end

	player:GetAttributeChangedSignal("Side"):Connect(function()
		local side = player:GetAttribute("Side")
		if side == "Zombie" then
			show("¡Eres zombi! Atrapa a los sobrevivientes (F o clic)", ZOMBIE_TEXT)
		elseif side == "Survivor" then
			show("Sobrevive: hay zombis entre ustedes", Color3.new(1, 1, 1))
		end
	end)

	-- La pausa de los zombis del principio: cuenta lo que falta y luego los manda
	local function countHold(character: Model)
		while character.Parent and character:GetAttribute("Held") do
			local untilTime = character:GetAttribute("HeldUntil") or 0
			local left = math.max(1, math.ceil(untilTime - workspace:GetServerTimeNow()))
			banner.Text = `¡Eres zombi! Sales en {left} s: prepárate`
			banner.TextColor3 = ZOMBIE_TEXT
			banner.Visible = true
			shownAt = os.clock()
			task.wait(0.2)
		end
		if character.Parent and player:GetAttribute("Side") == "Zombie" then
			show("¡A por los sobrevivientes!", ZOMBIE_TEXT)
		end
	end
	local function watchHold(character: Model)
		local counting = false
		local function check()
			if character:GetAttribute("Held") and not counting then
				counting = true
				countHold(character)
				counting = false
			end
		end
		character:GetAttributeChangedSignal("Held"):Connect(check)
		task.spawn(check)
	end
	player.CharacterAdded:Connect(watchHold)
	if player.Character then
		watchHold(player.Character)
	end

	-- La pócima: el botón solo existe mientras eres zombi. Va por encima de la granada (misma
	-- tecla), que un zombi no tiene
	local potion = Instance.new("TextLabel")
	potion.AnchorPoint = Vector2.new(0.5, 1)
	potion.Position = UDim2.new(0.5, 0, 1, -110)
	potion.Size = UDim2.fromOffset(420, 26)
	potion.BackgroundTransparency = 1
	potion.Font = Enum.Font.GothamBold
	potion.TextSize = 18
	potion.TextColor3 = ZOMBIE_TEXT
	potion.TextStrokeTransparency = 0.4
	potion.Visible = false
	potion.Parent = gui
	local bound = false
	local function updateBinding()
		local zombie = player:GetAttribute("Side") == "Zombie"
		if zombie and not bound then
			bound = true
			ContextActionService:BindActionAtPriority("ZombieBoost", function(_name, state)
				if state == Enum.UserInputState.Begin then
					zombieBoost:FireServer()
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.G, Enum.KeyCode.ButtonB)
			ContextActionService:SetTitle("ZombieBoost", "Pócima")
		elseif not zombie and bound then
			bound = false
			ContextActionService:UnbindAction("ZombieBoost")
		end
	end
	player:GetAttributeChangedSignal("Side"):Connect(updateBinding)
	updateBinding()
	task.spawn(function()
		while true do
			local character = player.Character
			if bound and character then
				local left = (character:GetAttribute("BoostReadyAt") or 0) - workspace:GetServerTimeNow()
				potion.Text = if character:GetAttribute("Boosted")
					then "¡Supervelocidad!"
					elseif left > 0 then `Pócima de velocidad: lista en {math.ceil(left)} s`
					else "Pócima de velocidad lista: G / Círculo"
				potion.Visible = true
			else
				potion.Visible = false
			end
			task.wait(0.2)
		end
	end)

	-- Chispas verdes en quien va con supervelocidad (jugadores y bots)
	local function sparkle(character: Model)
		local root = character:FindFirstChild("HumanoidRootPart")
		local fx = root and root:FindFirstChild("BoostFx")
		local on = character:GetAttribute("Boosted") == true
		if on and root and not fx then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "BoostFx"
			emitter.Color = ColorSequence.new(ZOMBIE_TEXT)
			emitter.LightEmission = 0.8
			emitter.Size = NumberSequence.new(0.4, 0)
			emitter.Lifetime = NumberRange.new(0.3, 0.6)
			emitter.Rate = 60
			emitter.Speed = NumberRange.new(2, 5)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Parent = root
		elseif not on and fx then
			fx:Destroy()
		end
	end
	task.spawn(function()
		while true do
			for _, other in Players:GetPlayers() do
				if other.Character then
					sparkle(other.Character)
				end
			end
			local bots = workspace:FindFirstChild("Bots")
			for _, character in if bots then bots:GetChildren() else {} do
				if character:IsA("Model") then
					sparkle(character)
				end
			end
			task.wait(0.2)
		end
	end)

	-- Revisar dos veces por segundo a quién hay que resaltar
	task.spawn(function()
		while true do
			local iAmZombie = player:GetAttribute("Side") == "Zombie"
			for _, other in Players:GetPlayers() do
				local character = other.Character
				if other ~= player and character then
					setHighlight(character, iAmZombie and other:GetAttribute("Side") == "Survivor")
				end
			end
			task.wait(0.5)
		end
	end)
end

return InfectionView
