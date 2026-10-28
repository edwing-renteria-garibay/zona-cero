-- El menú de la tienda: se abre con la tecla B (o el botón "Tienda").
-- A la izquierda tu personaje girando con lo que llevas puesto; a la derecha las pestañas:
-- Casco, Torso, Brazos, Piernas, Skins de armas y Robux (pases de juego y paquetes de créditos).
-- También muestra el aviso del premio diario al entrar.
--
-- El menú solo pide cosas al servidor (RemoteFunction "Shop"): "get" para ver tu perfil,
-- "buy" para comprar y "equip" para ponerte o quitarte algo. El servidor decide y devuelve
-- el perfil actualizado, y con eso se vuelven a dibujar las tarjetas.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Mobile = require(script.Parent.Parent.Controllers.Mobile)

local shopRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop") :: RemoteFunction

local player = Players.LocalPlayer

local BACKGROUND = Color3.fromRGB(24, 26, 30)
local CARD = Color3.fromRGB(40, 43, 50)
local TAB = Color3.fromRGB(52, 56, 64)
local TAB_ACTIVE = Color3.fromRGB(230, 170, 50)
local BUY = Color3.fromRGB(60, 140, 70)
local EQUIP = Color3.fromRGB(60, 100, 170)
local EQUIPPED = Color3.fromRGB(90, 90, 96)
local LOCKED = Color3.fromRGB(110, 60, 60)
local TEXT = Color3.new(1, 1, 1)

local ShopUI = {}

type Profile = { credits: number, owned: { [string]: boolean }, equipped: { [string]: string } }

local gui: ScreenGui
local backdrop: TextButton
local grid: ScrollingFrame
local creditsLabel: TextLabel
local openButton: TextButton
local viewport: ViewportFrame
local world: WorldModel
local tabButtons: { [string]: TextButton } = {}

