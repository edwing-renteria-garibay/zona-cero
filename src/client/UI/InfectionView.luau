-- Lo que se ve en el modo Infección:
--   · Al zombi, los sobrevivientes se le resaltan a través de las paredes (Highlight).
--   · Un aviso grande cuando te toca ser zombi o cuando empiezas como sobreviviente.
-- El lado de cada jugador es su atributo "Side" (lo pone InfectionService en el servidor).

local Players = game:GetService("Players")

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
