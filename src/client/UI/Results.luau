-- Pantalla de resultados al terminar la partida: quién ganó, el marcador final
-- y la tabla de jugadores con sus bajas y muertes. Se quita al empezar la siguiente.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local matchState = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MatchState") :: RemoteEvent

local player = Players.LocalPlayer

local Results = {}

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
	gui.DisplayOrder = 20 -- encima del HUD
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(460, 380)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	panel.BackgroundTransparency = 0.15
	panel.Parent = gui
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

		-- Encabezado y una fila por jugador
		local function row(name: string, kills: string, deaths: string, color: Color3?, textSize: number)
			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(1, 0, 0, 24)
			frame.BackgroundTransparency = 1
			frame.Parent = panel
			local n = label(frame, name, UDim2.new(0.6, 0, 1, 0), textSize, color)
			n.TextXAlignment = Enum.TextXAlignment.Left
			local k = label(frame, kills, UDim2.new(0.2, 0, 1, 0), textSize)
			k.Position = UDim2.fromScale(0.6, 0)
			local d = label(frame, deaths, UDim2.new(0.2, 0, 1, 0), textSize)
			d.Position = UDim2.fromScale(0.8, 0)
			add(frame)
		end
		row("Jugador", "Bajas", "Muertes", Color3.fromRGB(180, 180, 180), 14)
		for i, entry in data.players do
			if i > 10 then
				break
			end
			row(entry.name, tostring(entry.kills), tostring(entry.deaths), entry.color, 18)
		end
		gui.Enabled = true
	end)
end

return Results
