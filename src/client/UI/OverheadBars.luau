-- Barras sobre la cabeza de los demás jugadores (y de los bots): escudo (azul) encima y vida (verde) debajo.
-- La barra de Roblox solo muestra la vida, así que los disparos al escudo no se notaban.
-- Además, cuando el escudo recibe un golpe el personaje brilla en azul, como en Halo,
-- y destella en blanco cuando el escudo se rompe.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local MAX_SHIELD = 100
local SHIELD_COLOR = Color3.fromRGB(90, 200, 255)
local HEALTH_COLOR = Color3.fromRGB(80, 220, 90)
local LOW_HEALTH_COLOR = Color3.fromRGB(230, 60, 50)
local BAR_WIDTH = 60

local player = Players.LocalPlayer

local OverheadBars = {}

local function makeFill(parent: Instance, y: number, height: number, color: Color3): Frame
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, y)
	back.Size = UDim2.fromOffset(BAR_WIDTH, height)
	back.BackgroundColor3 = Color3.new(0, 0, 0)
	back.BackgroundTransparency = 0.4
	back.BorderSizePixel = 0
	back.Parent = parent
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	return fill
end

-- Ilumina el personaje un instante con un Highlight (un contorno y relleno de color)
local function flash(character: Model, color: Color3, strength: number)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = 1 - strength
	highlight.OutlineTransparency = 1 - strength
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = character
	local info = TweenInfo.new(0.3)
	TweenService:Create(highlight, info, { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	task.delay(0.3, highlight.Destroy, highlight)
end

local function setupCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local head = character:WaitForChild("Head") :: BasePart
	-- Ocultamos la barra de Roblox; el nombre sigue visible
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "OverheadBars"
	billboard.Size = UDim2.fromOffset(BAR_WIDTH, 10)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.MaxDistance = 150
	billboard.LightInfluence = 0
	billboard.Adornee = head
	billboard.Parent = character

	local shieldFill = makeFill(billboard, 0, 5, SHIELD_COLOR)
	local healthFill = makeFill(billboard, 6, 4, HEALTH_COLOR)

	local lastShield = character:GetAttribute("Shield") or MAX_SHIELD
	local function update()
		local shield = character:GetAttribute("Shield") or 0
		local health = humanoid.Health / humanoid.MaxHealth
		shieldFill.Size = UDim2.fromScale(math.clamp(shield / MAX_SHIELD, 0, 1), 1)
		healthFill.Size = UDim2.fromScale(math.clamp(health, 0, 1), 1)
		healthFill.BackgroundColor3 = if health < 0.35 then LOW_HEALTH_COLOR else HEALTH_COLOR

		-- Solo destella cuando el escudo baja, no mientras se recarga
		if shield < lastShield then
			if shield <= 0 then
				flash(character, Color3.new(1, 1, 1), 0.8) -- escudo roto
			else
				flash(character, SHIELD_COLOR, 0.5)
			end
		end
		lastShield = shield
	end
	character:GetAttributeChangedSignal("Shield"):Connect(update)
	humanoid.HealthChanged:Connect(update)
	update()
end

local function watchPlayer(other: Player)
	if other == player then
		return
	end
	other.CharacterAdded:Connect(setupCharacter)
	if other.Character then
		task.spawn(setupCharacter, other.Character)
	end
end

function OverheadBars.Start()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	-- Los cuerpos de los bots están en workspace.Bots (se espera aparte para no detener lo demás)
	task.spawn(function()
		local bots = workspace:WaitForChild("Bots", 30)
		if bots then
			bots.ChildAdded:Connect(setupCharacter)
			for _, body in bots:GetChildren() do
				task.spawn(setupCharacter, body)
			end
		end
	end)
end

return OverheadBars
