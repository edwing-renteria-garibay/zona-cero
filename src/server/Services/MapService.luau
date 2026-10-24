-- Construye el mapa elegido en Config/Maps con bloques grises (greybox): primero se prueba
-- que el mapa se juegue bien y después se decora. Si ya hay una carpeta Workspace.Map
-- (por ejemplo, un mapa hecho a mano en Studio), se usa esa y no se construye nada.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maps = require(ReplicatedStorage.Shared.Config.Maps)

local mapModules = script.Parent.Parent.Maps

local MapService = {}

local currentName: string? = nil -- el mapa que está puesto ahora
local forcedName: string? = nil -- el mapa que eligió quien creó una partida privada

-- El mapa elegido: el de la partida privada o, si no hay, el de Config/Maps
local function selectedMap(): string
	return forcedName or Maps.selected
end

-- El nombre del mapa a construir: el elegido, o uno al azar de la lista (distinto al actual)
local function chooseMap(): string
	local selected = selectedMap()
	if selected ~= "Aleatorio" and Maps.list[selected] then
		return selected
	end
	if selected ~= "Aleatorio" then
		warn("[Map] No existe el mapa", selected, "- elijo uno al azar")
	end
	local names = {}
	for name in Maps.list do
		if name ~= currentName then
			table.insert(names, name)
		end
	end
	if #names == 0 then
		return currentName :: string
	end
	return names[math.random(#names)]
end

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- La luz del mapa: hora del día, sol, niebla y tono (Config/Maps, lighting).
-- Lo fijo (sombras, efectos) está en default.project.json, dentro de Lighting.
local DEFAULT_AMBIENT = { 69, 69, 77 } -- igual que Ambient en default.project.json
local function applyLighting(mapName: string)
	local settings = Maps.lighting[mapName]
	if not settings then
		return
	end
	Lighting.ClockTime = settings.clockTime
	Lighting.Brightness = settings.brightness
	-- Los mapas que no traen ambient ni exposure usan los valores de default.project.json
	Lighting.Ambient = rgb(settings.ambient or DEFAULT_AMBIENT)
	Lighting.ExposureCompensation = settings.exposure or 0
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
		currentName = mapName
		map = Instance.new("Folder")
		map.Name = "Map"
		map:SetAttribute("MapName", Maps.list[mapName])
		map:SetAttribute("MapKey", mapName) -- nombre del archivo, para buscarlo en Config/Maps
		map:SetAttribute("Generated", true) -- hecho por código: se puede cambiar por otro
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

-- Cambia al siguiente mapa: quita el actual y construye otro. Un mapa hecho a mano en Studio
-- (sin el atributo Generated) se queda siempre. Devuelve el mapa nuevo, o nil si no cambió.
function MapService.Next(): Folder?
	local old = workspace:FindFirstChild("Map")
	if not old or not old:GetAttribute("Generated") then
		return nil
	end
	if selectedMap() ~= "Aleatorio" and selectedMap() == currentName then
		return nil -- se eligió un solo mapa: no hace falta reconstruirlo
	end
	old:Destroy()
	-- Algunos mapas usan Terrain (pasto, roca), que no queda dentro de la carpeta del mapa
	workspace.Terrain:Clear()
	local spawns = workspace:FindFirstChild("VehicleSpawns")
	if spawns then
		spawns:Destroy()
	end
	-- Una partida privada juega siempre en el mapa que se eligió (ver MatchSettings). Se aplica
	-- en el siguiente MapService.Next()
	function MapService.SetForced(mapName: string?)
		forcedName = mapName
	end

	return MapService.Build()
end

-- Una partida privada juega siempre en el mapa que se eligió (ver MatchSettings). Se aplica
-- en el siguiente MapService.Next()
function MapService.SetForced(mapName: string?)
	forcedName = mapName
end

return MapService
