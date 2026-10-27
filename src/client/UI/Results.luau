-- Pantalla de resultados al terminar la partida: quién ganó, el marcador final, el podio con
-- los 3 mejores (MVP) y la tabla de jugadores con sus bajas, asistencias y muertes. Suena victoria o
-- derrota según tu lado. Se quita al empezar la siguiente.
-- También los sonidos del principio y del final: la cuenta 3, 2, 1 y la canción de inicio
-- (3 s, o hasta el primer disparo), y la cuenta final cuando faltan 5 s.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Mobile = require(script.Parent.Parent.Controllers.Mobile)
local Sfx = require(script.Parent.Parent.Controllers.Sfx)

local matchState = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MatchState") :: RemoteEvent
local shotFired = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShotFired") :: RemoteEvent

local player = Players.LocalPlayer

local Results = {}

local START_SONG_TIME = 3 -- segundos que suena la canción de inicio (si nadie dispara antes)
local FINAL_COUNTDOWN = 5 -- cuando faltan estos segundos suena la cuenta final

-- Un sonido que se puede detener (los de Sfx.PlayLocal no se pueden parar)
local function stoppable(soundId: string): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 0.6
	sound.Parent = SoundService
	return sound
end

local startSong = stoppable(Sounds.countdown.start)
local finalCountdown = stoppable(Sounds.matchEnd.finished)
local matchNumber = 0 -- cambia en cada partida, para que lo de una no afecte a la siguiente

-- Canción de inicio: suena START_SONG_TIME segundos, o hasta que alguien dispare
local function playStartSong()
	local thisMatch = matchNumber
	startSong.TimePosition = 0
	startSong:Play()
	local connection
	connection = shotFired.OnClientEvent:Connect(function()
		startSong:Stop()
		connection:Disconnect()
	end)
	task.delay(START_SONG_TIME, function()
		connection:Disconnect()
		if matchNumber == thisMatch then
			startSong:Stop()
		end
	end)
end

-- Cuenta final: cuando faltan FINAL_COUNTDOWN segundos para que se acabe el tiempo
local function scheduleFinalCountdown()
	local thisMatch = matchNumber
	task.spawn(function()
		while matchNumber == thisMatch and ReplicatedStorage:GetAttribute("MatchPhase") == "Playing" do
			local endsAt = ReplicatedStorage:GetAttribute("MatchEndsAt") or 0
			if endsAt - workspace:GetServerTimeNow() <= FINAL_COUNTDOWN then
				finalCountdown.TimePosition = 0
				finalCountdown:Play()
				return
			end
			task.wait(0.1)
		end
	end)
end

local MEDALS = {
	Color3.fromRGB(255, 200, 60), -- oro
	Color3.fromRGB(200, 205, 215), -- plata
	Color3.fromRGB(205, 130, 70), -- bronce
}

