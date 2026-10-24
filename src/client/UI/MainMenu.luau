-- Menú de partidas: aparece al entrar al juego (en un servidor normal) con tres botones:
--   Partida rápida   cierra el menú y juegas aquí (modo al azar; si falta gente, hay bots)
--   Contra la IA     eliges un modo y vas a un servidor solo para ti (y tus amigos) contra bots
--   Partida privada  eliges modo y mapa, y vas a un servidor para jugar con tus amigos
-- Se vuelve a abrir con el botón "Menú (M)" o la tecla M.
--
-- En una partida contra la IA o privada, en vez del menú hay dos botones: "Invitar amigos"
-- (la ventana de invitaciones de Roblox) y "Salir a partida rápida".
-- El menú solo pide cosas al servidor (RemoteEvent "RequestMatch"); el que crea la partida y
-- teletransporta es el servidor (ver MatchSettings).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local UserInputService = game:GetService("UserInputService")

local Bots = require(ReplicatedStorage.Shared.Config.Bots)
local Maps = require(ReplicatedStorage.Shared.Config.Maps)
local Modes = require(ReplicatedStorage.Shared.Config.Modes)

local requestMatch = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestMatch") :: RemoteEvent

local player = Players.LocalPlayer

local BACKGROUND = Color3.fromRGB(24, 26, 30)
local CARD = Color3.fromRGB(52, 56, 64)
local ACCENT = Color3.fromRGB(230, 170, 50)
local AI_COLOR = Color3.fromRGB(60, 120, 170)
local PRIVATE_COLOR = Color3.fromRGB(60, 140, 70)
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(180, 184, 190)

local MainMenu = {}

