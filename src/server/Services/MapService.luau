-- Construye el mapa "Cañón Rojo" con bloques grises (greybox): primero se prueba que el
-- mapa se juegue bien y después se decora. Si ya hay una carpeta Workspace.Map
-- (por ejemplo, un mapa hecho a mano en Studio), se usa esa y no se construye nada.
--
-- Vista desde arriba (X va de una base a la otra, Z de un lado del cañón al otro):
--
--   z=+80  ======================== pared del cañón =========================
--          [rampa]  ____ techo del túnel (camino alto de flanqueo) ____  [rampa]
--          |        |____ túnel de infantería (los jeeps no caben) ____|        |
--   AZUL   |                  camino de jeeps con coberturas                  |   ROJO
--   x=-175 |                        puente en x = 0                           |  x=+175
--          |        |____ túnel de infantería _________________________|        |
--          [rampa]  ____ techo del túnel _______________________________  [rampa]
--   z=-80  ======================== pared del cañón =========================
--
-- Las dos mitades son iguales (giradas 180°) para que ningún equipo tenga ventaja.

local MapService = {}

-- Medidas principales, en studs
local LENGTH = 400 -- de una pared del fondo a la otra (eje X)
local CANYON_HALF_WIDTH = 80 -- del centro a cada pared del cañón (eje Z)
local WALL_HEIGHT = 60
local TUNNEL_INNER_Z = 44 -- pared del túnel que da al camino
local TUNNEL_OUTER_Z = 60 -- pared del túnel que da a la pared del cañón
local TUNNEL_END_X = 100 -- los túneles van de x = -100 a x = 100
local TUNNEL_HEIGHT = 12
local ROOF_TOP = 14 -- altura del techo de los túneles y del puente (el jeep pasa por debajo)
local BASE_X = 175 -- centro de cada base

-- Colores y materiales: el material decide el sonido del impacto (concreto, metal o madera)
local ROCK = { Color = Color3.fromRGB(150, 75, 50), Material = Enum.Material.Rock }
local SAND = { Color = Color3.fromRGB(190, 130, 90), Material = Enum.Material.Sand }
local CONCRETE = { Color = Color3.fromRGB(160, 155, 145), Material = Enum.Material.Concrete }
local WOOD = { Color = Color3.fromRGB(140, 100, 60), Material = Enum.Material.WoodPlanks }
local METAL = { Color = Color3.fromRGB(85, 92, 60), Material = Enum.Material.Metal }
local PLATE = { Color = Color3.fromRGB(110, 110, 110), Material = Enum.Material.DiamondPlate }

local TEAMS = {
	-- El equipo Rojo está en +X y el Azul en -X
	{ name = "Rojo", side = 1, color = BrickColor.new("Bright red") },
	{ name = "Azul", side = -1, color = BrickColor.new("Bright blue") },
}

-- Crea un bloque anclado. style es uno de los estilos de arriba (color + material)
local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, style): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = style.Color
	part.Material = style.Material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Pone un bloque en cada mitad del mapa: en (x, y, z) y girado 180° en (-x, y, -z)
local function mirrored(parent: Instance, name: string, size: Vector3, position: Vector3, style, yaw: number?)
	local rotation = CFrame.Angles(0, math.rad(yaw or 0), 0)
	block(parent, name, size, CFrame.new(position) * rotation, style)
	block(parent, name, size, CFrame.Angles(0, math.pi, 0) * CFrame.new(position) * rotation, style)
end

