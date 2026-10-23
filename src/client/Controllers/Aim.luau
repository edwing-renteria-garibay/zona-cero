-- Calcula el punto del mundo que señala el mouse (o el último toque en móvil).
-- Con control (Xbox/PlayStation) no hay mouse: se apunta al centro de la pantalla,
-- donde está la mira. Lo usan las armas, las granadas y la torreta del jeep.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local Aim = {}

-- ¿Lo último que tocó el jugador fue un control?
function Aim.UsingGamepad(): boolean
	local last = UserInputService:GetLastInputType()
	return last.Name:sub(1, 7) == "Gamepad"
end

-- Punto de la pantalla al que apuntas
function Aim.GetScreenPoint(): Vector2
	if Aim.UsingGamepad() then
		local camera = workspace.CurrentCamera
		-- ViewportSize incluye la barra de arriba, igual que GetMouseLocation
		return camera.ViewportSize / 2
	end
	return UserInputService:GetMouseLocation()
end

-- Devuelve el punto al que apuntas, ignorando tu personaje y el vehículo en el que vas
function Aim.GetTarget(): Vector3
	local character = player.Character
	local ignore: { Instance } = {}
	if character then
		table.insert(ignore, character)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		if seat and seat.Parent and seat.Parent:GetAttribute("Vehicle") then
			table.insert(ignore, seat.Parent)
		end
	end

	local camera = workspace.CurrentCamera
	local point = Aim.GetScreenPoint()
	local ray = camera:ViewportPointToRay(point.X, point.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	return if result then result.Position else ray.Origin + ray.Direction * 1000
end

return Aim
