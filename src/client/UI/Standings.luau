-- La tabla de puntajes: todos los que juegan (jugadores y bots) con sus bajas, asistencias y
-- muertes, ordenados de mejor a peor y con el color de su equipo (verde si es zombi).
--
-- Reemplaza a la lista de jugadores de Roblox, que no muestra a los bots y que se abría y
-- cerraba por su lado. Se muestra y se esconde junto con el cuadro de controles (ver
-- Controls: Tab, cruceta ← o el botón "Controles" en móvil).
-- Los datos salen del leaderstats de cada jugador y del carnet de cada bot
-- (ReplicatedStorage.Bots), que el servidor ya mantiene al día.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Teams = game:GetService("Teams")

local player = Players.LocalPlayer

local TEXT = Color3.fromRGB(235, 235, 235)
local MUTED = Color3.fromRGB(170, 170, 170)
local ZOMBIE_GREEN = Color3.fromRGB(120, 220, 90)
local NO_TEAM = Color3.fromRGB(235, 235, 235)
local REFRESH_EVERY = 0.5 -- segundos
local MAX_ROWS = 16

local Standings = {}

local panel: Frame
local rows: Frame
local visible = false

local function stat(who: Instance, name: string): number
	local leaderstats = who:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild(name)
	return if value and value:IsA("IntValue") then value.Value else 0
end

local function colorOf(who: Instance): Color3
	if who:GetAttribute("Side") == "Zombie" then
		return ZOMBIE_GREEN
	end
	local team: Team? = nil
	if who:IsA("Player") then
		team = if who.Neutral then nil else who.Team
	else
		local name = who:GetAttribute("Team")
		local found = name and Teams:FindFirstChild(name)
		team = if found and found:IsA("Team") then found else nil
	end
	return if team then team.TeamColor.Color else NO_TEAM
end

local function cell(parent: Instance, text: string, x: number, width: number, color: Color3, bold: boolean)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(x, 0)
	label.Size = UDim2.fromScale(width, 1)
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	label.TextSize = 15
	label.TextColor3 = color
	label.TextXAlignment = if x == 0 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = text
	label.Parent = parent
end

local function row(order: number, name: string, k: string, a: string, d: string, color: Color3, mine: boolean)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 22)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = if mine then 0.88 else 1 -- tu fila se marca
	frame.BorderSizePixel = 0
	frame.LayoutOrder = order
	frame.Parent = rows
	cell(frame, name, 0, 0.52, color, mine)
	cell(frame, k, 0.52, 0.16, TEXT, mine)
	cell(frame, a, 0.68, 0.16, TEXT, mine)
	cell(frame, d, 0.84, 0.16, TEXT, mine)
end

local function refresh()
	for _, child in rows:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	row(0, "Jugador", "Bajas", "Asist.", "Muertes", MUTED, false)
	local everyone: { Instance } = {}
	for _, other in Players:GetPlayers() do
		table.insert(everyone, other)
	end
	local cards = ReplicatedStorage:FindFirstChild("Bots")
	if cards then
		for _, card in cards:GetChildren() do
			table.insert(everyone, card)
		end
	end
	table.sort(everyone, function(a, b)
		local ka, kb = stat(a, "Bajas"), stat(b, "Bajas")
		if ka ~= kb then
			return ka > kb
		end
		return stat(a, "Muertes") < stat(b, "Muertes")
	end)
	for i, who in everyone do
		if i > MAX_ROWS then
			break
		end
		local name = if who:IsA("Player") then who.DisplayName else who.Name
		row(
			i,
			name,
			tostring(stat(who, "Bajas")),
			tostring(stat(who, "Asistencias")),
			tostring(stat(who, "Muertes")),
			colorOf(who),
			who == player
		)
	end
end

function Standings.SetVisible(show: boolean)
	visible = show
	panel.Visible = show
	if show then
		refresh()
	end
end

function Standings.Start()
	-- La lista de Roblox se apaga: esta la reemplaza (y así Tab no abre dos cosas distintas)
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)

	local gui = Instance.new("ScreenGui")
	gui.Name = "Standings"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- A la derecha, debajo del registro de bajas
	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -16, 0, 150)
	panel.Size = UDim2.fromOffset(340, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	panel.BackgroundTransparency = 0.35
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel
	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(padding :: any)[side] = UDim.new(0, 10)
	end
	padding.Parent = panel

	rows = Instance.new("Frame")
	rows.BackgroundTransparency = 1
	rows.Size = UDim2.fromScale(1, 0)
	rows.AutomaticSize = Enum.AutomaticSize.Y
	rows.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rows

	task.spawn(function()
		while true do
			task.wait(REFRESH_EVERY)
			if visible then
				refresh()
			end
		end
	end)
end

return Standings
