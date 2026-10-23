-- Construye el mapa elegido en Config/Maps con bloques grises (greybox): primero se prueba
-- que el mapa se juegue bien y después se decora. Si ya hay una carpeta Workspace.Map
-- (por ejemplo, un mapa hecho a mano en Studio), se usa esa y no se construye nada.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maps = require(ReplicatedStorage.Shared.Config.Maps)

local mapModules = script.Parent.Parent.Maps

local MapService = {}

-- El nombre del mapa a construir: el elegido, o uno al azar de la lista
local function chooseMap(): string
	if Maps.selected ~= "Aleatorio" and Maps.list[Maps.selected] then
		return Maps.selected
	end
	if Maps.selected ~= "Aleatorio" then
		warn("[Map] No existe el mapa", Maps.selected, "- elijo uno al azar")
	end
	local names = {}
	for name in Maps.list do
		table.insert(names, name)
	end
	return names[math.random(#names)]
end

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- La luz del mapa: hora del día, sol, niebla y tono (Config/Maps, lighting).
-- Lo fijo (sombras, efectos) está en default.project.json, dentro de Lighting.
local function applyLighting(mapName: string)
	local settings = Maps.lighting[mapName]
	if not settings then
		return
	end
	Lighting.ClockTime = settings.clockTime
	Lighting.Brightness = settings.brightness
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = settings.density
		atmosphere.Offset = 0.2
		atmosphere.Color = rgb(settings.haze)
		atmosphere.Decay = rgb(settings.decay)
		atmosphere.Glare = 0.3
		atmosphere.Haze = 1.5
	end
	local correction = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if correction then
		correction.TintColor = rgb(settings.tint)
	end
end

-- Construye el mapa si no existe y quita lo que trae la plantilla de Studio: desactiva los
-- puntos de aparición que no son del mapa y borra la Baseplate (queda a la misma altura que
-- el piso del mapa y los dos pisos parpadean al moverse la cámara)
function MapService.Build(): Folder
	local map = workspace:FindFirstChild("Map") :: Folder?
	if not map then
		local mapName = chooseMap()
		map = Instance.new("Folder")
		map.Name = "Map"
		map:SetAttribute("MapName", Maps.list[mapName])
		-- Carpetas que llenan los mapas: dónde aparecen los jeeps y las plataformas de objetos
		local vehicleSpawns = Instance.new("Folder")
		vehicleSpawns.Name = "VehicleSpawns"
		vehicleSpawns.Parent = workspace
		local pickups = Instance.new("Folder")
		pickups.Name = "WeaponPickups"
		pickups.Parent = map
		require(mapModules:FindFirstChild(mapName) :: ModuleScript).Build(map)
		-- Acabados: tonos, remates de muros y luces en los puntos de aparición
		require(mapModules.Builder).decorate(map, #mapName)
		map.Parent = workspace
		applyLighting(mapName)
		print("[Map] Mapa:", Maps.list[mapName])
	end
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and not baseplate:IsDescendantOf(map) then
		baseplate:Destroy()
	end
	for _, spawn in workspace:GetDescendants() do
		if spawn:IsA("SpawnLocation") and not spawn:IsDescendantOf(map) then
			spawn.Enabled = false
		end
	end
	return map
end

return MapService