local function buildCanyon(map: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "Canyon"
	folder.Parent = map
	local width = CANYON_HALF_WIDTH * 2
	-- Suelo: la parte de arriba queda en y = 0
	block(folder, "Floor", Vector3.new(LENGTH, 2, width), CFrame.new(0, -1, 0), SAND)
	-- Paredes del cañón a los lados y al fondo de cada base
	for _, side in { 1, -1 } do
		local wallZ = side * (CANYON_HALF_WIDTH + 10)
		block(
			folder,
			"CanyonWall",
			Vector3.new(LENGTH + 40, WALL_HEIGHT, 20),
			CFrame.new(0, WALL_HEIGHT / 2, wallZ),
			ROCK
		)
		local endX = side * (LENGTH / 2 + 10)
		block(
			folder,
			"EndWall",
			Vector3.new(20, WALL_HEIGHT, width),
			CFrame.new(endX, WALL_HEIGHT / 2, 0),
			ROCK
		)
	end
	-- Unas rocas junto a las bases para que las paredes no se vean tan planas
	for _, rock in { { 150, 72, 10 }, { 190, -70, 12 } } do
		mirrored(
			folder,
			"Rock",
			Vector3.new(16, rock[3], 14),
			Vector3.new(rock[1], rock[3] / 2, rock[2]),
			ROCK,
			15
		)
	end
end

-- Túneles de infantería a los dos lados del camino. Sus techos forman el camino alto.
local function buildTunnels(map: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "Tunnels"
	folder.Parent = map
	local tunnelLength = TUNNEL_END_X * 2
	local midZ = (TUNNEL_INNER_Z + TUNNEL_OUTER_Z) / 2

	for _, side in { 1, -1 } do
		-- Pared exterior, entera
		block(
			folder,
			"TunnelWall",
			Vector3.new(tunnelLength, TUNNEL_HEIGHT, 2),
			CFrame.new(0, TUNNEL_HEIGHT / 2, side * TUNNEL_OUTER_Z),
			CONCRETE
		)
		-- Pared interior en tramos, con huecos de 6 studs para entrar y salir al camino
		local segment, gap = 34, 6
		local x = -TUNNEL_END_X
		while x < TUNNEL_END_X do
			local length = math.min(segment, TUNNEL_END_X - x)
			block(
				folder,
				"TunnelWall",
				Vector3.new(length, TUNNEL_HEIGHT, 2),
				CFrame.new(x + length / 2, TUNNEL_HEIGHT / 2, side * TUNNEL_INNER_Z),
				CONCRETE
			)
			x += segment + gap
		end
		-- Techo: también cubre el pasillo entre el túnel y la pared del cañón
		local roofInner, roofOuter = TUNNEL_INNER_Z - 1, CANYON_HALF_WIDTH
		block(
			folder,
			"TunnelRoof",
			Vector3.new(tunnelLength, 2, roofOuter - roofInner),
			CFrame.new(0, ROOF_TOP - 1, side * (roofInner + roofOuter) / 2),
			CONCRETE
		)
		-- Postes en las entradas: una persona pasa entre ellos, un jeep no
		for _, endX in { -TUNNEL_END_X, TUNNEL_END_X } do
			for z = TUNNEL_INNER_Z + 2.5, TUNNEL_OUTER_Z - 2, 4 do
				block(folder, "Bollard", Vector3.new(1, 4, 1), CFrame.new(endX, 2, side * z), METAL)
			end
		end
		-- Coberturas dentro del túnel
		for _, crateX in { -60, 0, 60 } do
			block(folder, "Crate", Vector3.new(4, 4, 4), CFrame.new(crateX, 2, side * (midZ + 3)), WOOD)
		end
	end

	-- Rampas para subir al techo de los túneles, junto a la pared del cañón
	local run = 30 -- largo horizontal de la rampa
	local angle = math.atan2(ROOF_TOP, run)
	local rampLength = math.sqrt(run * run + ROOF_TOP * ROOF_TOP)
	local rampZ = (TUNNEL_OUTER_Z + 2 + CANYON_HALF_WIDTH) / 2
	local rampWidth = CANYON_HALF_WIDTH - TUNNEL_OUTER_Z - 2
	-- Cuatro rampas, una en cada esquina, con la parte alta hacia el centro del mapa.
	-- Se inclinan girando sobre el eje Z: en +X el extremo de afuera baja, en -X sube.
	for _, sideX in { 1, -1 } do
		for _, sideZ in { 1, -1 } do
			local center = Vector3.new(sideX * (TUNNEL_END_X + run / 2), ROOF_TOP / 2 - 0.5, sideZ * rampZ)
			block(
				folder,
				"Ramp",
				Vector3.new(rampLength, 1, rampWidth),
				CFrame.new(center) * CFrame.Angles(0, 0, -sideX * angle),
				PLATE
			)
		end
	end
end

-- Puente en el centro, de un techo de túnel al otro. Ahí está el lanzacohetes.
local function buildBridge(map: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "Bridge"
	folder.Parent = map
	local span = (TUNNEL_INNER_Z - 1) * 2
	block(folder, "Deck", Vector3.new(16, 2, span), CFrame.new(0, ROOF_TOP - 1, 0), PLATE)
	for _, x in { -7.5, 7.5 } do
		block(folder, "Railing", Vector3.new(1, 3, span), CFrame.new(x, ROOF_TOP + 1.5, 0), METAL)
	end
	-- Pilares a los lados del camino (los jeeps pasan por debajo, entre ellos)
	for _, z in { -TUNNEL_INNER_Z + 4, TUNNEL_INNER_Z - 4 } do
		block(
			folder,
			"Pillar",
			Vector3.new(4, ROOF_TOP - 2, 4),
			CFrame.new(0, (ROOF_TOP - 2) / 2, z),
			CONCRETE
		)
	end
end

-- Coberturas en el camino de jeeps, cada 15 a 25 studs: barreras, cajas y contenedores
local function buildCover(map: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "Cover"
	folder.Parent = map
	local barrier = Vector3.new(8, 3.5, 2)
	local crate = Vector3.new(4, 4, 4)
	local container = Vector3.new(16, 8, 7)
	-- Solo se describe la mitad Roja (+X); la Azul es la misma girada 180°
	mirrored(folder, "Barrier", barrier, Vector3.new(25, barrier.Y / 2, 18), CONCRETE, 10)
	mirrored(folder, "Barrier", barrier, Vector3.new(45, barrier.Y / 2, -22), CONCRETE, -15)
	mirrored(folder, "Crate", crate, Vector3.new(62, crate.Y / 2, 6), WOOD)
	mirrored(folder, "Crate", crate, Vector3.new(64, crate.Y / 2 + crate.Y, 6), WOOD, 20)
	mirrored(folder, "Container", container, Vector3.new(85, container.Y / 2, -12), METAL)
	mirrored(folder, "Barrier", barrier, Vector3.new(105, barrier.Y / 2, 24), CONCRETE)
	mirrored(folder, "Crate", crate, Vector3.new(120, crate.Y / 2, -30), WOOD, 35)
	mirrored(folder, "Barrier", barrier, Vector3.new(130, barrier.Y / 2, 8), CONCRETE, 90)
end

-- Una base por equipo: un búnker abierto hacia el centro, con los puntos de aparición dentro
local function buildBase(map: Folder, team)
	local folder = Instance.new("Folder")
	folder.Name = "Base" .. team.name
	folder.Parent = map
	local side = team.side
	local stripe = { Color = team.color.Color, Material = Enum.Material.SmoothPlastic }

	-- Búnker: pared trasera, dos laterales y techo; el frente (hacia el centro) queda abierto
	local depth, width, height = 30, 44, 12
	local back = BASE_X + depth / 2
	block(folder, "BunkerFloor", Vector3.new(depth, 1, width), CFrame.new(side * BASE_X, 0.5, 0), CONCRETE)
	block(
		folder,
		"BunkerWall",
		Vector3.new(2, height, width),
		CFrame.new(side * back, height / 2, 0),
		CONCRETE
	)
	for _, z in { -width / 2, width / 2 } do
		block(
			folder,
			"BunkerWall",
			Vector3.new(depth, height, 2),
			CFrame.new(side * BASE_X, height / 2, z),
			CONCRETE
		)
	end
	block(
		folder,
		"BunkerRoof",
		Vector3.new(depth, 2, width + 2),
		CFrame.new(side * BASE_X, height + 1, 0),
		CONCRETE
	)
	-- Franja del color del equipo para saber de quién es la base
	block(
		folder,
		"TeamStripe",
		Vector3.new(depth + 0.2, 1.5, width + 2.2),
		CFrame.new(side * BASE_X, height - 1, 0),
		stripe
	)
	-- Barricada a la entrada para cubrirse al salir
	block(
		folder,
		"Barrier",
		Vector3.new(2, 3.5, 12),
		CFrame.new(side * (BASE_X - depth / 2 - 6), 1.75, 0),
		CONCRETE
	)

	-- Puntos de aparición: solo para este equipo, mirando hacia el centro
	for _, z in { -12, -4, 4, 12 } do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn" .. team.name
		spawn.Size = Vector3.new(5, 1, 5)
		spawn.Anchored = true
		spawn.CFrame = CFrame.lookAt(Vector3.new(side * (BASE_X + 6), 1.5, z), Vector3.new(0, 1.5, z))
		spawn.BrickColor = team.color
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.TeamColor = team.color
		spawn.Neutral = false -- solo aparecen aquí los de este equipo
		spawn.AllowTeamChangeOnTouch = false
		spawn.Duration = 0 -- sin campo de fuerza: la protección la da el juego (SpawnProtected)
		spawn.Parent = folder
	end
end

-- Dónde aparecen los jeeps (VehicleService lee Workspace.VehicleSpawns) y las armas del mapa
local function buildSpawnPoints(map: Folder)
	local vehicleSpawns = Instance.new("Folder")
	vehicleSpawns.Name = "VehicleSpawns"
	for _, team in TEAMS do
		-- Un jeep junto a cada base, mirando hacia el centro
		local position = Vector3.new(team.side * 140, 1, team.side * -2)
		local marker = Instance.new("Part")
		marker.Name = "JeepSpawn" .. team.name
		marker.Anchored = true
		marker.Size = Vector3.new(8, 1, 12)
		marker.CFrame = CFrame.lookAt(position, Vector3.new(0, 1, position.Z))
		marker.Parent = vehicleSpawns
	end
	vehicleSpawns.Parent = workspace

	local pickups = Instance.new("Folder")
	pickups.Name = "WeaponPickups"
	pickups.Parent = map
	-- El lanzacohetes, en el centro del puente: muy expuesto, como pide el diseño
	local pad = Instance.new("Part")
	pad.Name = "RocketLauncherPad"
	pad.Anchored = true
	pad.Size = Vector3.new(4, 0.4, 4)
	pad.CFrame = CFrame.new(0, ROOF_TOP + 0.2, 0)
	pad.Color = Color3.fromRGB(255, 170, 0)
	pad.Material = Enum.Material.Neon
	pad:SetAttribute("Weapon", "RocketLauncher")
	pad.Parent = pickups
end

-- Construye el mapa si no existe y desactiva los puntos de aparición que no son del mapa
-- (como el SpawnLocation que trae la plantilla de Studio)
function MapService.Build(): Folder
	local map = workspace:FindFirstChild("Map") :: Folder?
	if not map then
		map = Instance.new("Folder")
		map.Name = "Map"
		buildCanyon(map)
		buildTunnels(map)
		buildBridge(map)
		buildCover(map)
		for _, team in TEAMS do
			buildBase(map, team)
		end
		buildSpawnPoints(map)
		map.Parent = workspace
	end
	for _, spawn in workspace:GetDescendants() do
		if spawn:IsA("SpawnLocation") and not spawn:IsDescendantOf(map) then
			spawn.Enabled = false
		end
	end
	return map
end

return MapService