local function label(parent: Instance, text: string, size: UDim2, textSize: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = size
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = textSize
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.6
	l.Text = text
	l.Parent = parent
	return l
end

function Results.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Results"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 25 -- encima del HUD y de los botones del menú de partidas
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(480, 500)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	panel.BackgroundTransparency = 0.15
	panel.Parent = gui
	Mobile.FitToScreen(panel, 480, 500) -- en celular se encoge para caber completo
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 16)
	padding.PaddingLeft = UDim.new(0, 20)
	padding.PaddingRight = UDim.new(0, 20)
	padding.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = panel

	local function clear()
		for _, child in panel:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	matchState.OnClientEvent:Connect(function(state: string, data)
		-- Cuenta regresiva: "tres", "dos", "uno"... y "¡empieza!"
		if state == "Countdown" then
			Sfx.PlayLocal(Sounds.countdown[data])
		elseif state == "Started" then
			matchNumber += 1
			playStartSong()
			scheduleFinalCountdown()
		end
		if state ~= "Ended" then
			gui.Enabled = false
			return
		end
		clear()
		local order = 0
		local function add(item: GuiObject)
			order += 1
			item.LayoutOrder = order
		end

		local title = data.title or if data.winner then "¡Gana " .. data.winner .. "!" else "Empate"
		add(label(panel, title, UDim2.new(1, 0, 0, 44), 34, data.winnerColor))

		local scores = {}
		for _, team in data.teams do
			table.insert(
				scores,
				string.format('<font color="#%s">%s %d</font>', team.color:ToHex(), team.name, team.score)
			)
		end
		local scoreLine = label(panel, table.concat(scores, "   —   "), UDim2.new(1, 0, 0, 28), 22)
		scoreLine.RichText = true
		add(scoreLine)

		-- Podio: 2.º a la izquierda, 1.º en medio (más alto) y 3.º a la derecha
		local podium = Instance.new("Frame")
		podium.Size = UDim2.new(1, 0, 0, 110)
		podium.BackgroundTransparency = 1
		podium.Parent = panel
		add(podium)
		for column, place in { 2, 1, 3 } do
			local entry = data.players[place]
			if entry then
				local height = if place == 1 then 100 elseif place == 2 then 84 else 72
				local step = Instance.new("Frame")
				step.AnchorPoint = Vector2.new(0, 1)
				step.Position = UDim2.new((column - 1) / 3, 4, 1, 0)
				step.Size = UDim2.new(1 / 3, -8, 0, height)
				step.BackgroundColor3 = Color3.fromRGB(40, 40, 44)
				step.Parent = podium
				local stepCorner = Instance.new("UICorner")
				stepCorner.CornerRadius = UDim.new(0, 8)
				stepCorner.Parent = step
				local stroke = Instance.new("UIStroke")
				stroke.Color = MEDALS[place]
				stroke.Thickness = 2
				stroke.Parent = step
				local placeLabel = label(step, `{place}.º`, UDim2.new(1, 0, 0, 26), 22, MEDALS[place])
				placeLabel.Position = UDim2.fromOffset(0, 4)
				local nameLabel = label(step, entry.name, UDim2.new(1, -8, 0, 22), 15, entry.color)
				nameLabel.Position = UDim2.fromOffset(4, 30)
				nameLabel.TextScaled = true
				local killsLabel = label(
					step,
					`{entry.kills} bajas · {entry.assists or 0} asist.`,
					UDim2.new(1, 0, 0, 18),
					13
				)
				killsLabel.Position = UDim2.fromOffset(0, 54)
			end
		end

		-- Encabezado y una fila por jugador
		local function row(
			name: string,
			kills: string,
			assists: string,
			deaths: string,
			color: Color3?,
			textSize: number
		)
			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(1, 0, 0, 24)
			frame.BackgroundTransparency = 1
			frame.Parent = panel
			local n = label(frame, name, UDim2.new(0.46, 0, 1, 0), textSize, color)
			n.TextXAlignment = Enum.TextXAlignment.Left
			local k = label(frame, kills, UDim2.new(0.18, 0, 1, 0), textSize)
			k.Position = UDim2.fromScale(0.46, 0)
			local a = label(frame, assists, UDim2.new(0.18, 0, 1, 0), textSize)
			a.Position = UDim2.fromScale(0.64, 0)
			local d = label(frame, deaths, UDim2.new(0.18, 0, 1, 0), textSize)
			d.Position = UDim2.fromScale(0.82, 0)
			add(frame)
		end
		row("Jugador", "Bajas", "Asist.", "Muertes", Color3.fromRGB(180, 180, 180), 14)
		for i, entry in data.players do
			if i > 8 then
				break
			end
			row(
				entry.name,
				tostring(entry.kills),
				tostring(entry.assists or 0),
				tostring(entry.deaths),
				entry.color,
				18
			)
		end
		gui.Enabled = true

		-- Si se acabó antes de tiempo (alguien llegó a la meta), la cuenta final no aplica
		matchNumber += 1
		local endsAt = ReplicatedStorage:GetAttribute("MatchEndsAt") or 0
		if endsAt - workspace:GetServerTimeNow() > 1 then
			finalCountdown:Stop()
		end
		startSong:Stop()
		-- En seguida, la canción de victoria o de derrota (en un empate, ninguna)
		if data.winner then
			local won = table.find(data.winners or {}, player.Name) ~= nil
			Sfx.PlayLocal(if won then Sounds.matchEnd.win else Sounds.matchEnd.lose)
		end
	end)
end

return Results
