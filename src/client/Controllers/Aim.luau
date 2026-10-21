-- Calcula el punto del mundo que señala el mouse (o el último toque en móvil).
-- Lo usan el rifle y la torreta del jeep.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local Aim = {}

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
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	return if result then result.Position else ray.Origin + ray.Direction * 1000
end

return Aim
