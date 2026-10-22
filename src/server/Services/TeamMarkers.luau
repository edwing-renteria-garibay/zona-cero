-- Brazaletes del color del equipo: una banda en cada brazo para distinguir a Rojo y Azul
-- sin cambiar el avatar de cada jugador. Sin equipo (Asesino en solitario) no se ven.

local TeamMarkers = {}

-- Nombres de la parte de arriba de cada brazo: R15 (avatar normal) y R6 (avatar clásico)
local ARM_NAMES = { "LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm" }
local BAND_HEIGHT = 0.35 -- qué parte del brazo cubre la banda (35 %)

-- Pinta la banda del color del equipo, o la esconde si el jugador no tiene equipo
local function paintBand(band: BasePart, player: Player)
	band.Color = player.TeamColor.Color
	band.Transparency = if player.Team and not player.Neutral then 0 else 1
end

local function addBand(arm: BasePart, player: Player)
	local band = Instance.new("Part")
	band.Name = "TeamArmband"
	-- Un poco más ancha que el brazo para que lo rodee
	band.Size = Vector3.new(arm.Size.X * 1.12, arm.Size.Y * BAND_HEIGHT, arm.Size.Z * 1.12)
	-- Cerca del hombro, como un brazalete
	band.CFrame = arm.CFrame * CFrame.new(0, arm.Size.Y * 0.15, 0)
	paintBand(band, player)
	band.Material = Enum.Material.SmoothPlastic
	band.CanCollide = false
	band.CanQuery = false -- las balas la atraviesan y pegan en el brazo
	band.CanTouch = false
	band.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = arm
	weld.Part1 = band
	weld.Parent = band
	band.Parent = arm
end

local function paint(character: Model, player: Player)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part.Name == "TeamArmband" then
			paintBand(part, player)
		end
	end
end

function TeamMarkers.SetupCharacter(player: Player, character: Model)
	for _, name in ARM_NAMES do
		-- Los brazos de R15 o de R6: se espera un momento a que aparezcan
		local arm = character:FindFirstChild(name) or character:WaitForChild(name, 2)
		if arm and arm:IsA("BasePart") then
			addBand(arm, player)
		end
	end
	-- Si el jugador cambia de equipo (o se queda sin equipo), el brazalete cambia
	local connections = {}
	for _, property in { "Team", "Neutral" } do
		table.insert(
			connections,
			player:GetPropertyChangedSignal(property):Connect(function()
				paint(character, player)
			end)
		)
	end
	character.AncestryChanged:Connect(function()
		if not character.Parent then
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end)
end

return TeamMarkers