local backdrop: TextButton
local title: TextLabel
local subtitle: TextLabel
local status: TextLabel
local content: ScrollingFrame
local backButton: TextButton
local busy = false -- esperando el teletransporte
local goBack: (() -> ())? = nil -- qué hace el botón "Atrás" en la página actual

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function newLabel(parent: Instance, text: string, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, textSize + 8)
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function newButton(parent: Instance, text: string, size: UDim2, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.BackgroundColor3 = color
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextSize = 16
	button.TextColor3 = TEXT
	button.TextWrapped = true
	button.AutoButtonColor = true
	button.Parent = parent
	corner(button, 8)
	return button
end

local function setOpen(open: boolean)
	backdrop.Visible = open
end

local function clearContent()
	for _, child in content:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- Una cuadrícula de botones, uno por opción
local function showGrid(options: { { text: string, color: Color3?, onClick: () -> () } }, tall: boolean?)
	clearContent()
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = if tall then UDim2.new(1, 0, 0, 64) else UDim2.new(0.5, -6, 0, 44)
	grid.CellPadding = UDim2.fromOffset(12, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = content
	for i, option in options do
		local button = newButton(content, option.text, UDim2.fromOffset(0, 0), option.color or CARD)
		button.LayoutOrder = i
		button.Activated:Connect(function()
			if not busy then
				option.onClick()
			end
		end)
	end
end

local function ask(kind: string, modeName: string, mapName: string?, difficulty: string?)
	busy = true
	status.TextColor3 = ACCENT
	status.Text = "Creando la partida..."
	requestMatch:FireServer(kind, modeName, mapName, difficulty)
	-- Si el servidor no contesta (por ejemplo, ignoró un pedido muy seguido), se desbloquea
	task.delay(12, function()
		if busy then
			busy = false
			status.Text = ""
		end
	end)
end

local showHome: () -> ()
local showPrivateMode: () -> ()

local function page(heading: string, help: string, onBack: (() -> ())?)
	title.Text = heading
	subtitle.Text = help
	if not busy then
		status.Text = ""
	end
	goBack = onBack
	backButton.Visible = onBack ~= nil
end

local function modeOptions(filter: (any) -> boolean, onPick: (string) -> ())
	local options = {}
	for _, name in Modes.randomPool do
		local mode = Modes[name]
		if mode and filter(mode) then
			table.insert(options, {
				text = mode.name,
				onClick = function()
					onPick(name)
				end,
			})
		end
	end
	return options
end

local function showAI()
	page("Contra la IA", "Elige el modo. Tú (y los amigos que invites) contra bots.", showHome)
	showGrid(modeOptions(function(mode)
		return mode.bots == true or mode.botZombies == true
	end, function(name)
		page("Contra la IA · " .. Modes[name].name, "Elige qué tan buenos son los bots.", showAI)
		local colors = {
			Color3.fromRGB(70, 150, 80),
			Color3.fromRGB(60, 120, 170),
			Color3.fromRGB(200, 120, 40),
			Color3.fromRGB(180, 50, 50),
		}
		local options = {}
		for i, key in Bots.difficultyOrder do
			table.insert(options, {
				text = Bots.difficulties[key].name,
				color = colors[i],
				onClick = function()
					ask("ai", name, nil, key)
				end,
			})
		end
		showGrid(options)
	end))
end

local function showPrivateMap(modeName: string)
	page(
		"Partida privada · " .. Modes[modeName].name,
		"Elige el mapa. Después podrás invitar a tus amigos.",
		showPrivateMode
	)
	local names = {}
	for key in Maps.list do
		table.insert(names, key)
	end
	table.sort(names, function(a, b)
		return Maps.list[a] < Maps.list[b]
	end)
	local options = {
		{
			text = "Aleatorio",
			color = ACCENT,
			onClick = function()
				ask("private", modeName, nil)
			end,
		},
	}
	for _, key in names do
		table.insert(options, {
			text = Maps.list[key],
			onClick = function()
				ask("private", modeName, key)
			end,
		})
	end
	showGrid(options)
end

function showPrivateMode()
	page("Partida privada", "Elige el modo para jugar con tus amigos.", showHome)
	showGrid(modeOptions(function()
		return true
	end, showPrivateMap))
end

function showHome()
	page("ZONA CERO", "¿Cómo quieres jugar?", nil)
	showGrid({
		{
			text = "Partida rápida\nJuega ya: modo al azar y bots si falta gente",
			color = ACCENT,
			onClick = function()
				setOpen(false)
			end,
		},
		{ text = "Contra la IA\nTú y tus amigos contra bots", color = AI_COLOR, onClick = showAI },
		{
			text = "Partida privada\nElige modo y mapa e invita a tus amigos",
			color = PRIVATE_COLOR,
			onClick = showPrivateMode,
		},
	}, true)
end

-- La ventana de invitaciones de Roblox. La invitación lleva el código de esta partida
local function inviteFriends()
	local code = ReplicatedStorage:GetAttribute("InviteCode")
	local ok, canSend = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if not ok or not canSend then
		return
	end
	local options = Instance.new("ExperienceInviteOptions")
	options.PromptMessage = "¡Ven a jugar conmigo a Zona Cero!"
	if type(code) == "string" then
		options.LaunchData = HttpService:JSONEncode({ join = code })
	end
	pcall(SocialService.PromptGameInvite, SocialService, player, options)
end

-- Los botones de la izquierda: "Menú (M)" en una partida rápida; "Iniciar partida" (solo el
-- anfitrión, antes de la primera), "Invitar amigos" y "Salir a partida rápida" en una
-- partida contra la IA o privada
local function buildSideButtons(gui: ScreenGui, kind: string)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	-- Debajo del botón de la tienda (centrado en 0.4 de la altura y de 36 de alto)
	holder.AnchorPoint = Vector2.new(0, 0)
	holder.Position = UDim2.new(0, 16, 0.4, 26)
	holder.Size = UDim2.fromOffset(230, 160)
	holder.Parent = gui
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = holder
	local size = UDim2.fromOffset(230, 36)
	if kind == "public" then
		local menuButton = newButton(holder, "Menú (M)", size, BACKGROUND)
		menuButton.BackgroundTransparency = 0.2
		menuButton.TextSize = 14
		menuButton.Activated:Connect(function()
			showHome()
			setOpen(not backdrop.Visible)
		end)
		UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == Enum.KeyCode.M then
				showHome()
				setOpen(not backdrop.Visible)
			end
		end)
		return
	end
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(230, 18)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = TEXT
	label.TextStrokeTransparency = 0.5
	label.TextXAlignment = Enum.TextXAlignment.Left
	local mode = Modes[ReplicatedStorage:GetAttribute("ServerMode") or ""]
	local modeName = if type(mode) == "table" and mode.name then mode.name else ""
	label.Text = (if kind == "ai" then "Contra la IA · " else "Partida privada · ") .. modeName
	local difficulty = Bots.difficulties[ReplicatedStorage:GetAttribute("ServerDifficulty") or ""]
	if kind == "ai" and difficulty then
		label.Text ..= " · " .. difficulty.name
	end
	label.LayoutOrder = 1
	label.Parent = holder
	-- Solo el anfitrión, y solo antes de la primera partida: la sala espera a que lo apriete
	-- (así alcanzan a llegar los amigos invitados)
	local start = newButton(holder, "Iniciar partida", size, AI_COLOR)
	start.TextSize = 14
	start.LayoutOrder = 2
	start.Activated:Connect(function()
		requestMatch:FireServer("start")
	end)
	local function updateStart()
		start.Visible = ReplicatedStorage:GetAttribute("WaitingForHost") == true
			and ReplicatedStorage:GetAttribute("HostUserId") == player.UserId
	end
	ReplicatedStorage:GetAttributeChangedSignal("WaitingForHost"):Connect(updateStart)
	ReplicatedStorage:GetAttributeChangedSignal("HostUserId"):Connect(updateStart)
	updateStart()
	local invite = newButton(holder, "Invitar amigos", size, PRIVATE_COLOR)
	invite.TextSize = 14
	invite.LayoutOrder = 3
	invite.Activated:Connect(inviteFriends)
	local leave = newButton(holder, "Salir a partida rápida", size, BACKGROUND)
	leave.BackgroundTransparency = 0.2
	leave.TextSize = 14
	leave.LayoutOrder = 4
	leave.Activated:Connect(function()
		leave.Text = "Saliendo..."
		requestMatch:FireServer("leave")
	end)
end

local function build(kind: string)
	local gui = Instance.new("ScreenGui")
	gui.Name = "MainMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Fondo oscuro de toda la pantalla. Modal = true suelta el mouse aunque estés en primera
	-- persona, y como es un botón, los clics no disparan el arma
	backdrop = Instance.new("TextButton")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.35
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Modal = true
	backdrop.Visible = false
	backdrop.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0, 480, 0, 460)
	panel.BackgroundColor3 = BACKGROUND
	panel.Parent = backdrop
	corner(panel, 12)
	local sizeLimit = Instance.new("UISizeConstraint") -- en pantallas pequeñas se encoge
	sizeLimit.MaxSize = Vector2.new(480, 460)
	sizeLimit.Parent = panel
	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(padding :: any)[side] = UDim.new(0, 18)
	end
	padding.Parent = panel

	title = newLabel(panel, "", 26, TEXT)
	subtitle = newLabel(panel, "", 14, MUTED)
	subtitle.Position = UDim2.fromOffset(0, 36)

	content = Instance.new("ScrollingFrame")
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 4
	content.CanvasSize = UDim2.new()
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.Position = UDim2.fromOffset(0, 70)
	content.Size = UDim2.new(1, 0, 1, -140)
	content.Parent = panel

	status = newLabel(panel, "", 14, ACCENT)
	status.AnchorPoint = Vector2.new(0, 1)
	status.Position = UDim2.new(0, 0, 1, -44)

	backButton = newButton(panel, "Atrás", UDim2.fromOffset(120, 36), CARD)
	backButton.AnchorPoint = Vector2.new(0, 1)
	backButton.Position = UDim2.fromScale(0, 1)
	backButton.TextSize = 14
	backButton.Activated:Connect(function()
		if goBack and not busy then
			goBack()
		end
	end)

	buildSideButtons(gui, kind)
	showHome()
end

-- Lo que contesta el servidor: "teleporting" o ("error", mensaje)
local function onServerReply(state: string, message: string?)
	if not backdrop then
		return
	end
	if state == "teleporting" then
		busy = true
		status.TextColor3 = ACCENT
		status.Text = "Entrando a la partida..."
		setOpen(true)
	elseif state == "error" then
		busy = false
		status.TextColor3 = Color3.fromRGB(240, 110, 100)
		status.Text = message or "Algo salió mal."
		setOpen(true)
	end
end

function MainMenu.Start()
	task.spawn(function()
		-- Espera a saber qué clase de servidor es (un servidor reservado tarda un momento)
		local kind = ReplicatedStorage:GetAttribute("ServerKind")
		local waited = 0
		while (kind == nil or kind == "loading") and waited < 15 do
			task.wait(0.25)
			waited += 0.25
			kind = ReplicatedStorage:GetAttribute("ServerKind")
		end
		build(if type(kind) == "string" and kind ~= "loading" then kind else "public")
		requestMatch.OnClientEvent:Connect(onServerReply)
		setOpen(kind == "public" or kind == nil) -- al entrar a una partida rápida, el menú
	end)
end

return MainMenu