local profile: Profile? = nil
local currentTab = "Helmet"
local previewModel: Model? = nil
local previewAngle = 0
local busy = false -- esperando la respuesta del servidor

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function newLabel(parent: Instance, text: string, size: UDim2, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextSize = textSize
	label.TextColor3 = TEXT
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
	button.TextSize = 14
	button.TextColor3 = TEXT
	button.AutoButtonColor = true
	button.Parent = parent
	corner(button, 6)
	return button
end

local function credits(): number
	return player:GetAttribute("Credits") or (profile and profile.credits) or 0
end

local function updateCredits()
	creditsLabel.Text = string.format("%d créditos", credits())
	-- En celular no hay tecla B
	local format = if Mobile.IsTouch() then "Tienda · %d créditos" else "Tienda (B) · %d créditos"
	openButton.Text = string.format(format, credits())
end

-- La vista previa: una copia de tu personaje dentro del ViewportFrame
local function refreshPreview()
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end
	local character = player.Character
	if not character then
		return
	end
	local archivable = character.Archivable
	character.Archivable = true -- sin esto Roblox no deja copiar al personaje
	local copy = character:Clone()
	character.Archivable = archivable
	if not copy then
		return
	end
	for _, item in copy:GetDescendants() do
		if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("Sound") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = true
			-- En primera persona tu cuerpo está escondido; en la copia se ve
			item.LocalTransparencyModifier = 0
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	copy:PivotTo(CFrame.new())
	copy.Parent = world
	previewModel = copy
end

-- Pide algo al servidor y redibuja con el perfil que devuelve
local redraw: () -> ()
local function request(action: string, itemId: string?)
	if busy then
		return
	end
	busy = true
	local ok, result = pcall(function()
		return shopRemote:InvokeServer(action, itemId)
	end)
	busy = false
	if ok and result then
		profile = result
	end
	redraw()
	if action ~= "get" then
		task.delay(0.4, refreshPreview) -- da tiempo a que llegue la armadura nueva
	end
end

local function clearGrid()
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- Una tarjeta: muestra de colores, nombre y el botón (precio, Equipar, Equipado...)
local function card(
	name: string,
	colors: { Color3 },
	buttonText: string,
	buttonColor: Color3,
	onClick: (() -> ())?
)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = CARD
	frame.Parent = grid
	corner(frame, 8)
	local swatch = Instance.new("Frame")
	swatch.Size = UDim2.new(1, -16, 0, 60)
	swatch.Position = UDim2.fromOffset(8, 8)
	swatch.BackgroundColor3 = colors[1] or CARD
	swatch.Parent = frame
	corner(swatch, 6)
	-- Franjas con los demás colores del estilo
	for i = 2, #colors do
		local stripe = Instance.new("Frame")
		stripe.Size = UDim2.new(0.25, 0, 1, 0)
		stripe.Position = UDim2.new(1 - 0.25 * (#colors - i + 1), 0, 0, 0)
		stripe.BackgroundColor3 = colors[i]
		stripe.BorderSizePixel = 0
		stripe.Parent = swatch
	end
	local label = newLabel(frame, name, UDim2.new(1, -8, 0, 30), 15)
	label.Position = UDim2.fromOffset(4, 72)
	local button = newButton(frame, buttonText, UDim2.new(1, -16, 0, 32), buttonColor)
	button.Position = UDim2.new(0, 8, 1, -40)
	-- Los textos largos ("Comprar: 1500 créditos") se achican para caber en la tarjeta
	for _, item in { label, button } do
		local maxSize = item.TextSize
		item.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = maxSize
		limit.Parent = item
	end
	if onClick then
		button.Activated:Connect(onClick)
	else
		button.AutoButtonColor = false
	end
end

-- Compra de un pase de juego (Config/Shop.gamePasses). La ventana es de Roblox; cuando
-- termina, el servidor da el pase y la tienda se redibuja sola (atributo "Pass_...")
local function findPass(key: string)
	for _, pass in Shop.gamePasses do
		if pass.key == key then
			return pass
		end
	end
	return nil
end

local function promptPass(key: string)
	local pass = findPass(key)
	if pass and pass.id ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, pass.id)
	end
end

-- Botón de una cosa que solo se consigue con un pase
local function passCard(name: string, colors: { Color3 }, key: string)
	local pass = findPass(key)
	if not pass or pass.id == 0 then
		card(name, colors, "Próximamente", EQUIPPED, nil)
		return
	end
	card(name, colors, string.format("%s: %d Robux", pass.name, pass.robux), TAB_ACTIVE, function()
		promptPass(key)
	end)
end

local function drawArmorTab(slotId: string, data: Profile)
	local equipped = data.equipped[slotId]
	card(
		"Sin armadura",
		{ CARD },
		if equipped == nil then "Puesto" else "Quitar",
		if equipped == nil then EQUIPPED else EQUIP,
		if equipped == nil
			then nil
			else function()
				request("equip", slotId .. ".")
			end
	)
	for _, style in Shop.armor do
		local itemId = slotId .. "." .. style.id
		local colors = { style.primary, style.secondary, style.accent }
		if equipped == style.id then
			card(style.name, colors, "Puesto", EQUIPPED, nil)
		elseif data.owned[itemId] then
			card(style.name, colors, "Ponerse", EQUIP, function()
				request("equip", itemId)
			end)
		elseif style.pass then
			passCard(style.name, colors, style.pass)
		elseif credits() >= style.price then
			card(style.name, colors, string.format("Comprar: %d créditos", style.price), BUY, function()
				request("buy", itemId)
			end)
		else
			card(style.name, colors, string.format("%d créditos", style.price), LOCKED, nil)
		end
	end
end

local function drawSkinsTab(data: Profile)
	local equipped = data.equipped.Skin
	card(
		"Original",
		{ Color3.fromRGB(44, 44, 42) },
		if equipped == nil then "Puesta" else "Usar",
		if equipped == nil then EQUIPPED else EQUIP,
		if equipped == nil
			then nil
			else function()
				request("equip", "Skin.")
			end
	)
	for _, skin in Shop.weaponSkins do
		local itemId = "Skin." .. skin.id
		if equipped == skin.id then
			card(skin.name, { skin.color }, "Puesta", EQUIPPED, nil)
		elseif data.owned[itemId] then
			card(skin.name, { skin.color }, "Usar", EQUIP, function()
				request("equip", itemId)
			end)
		elseif skin.pass then
			passCard(skin.name, { skin.color }, skin.pass)
		elseif credits() >= skin.price then
			card(
				skin.name,
				{ skin.color },
				string.format("Comprar: %d créditos", skin.price),
				BUY,
				function()
					request("buy", itemId)
				end
			)
		else
			card(skin.name, { skin.color }, string.format("%d créditos", skin.price), LOCKED, nil)
		end
	end
end

local function drawCreditsTab()
	-- Primero los pases (para siempre), luego los paquetes de créditos
	for _, pass in Shop.gamePasses do
		local name = string.format("%s · %s", pass.name, pass.description)
		if player:GetAttribute("Pass_" .. pass.key) then
			card(name, { pass.color }, "Ya lo tienes", EQUIPPED, nil)
		elseif pass.id == 0 then
			card(name, { pass.color }, "Próximamente", EQUIPPED, nil)
		else
			card(name, { pass.color }, string.format("%d Robux", pass.robux), BUY, function()
				promptPass(pass.key)
			end)
		end
	end
	for _, pack in Shop.creditPacks do
		local name = string.format("%d créditos por %d Robux", pack.credits, pack.robux)
		if pack.productId == 0 then
			card(name, { TAB_ACTIVE }, "Próximamente", EQUIPPED, nil)
		else
			card(name, { TAB_ACTIVE }, "Comprar", BUY, function()
				MarketplaceService:PromptProductPurchase(player, pack.productId)
			end)
		end
	end
end

redraw = function()
	for id, button in tabButtons do
		button.BackgroundColor3 = if id == currentTab then TAB_ACTIVE else TAB
	end
	updateCredits()
	clearGrid()
	local data = profile
	if not data then
		local label = newLabel(grid, "Cargando...", UDim2.new(1, 0, 0, 40), 18)
		label.LayoutOrder = 1
		return
	end
	if currentTab == "Skin" then
		drawSkinsTab(data)
	elseif currentTab == "Credits" then
		drawCreditsTab()
	else
		drawArmorTab(currentTab, data)
	end
end

local function setOpen(open: boolean)
	backdrop.Visible = open
	-- Lo leen la cámara y la mira para soltar el mouse mientras el menú está abierto
	player:SetAttribute("MenuOpen", open or nil)
	if open then
		refreshPreview()
		task.spawn(request, "get")
		-- Con control no hay mouse: seleccionamos un botón para moverse con el stick
		for _, item in backdrop:GetDescendants() do
			if item:IsA("GuiButton") and item.Visible then
				GuiService.SelectedObject = item
				break
			end
		end
	elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(backdrop) then
		GuiService.SelectedObject = nil
	end
end

local function onToggle(_name: string, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	setOpen(not backdrop.Visible)
	return Enum.ContextActionResult.Sink
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "Shop"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")

	openButton = newButton(gui, "Tienda (B)", UDim2.fromOffset(230, 36), BACKGROUND)
	openButton.AnchorPoint = Vector2.new(0, 0.5)
	openButton.Position = UDim2.new(0, 16, 0.4, 0)
	openButton.BackgroundTransparency = 0.2
	if Mobile.IsTouch() then
		-- En celular, arriba a la izquierda y más pequeño: el centro-izquierda es del stick
		openButton.AnchorPoint = Vector2.new(0, 0)
		openButton.Position = UDim2.fromOffset(12, 6)
		openButton.Size = UDim2.fromOffset(170, 28)
		openButton.TextSize = 12
	end
	openButton.Activated:Connect(function()
		setOpen(not backdrop.Visible)
	end)

	-- Fondo oscuro de toda la pantalla. Modal = true suelta el mouse aunque estés en primera
	-- persona, y como es un botón, los clics no disparan el arma
	backdrop = Instance.new("TextButton")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Modal = true
	backdrop.Visible = false
	backdrop.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.94, 0.88)
	panel.BackgroundColor3 = BACKGROUND
	panel.Parent = backdrop
	corner(panel, 12)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(880, 540)
	limit.Parent = panel

	local title = newLabel(panel, "Tienda", UDim2.fromOffset(200, 40), 26)
	title.Position = UDim2.fromOffset(16, 8)
	title.TextXAlignment = Enum.TextXAlignment.Left
	creditsLabel = newLabel(panel, "", UDim2.new(0, 160, 0, 40), 22)
	creditsLabel.AnchorPoint = Vector2.new(1, 0)
	creditsLabel.Position = UDim2.new(1, -64, 0, 8)
	creditsLabel.TextColor3 = TAB_ACTIVE
	creditsLabel.TextXAlignment = Enum.TextXAlignment.Right
	local close = newButton(panel, "X", UDim2.fromOffset(36, 36), LOCKED)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 10)
	close.Activated:Connect(function()
		setOpen(false)
	end)

	-- Vista previa a la izquierda
	viewport = Instance.new("ViewportFrame")
	viewport.Position = UDim2.fromOffset(16, 56)
	viewport.Size = UDim2.new(0.32, -16, 1, -72)
	viewport.BackgroundColor3 = CARD
	viewport.Ambient = Color3.fromRGB(150, 150, 150)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.Parent = panel
	corner(viewport, 8)
	world = Instance.new("WorldModel")
	world.Parent = viewport
	local camera = Instance.new("Camera")
	-- El personaje mira hacia -Z: la cámara se pone enfrente. El centro del personaje (0, 0, 0)
	-- está a la altura de la cintura; los pies quedan unos 3 studs abajo
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.5, -11), Vector3.new(0, -0.3, 0))
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	-- Pestañas
	local tabs = Instance.new("Frame")
	tabs.BackgroundTransparency = 1
	tabs.Position = UDim2.new(0.32, 12, 0, 56)
	tabs.Size = UDim2.new(0.68, -28, 0, 34)
	tabs.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabs
	local tabList = {}
	for _, slot in Shop.slots do
		table.insert(tabList, { id = slot.id, name = slot.name })
	end
	table.insert(tabList, { id = "Skin", name = "Skins" })
	table.insert(tabList, { id = "Credits", name = "Robux" })
	for i, tab in tabList do
		local button = newButton(tabs, tab.name, UDim2.new(1 / #tabList, -6, 1, 0), TAB)
		button.LayoutOrder = i
		button.TextScaled = true
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 4)
		padding.PaddingRight = UDim.new(0, 4)
		padding.PaddingTop = UDim.new(0, 6)
		padding.PaddingBottom = UDim.new(0, 6)
		padding.Parent = button
		tabButtons[tab.id] = button
		button.Activated:Connect(function()
			currentTab = tab.id
			redraw()
		end)
	end

	-- Las tarjetas
	grid = Instance.new("ScrollingFrame")
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.new(0.32, 12, 0, 100)
	grid.Size = UDim2.new(0.68, -28, 1, -116)
	grid.ScrollBarThickness = 6
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = panel
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(150, 150)
	gridLayout.CellPadding = UDim2.fromOffset(10, 10)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid
end

-- Aviso del premio diario: un letrero arriba que se va solo
local function showDaily()
	local reward = player:GetAttribute("DailyReward")
	if type(reward) ~= "number" then
		return
	end
	local streak = player:GetAttribute("DailyStreak") or 1
	local text = string.format("Premio diario: +%d créditos", reward)
	if streak > 1 then
		text ..= string.format("  ·  %d días seguidos", streak)
	end
	if player:GetAttribute("Pass_VIP") then
		text ..= "  ·  VIP x2"
	end
	local toast = newLabel(gui, text, UDim2.fromOffset(460, 44), 18)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 70)
	toast.BackgroundColor3 = BACKGROUND
	toast.BackgroundTransparency = 0.15
	toast.TextColor3 = TAB_ACTIVE
	corner(toast, 8)
	task.delay(6, function()
		toast:Destroy()
	end)
