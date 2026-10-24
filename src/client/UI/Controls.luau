-- Los controles del juego, en un cuadro a la izquierda de la pantalla. Se muestran según con
-- qué estás jugando (teclado y mouse, control de Xbox o PlayStation, o pantalla táctil) y
-- cambian solos si cambias de uno a otro.
--
-- Se muestra y se esconde junto con la tabla de jugadores de Roblox:
--   PC: Tab (la misma tecla que la tabla). Empieza visible, como la tabla.
--   Control: cruceta ← (la tabla de Roblox no tiene botón en el control). Empieza escondido.
--   Móvil: el botón "Controles". Empieza escondido.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local TEXT = Color3.fromRGB(235, 235, 235)
local KEY = Color3.fromRGB(255, 200, 80)
local ROW_HEIGHT = 17

-- { tecla, qué hace }
local KEYBOARD = {
	{ "Clic izq.", "Disparar (y lanzar SimiOs)" },
	{ "Clic der.", "Apuntar con zoom" },
	{ "R", "Recargar" },
	{ "G", "Granada (mantén y suelta)" },
	{ "F", "Golpe" },
	{ "Shift", "Correr" },
	{ "Espacio", "Saltar" },
	{ "V", "Cámara 1.ª / 3.ª persona" },
	{ "1 - 9", "Elegir arma" },
	{ "E", "Cambiar arma del piso" },
	{ "B", "Tienda" },
	{ "M", "Menú de partidas" },
	{ "Tab", "Mostrar / ocultar" },
}

-- Xbox / PlayStation
local GAMEPAD = {
	{ "RT / R2", "Disparar (y lanzar SimiOs)" },
	{ "LT / L2", "Apuntar con zoom" },
	{ "X / Cuadrado", "Recargar" },
	{ "B / Círculo", "Granada (mantén y suelta)" },
	{ "R3", "Golpe" },
	{ "L3", "Correr" },
	{ "A / Equis", "Saltar" },
	{ "Y / Triángulo", "Cámara 1.ª / 3.ª persona" },
	{ "LB RB / L1 R1", "Elegir arma" },
	{ "Cruceta ↑", "Cambiar arma del piso" },
	{ "Cruceta ↓", "Tienda" },
	{ "Cruceta ←", "Mostrar / ocultar" },
}

local TOUCH = {
	{ "Stick izq.", "Moverte" },
	{ "Arrastrar", "Mirar" },
	{ "Tocar", "Disparar" },
	{ "Botones", "Recargar, Granada, Golpe," },
	{ "", "Correr, Cámara y Tienda" },
	{ "SimiO", "Lanzar SimiOs" },
	{ "Menú", "Menú de partidas" },
}

local Controls = {}

local function deviceOf(inputType: Enum.UserInputType): string?
	if inputType == Enum.UserInputType.Touch then
		return "touch"
	elseif inputType.Name:sub(1, 7) == "Gamepad" then
		return "gamepad"
	elseif inputType == Enum.UserInputType.Keyboard or inputType.Name:sub(1, 5) == "Mouse" then
		return "keyboard"
	end
	return nil
end

function Controls.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Controls"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Debajo de los botones de Tienda y Menú (ver show: en móvil, debajo del botón Controles)
	local panel = Instance.new("Frame")
	panel.AutomaticSize = Enum.AutomaticSize.XY
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	panel.BackgroundTransparency = 0.35
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	local function label(
		parent: Instance,
		text: string,
		width: number,
		color: Color3,
		order: number
	): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromOffset(width, ROW_HEIGHT)
		l.Font = Enum.Font.GothamBold
		l.TextSize = 13
		l.TextColor3 = color
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Text = text
		l.LayoutOrder = order
		l.Parent = parent
		return l
	end

	local function fill(rows)
		for _, child in panel:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		label(panel, "Controles", 260, TEXT, 0).TextSize = 15
		for i, row in rows do
			local line = Instance.new("Frame")
			line.BackgroundTransparency = 1
			line.Size = UDim2.fromOffset(260, ROW_HEIGHT)
			line.LayoutOrder = i
			line.Parent = panel
			label(line, row[1], 100, KEY, 0)
			label(line, row[2], 160, TEXT, 0).Position = UDim2.fromOffset(100, 0)
		end
	end

	-- Botón para móvil (en PC y control se usa la tecla)
	local toggle = Instance.new("TextButton")
	toggle.Size = UDim2.fromOffset(110, 30)
	toggle.Position = UDim2.new(0, 16, 0.4, 182)
	toggle.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	toggle.BackgroundTransparency = 0.2
	toggle.Font = Enum.Font.GothamBold
	toggle.TextSize = 14
	toggle.TextColor3 = TEXT
	toggle.Text = "Controles"
	toggle.Parent = gui
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 8)
	toggleCorner.Parent = toggle

	local device = deviceOf(UserInputService:GetLastInputType())
		or if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
			then "touch"
			else "keyboard"
	local function show(newDevice: string)
		device = newDevice
		fill(if device == "touch" then TOUCH elseif device == "gamepad" then GAMEPAD else KEYBOARD)
		toggle.Visible = device == "touch"
		panel.Position = UDim2.new(0, 16, 0.4, if device == "touch" then 220 else 182)
	end
	show(device)
	panel.Visible = device == "keyboard"

	UserInputService.LastInputTypeChanged:Connect(function(inputType)
		local newDevice = deviceOf(inputType)
		if newDevice and newDevice ~= device then
			show(newDevice)
		end
	end)

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
	-- Tab: sin "sink", para que también se abra y cierre la tabla de jugadores de Roblox
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Tab and not UserInputService:GetFocusedTextBox() then
			panel.Visible = not panel.Visible
		end
	end)
	ContextActionService:BindAction("ToggleControls", function(_name, state)
		if state == Enum.UserInputState.Begin then
			panel.Visible = not panel.Visible
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.DPadLeft)
end

return Controls
