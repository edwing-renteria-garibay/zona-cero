-- Brazaletes del color del equipo: una banda en cada brazo para distinguir a Rojo y Azul
-- sin cambiar el avatar de cada jugador.

local TeamMarkers = {}

-- Nombres de la parte de arriba de cada brazo: R15 (avatar normal) y R6 (avatar clásico)
local ARM_NAMES = { "LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm" }
local BAND_HEIGHT = 0.35 -- qué parte del brazo cubre la banda (35 %)

local function teamColor(player: Player): Color3
	return if player.Team then player.TeamColor.Color else Color3.new(1, 1, 1)
end

local function addBand(arm: BasePart, color: Color3)
	local band = Instance.new("Part")
	band.Name = "TeamArmband"
	-- Un poco más ancha que el brazo para que lo rodee
	band.Size = Vector3.new(arm.Size.X * 1.12, arm.Size.Y * BAND_HEIGHT, arm.Size.Z * 1.12)
	-- Cerca del hombro, como un brazalete
	band.CFrame = arm.CFrame * CFrame.new(0, arm.Size.Y * 0.15, 0)
	band.Color = color
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

local function paint(character: Model, color: Color3)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part.Name == "TeamArmband" then
			part.Color = color
		end
	end
end

function TeamMarkers.SetupCharacter(player: Player, character: Model)
	for _, name in ARM_NAMES do
		-- Los brazos de R15 o de R6: se espera un momento a que aparezcan
		local arm = character:FindFirstChild(name) or character:WaitForChild(name, 2)
		if arm and arm:IsA("BasePart") then
			addBand(arm, teamColor(player))
		end
	end
	-- Si el jugador cambia de equipo, el brazalete cambia de color
	local connection = player:GetPropertyChangedSignal("Team"):Connect(function()
		paint(character, teamColor(player))
	end)
	character.AncestryChanged:Connect(function()
		if not character.Parent then
			connection:Disconnect()
		end
	end)
end

return TeamMarkers