end

function ShopUI.Start()
	build()
	updateCredits()
	showDaily()
	player:GetAttributeChangedSignal("DailyReward"):Connect(showDaily)
	-- Al comprar un pase se redibuja (aparece "Ya lo tienes" y lo nuevo para ponerse)
	for _, pass in Shop.gamePasses do
		player:GetAttributeChangedSignal("Pass_" .. pass.key):Connect(function()
			if backdrop.Visible then
				task.spawn(request, "get")
			end
		end)
	end
	player:GetAttributeChangedSignal("Credits"):Connect(function()
		updateCredits()
		if backdrop.Visible and profile then
			redraw() -- puede que ya te alcance para algo
		end
	end)
	-- En control: flecha abajo del D-pad
	ContextActionService:BindAction("Shop", onToggle, false, Enum.KeyCode.B, Enum.KeyCode.DPadDown)
	ContextActionService:SetTitle("Shop", "Tienda")

	-- La vista previa gira despacio
	RunService.RenderStepped:Connect(function(dt)
		if backdrop.Visible and previewModel then
			previewAngle += dt * 0.8
			previewModel:PivotTo(CFrame.Angles(0, previewAngle, 0))
		end
	end)
	-- Al reaparecer con el menú abierto, la copia se actualiza
	player.CharacterAdded:Connect(function()
		if backdrop.Visible then
			task.delay(1, refreshPreview)
		end
	end)
end

return ShopUI
