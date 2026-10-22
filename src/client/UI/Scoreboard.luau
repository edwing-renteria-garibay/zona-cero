-- Marcador arriba al centro: puntos de cada equipo, tiempo que queda y bajas para ganar.
-- En Asesino en solitario muestra tus bajas (izquierda) y las del que va ganando (derecha).
-- Antes de empezar muestra "Esperando jugadores" o la cuenta regresiva en grande.
-- Todo se lee de los atributos que pone MatchService en ReplicatedStorage y en cada Team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")

local Modes = require(ReplicatedStorage.Shared.Config.Modes)

local player = Players.LocalPlayer

local SOLO_YOU = Color3.fromRGB(70, 70, 70)
local SOLO_LEADER = Color3.fromRGB(200, 150, 30)

local Scoreboard = {}

local function makeLabel(parent: Instance, size: UDim2, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = textSize
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = parent
	return label
end

-- Una caja con el color del equipo y su puntuación
local function makeTeamBox(parent: Instance, order: number): (Frame, TextLabel)
	local box = Instance.new("Frame")
	box.Size = UDim2.fromOffset(70, 40)
	box.BackgroundTransparency = 0.2
	box.BorderSizePixel = 0
	box.LayoutOrder = order
	box.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = box
	local score = makeLabel(box, UDim2.fromScale(1, 1), 26)
	return box, score
end

local function killsOf(someone: Player): number
	local leaderstats = someone:FindFirstChild("leaderstats")
	local kills = leaderstats and leaderstats:FindFirstChild("Bajas")
	return if kills and kills:IsA("IntValue") then kills.Value else 0
end

-- Las bajas del que va ganando, sin contarte a ti
local function leaderKills(): number
	local best = 0
	for _, other in Players:GetPlayers() do
		if other ~= player then
			best = math.max(best, killsOf(other))
		end
	end
	return best
end

local function formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Scoreboard.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Scoreboard"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Fila de arriba: [Rojo] 4:32 [Azul]
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 8)
	bar.Size = UDim2.fromOffset(260, 40)
	bar.BackgroundTransparency = 1
	bar.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	local leftBox, leftScore = makeTeamBox(bar, 1)
	local timer = makeLabel(bar, UDim2.fromOffset(90, 40), 24)
	timer.LayoutOrder = 2
	local rightBox, rightScore = makeTeamBox(bar, 3)

	local goal = makeLabel(gui, UDim2.fromOffset(420, 20), 14)
	goal.AnchorPoint = Vector2.new(0.5, 0)
	goal.Position = UDim2.new(0.5, 0, 0, 50)
	goal.Font = Enum.Font.GothamBold

	-- Mensaje grande en el centro (esperando / cuenta regresiva)
	local banner = makeLabel(gui, UDim2.fromOffset(600, 60), 36)
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.3)

	RunService.RenderStepped:Connect(function()
		local phase = ReplicatedStorage:GetAttribute("MatchPhase")
		local mode = ReplicatedStorage:GetAttribute("MatchMode")
		local teams = Teams:GetTeams()
		-- Tu equipo siempre a la izquierda
		table.sort(teams, function(a, b)
			if a == player.Team then
				return true
			elseif b == player.Team then
				return false
			end
			return a.Name < b.Name
		end)
		local left, right = teams[1], teams[2]
		bar.Visible = left ~= nil and right ~= nil
		if mode == "FreeForAll" then
			leftBox.BackgroundColor3 = SOLO_YOU
			rightBox.BackgroundColor3 = SOLO_LEADER
			leftScore.Text = tostring(killsOf(player))
			rightScore.Text = tostring(leaderKills())
		elseif left and right then
			leftBox.BackgroundColor3 = left.TeamColor.Color
			rightBox.BackgroundColor3 = right.TeamColor.Color
			leftScore.Text = tostring(left:GetAttribute("Score") or 0)
			rightScore.Text = tostring(right:GetAttribute("Score") or 0)
		end

		if phase == "Playing" then
			local endsAt = ReplicatedStorage:GetAttribute("MatchEndsAt") or 0
			timer.Text = formatTime(endsAt - workspace:GetServerTimeNow())
			local unit = if mode == "CaptureTheFlag"
				then "capturas"
				elseif mode == "KingOfTheHill" then "segundos en la colina"
				else "bajas"
			local rules = Modes[mode]
			goal.Text = string.format(
				"%s · Primero en %d %s",
				if rules and rules.name then rules.name else "",
				ReplicatedStorage:GetAttribute("MatchScoreToWin") or 0,
				unit
			)
			banner.Text = ""
		elseif phase == "Countdown" then
			timer.Text = "--:--"
			goal.Text = ""
			banner.Text = string.format(
				"La partida empieza en %d",
				ReplicatedStorage:GetAttribute("MatchCountdown") or 0
			)
		elseif phase == "Waiting" then
			timer.Text = "--:--"
			goal.Text = ""
			banner.Text = string.format(
				"Esperando jugadores (%d/%d)",
				#Players:GetPlayers(),
				ReplicatedStorage:GetAttribute("MatchPlayersNeeded") or 2
			)
		else
			banner.Text = "" -- en "Ended" manda la pantalla de resultados
		end
	end)
end

return Scoreboard
