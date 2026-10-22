-- Construye el mapa "Cañón Rojo" con bloques grises (greybox): primero se prueba que el
-- mapa se juegue bien y después se decora. Si ya hay una carpeta Workspace.Map
-- (por ejemplo, un mapa hecho a mano en Studio), se usa esa y no se construye nada.
--
-- Vista desde arriba de la mitad Roja (+X). La mitad Azul es la misma, girada 180°:
--
--   z=+80 ==================== pared del cañón ====================================
--          [cornisa alta, a 8 studs, con rampas en las puntas]      |  BASE BAJA   |
--                                                                   |  (cerrada,   |
--      montículo       carril norte: cajas, contenedor, barreras    |  2 spawns)   |
--     con el lanza- ---- muro divisorio con huecos ----              ---------------
--     cohetes (x=0)    carril sur                       [jeep]       ZONA DE SPAWN
--                         [cuarto lateral                            (2 spawns)
--                          con granadas]       rampa  /BASE ALTA\ ---- rampa roja
--          [cornisa alta]                             \(mesa 16)/
--   z=-80 ==================== pared del cañón ====================================
--                                                                        x=+200
-- Tres rutas entre bases: los carriles del centro (jeeps), las cornisas altas junto a
-- las paredes y los cuartos laterales. Los jeeps no caben por las puertas de las bases.

local MapService = {}

-- Medidas principales, en studs
local HALF_LENGTH = 200 -- del centro a la pared del fondo (eje X)
local HALF_WIDTH = 80 -- del centro a cada pared del cañón (eje Z)
local WALL_HEIGHT = 60
local LEDGE_HEIGHT = 8 -- cornisas junto a las paredes del cañón
local MESA_HEIGHT = 16 -- base alta
local MOUND_HEIGHT = 4 -- montículo del centro
local ROOM_HEIGHT = 14 -- paredes de las bases

-- Colores y materiales: el material decide el sonido del impacto (concreto, metal o madera)
local ROCK = { Color = Color3.fromRGB(150, 75, 50), Material = Enum.Material.Rock }
local SAND = { Color = Color3.fromRGB(190, 130, 90), Material = Enum.Material.Sand }
local CONCRETE = { Color = Color3.fromRGB(160, 155, 145), Material = Enum.Material.Concrete }
local SANDBAG = { Color = Color3.fromRGB(170, 150, 110), Material = Enum.Material.Fabric }
local WOOD = { Color = Color3.fromRGB(140, 100, 60), Material = Enum.Material.WoodPlanks }
local METAL = { Color = Color3.fromRGB(85, 92, 60), Material = Enum.Material.Metal }
local PLATE = { Color = Color3.fromRGB(110, 110, 110), Material = Enum.Material.DiamondPlate }

local TEAMS = {
	-- El equipo Rojo está en +X y el Azul en -X
	{ name = "Rojo", side = 1, color = BrickColor.new("Bright red") },
	{ name = "Azul", side = -1, color = BrickColor.new("Bright blue") },
}

local HALF_TURN = CFrame.Angles(0, math.pi, 0)

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

-- Una rampa (una losa inclinada) que va de low a high. La cara de arriba pasa por los dos
-- puntos, así que se puede caminar o manejar de un punto al otro.
local function slope(parent: Instance, name: string, low: Vector3, high: Vector3, width: number, style): Part
	local length = (high - low).Magnitude
	local middle = (low + high) / 2
	-- lookAt apunta el eje Z de la losa hacia high; luego la bajamos medio grosor
	local cframe = CFrame.lookAt(middle, high) * CFrame.new(0, -0.5, 0)
	return block(parent, name, Vector3.new(width, 1, length), cframe, style)
end

-- Un muro con huecos (puertas) a lo largo del eje X o Z.
-- from/to: los extremos del muro sobre el suelo; gaps: lista de {inicio, fin} medidos desde from
local function wallWithGaps(
	parent: Instance,
	name: string,
	from: Vector3,
	to: Vector3,
	height: number,
	gaps: { { number } },
	style
)
	local direction = (to - from).Unit
	local total = (to - from).Magnitude
	local cursor = 0
	local function piece(startAt: number, endAt: number)
		if endAt - startAt < 0.1 then
			return
		end
		local a = from + direction * startAt
		local b = from + direction * endAt
		local middle = (a + b) / 2 + Vector3.new(0, height / 2, 0)
		block(
			parent,
			name,
			Vector3.new(2, height, endAt - startAt),
			CFrame.lookAt(middle, middle + direction),
			style
		)
	end
	for _, gap in gaps do
		piece(cursor, gap[1])
		cursor = gap[2]
	end
	piece(cursor, total)
end

-- Suelo, paredes del cañón, montículo central y cornisas: lo que no es de ningún equipo
local function buildCanyon(map: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "Canyon"
	folder.Parent = map
	local length, width = HALF_LENGTH * 2, HALF_WIDTH * 2
	block(folder, "Floor", Vector3.new(length, 2, width), CFrame.new(0, -1, 0), SAND)
	for _, side in { 1, -1 } do
		block(
			folder,
			"CanyonWall",
			Vector3.new(length + 40, WALL_HEIGHT, 20),
			CFrame.new(0, WALL_HEIGHT / 2, side * (HALF_WIDTH + 10)),
			ROCK
		)
		block(
			folder,
			"EndWall",
			Vector3.new(20, WALL_HEIGHT, width),
			CFrame.new(side * (HALF_LENGTH + 10), WALL_HEIGHT / 2, 0),
			ROCK
		)
	end

	-- Montículo en el centro: una plataforma con rampas por los cuatro lados.
	-- Arriba está el lanzacohetes, a la vista de todos.
	local top, run = 14, 12 -- medio lado de la plataforma y largo de cada rampa
	block(
		folder,
		"Mound",
		Vector3.new(top * 2, MOUND_HEIGHT, top * 2),
		CFrame.new(0, MOUND_HEIGHT / 2, 0),
		SAND
	)
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local edge = dir * top + Vector3.yAxis * MOUND_HEIGHT
		slope(folder, "MoundSlope", dir * (top + run), edge, top * 2, SAND)
	end

	-- Cornisas junto a las paredes: camino alto para flanquear, con rampas en las dos puntas
	local ledgeEnd, ledgeRun, ledgeWidth = 100, 24, 16
	local ledgeZ = HALF_WIDTH - ledgeWidth / 2
	for _, sideZ in { 1, -1 } do
		block(
			folder,
			"Ledge",
			Vector3.new(ledgeEnd * 2, LEDGE_HEIGHT, ledgeWidth),
			CFrame.new(0, LEDGE_HEIGHT / 2, sideZ * ledgeZ),
			ROCK
		)
		for _, sideX in { 1, -1 } do
			slope(
				folder,
				"LedgeRamp",
				Vector3.new(sideX * (ledgeEnd + ledgeRun), 0, sideZ * ledgeZ),
				Vector3.new(sideX * ledgeEnd, LEDGE_HEIGHT, sideZ * ledgeZ),
				ledgeWidth,
				ROCK
			)
		end
		-- Rocas sobre la cornisa para cubrirse arriba
		for _, x in { -60, 0, 60 } do
			block(
				folder,
				"Rock",
				Vector3.new(6, 4, 4),
				CFrame.new(x + sideZ * 15, LEDGE_HEIGHT + 2, sideZ * (ledgeZ - 4)) * CFrame.Angles(0, 0.4, 0),
				ROCK
			)
		end
	end
end

-- Todo lo de un equipo. Las medidas están escritas para la mitad Roja (+X);
-- para la Azul, place() gira cada pieza 180° alrededor del centro del mapa.
local function buildHalf(map: Folder, team)
	local folder = Instance.new("Folder")
	folder.Name = "Half" .. team.name
	folder.Parent = map
	local stripe = { Color = team.color.Color, Material = Enum.Material.SmoothPlastic }

	local function place(cframe: CFrame): CFrame
		return if team.side == 1 then cframe else HALF_TURN * cframe
	end
	local function at(position: Vector3): Vector3
		return place(CFrame.new(position)).Position
	end
	local function add(name: string, size: Vector3, position: Vector3, style, yaw: number?): Part
		return block(
			folder,
			name,
			size,
			place(CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0)),
			style
		)
	end
	local function addSpawn(position: Vector3)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn" .. team.name
		spawn.Size = Vector3.new(5, 1, 5)
		spawn.Anchored = true
		-- Mirando hacia el centro del mapa
		local world = at(position)
		spawn.CFrame = CFrame.lookAt(world, Vector3.new(0, world.Y, world.Z))
		spawn.BrickColor = team.color
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.TeamColor = team.color
		spawn.Neutral = false -- solo aparecen aquí los de este equipo
		spawn.AllowTeamChangeOnTouch = false
		spawn.Duration = 0 -- sin campo de fuerza: la protección la da el juego (SpawnProtected)
		spawn.Parent = folder
	end

	-- Base baja: un cuarto cerrado en la esquina, con dos puertas angostas (8 studs:
	-- una persona pasa, un jeep no). Una da al centro y otra a la zona de spawn.
	local x0, x1, z0, z1 = 156, 198, 34, 78
	local h = ROOM_HEIGHT
	local function wall(from: Vector3, to: Vector3, gaps)
		local a, b = at(from), at(to)
		wallWithGaps(folder, "BaseWall", a, b, h, gaps, CONCRETE)
	end
	wall(Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z1), { { 16, 24 } }) -- oeste, puerta al centro
	wall(Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0), { { 24, 32 } }) -- sur, puerta a la zona de spawn
	wall(Vector3.new(x1, 0, z0), Vector3.new(x1, 0, z1), {})
	wall(Vector3.new(x0, 0, z1), Vector3.new(x1, 0, z1), {})
	add(
		"BaseRoof",
		Vector3.new(x1 - x0 + 2, 2, z1 - z0 + 2),
		Vector3.new((x0 + x1) / 2, h + 1, (z0 + z1) / 2),
		CONCRETE
	)
	add(
		"TeamStripe",
		Vector3.new(x1 - x0 + 2.4, 1.5, z1 - z0 + 2.4),
		Vector3.new((x0 + x1) / 2, h - 1, (z0 + z1) / 2),
		stripe
	)
	addSpawn(Vector3.new(188, 0.5, 60))
	addSpawn(Vector3.new(188, 0.5, 48))
	add("Crate", Vector3.new(4, 4, 4), Vector3.new(170, 2, 66), WOOD, 15)
	add("Crate", Vector3.new(4, 4, 4), Vector3.new(170, 2, 46), WOOD, -10)

	-- Zona de spawn: un nicho techado contra la pared del fondo, abierto hacia el centro,
	-- con sacos de arena al frente para cubrirse al salir
	add("SpawnBack", Vector3.new(2, h, 30), Vector3.new(198, h / 2, 0), CONCRETE)
	for _, z in { -15, 15 } do
		add("SpawnSide", Vector3.new(22, h, 2), Vector3.new(188, h / 2, z), CONCRETE)
	end
	add("SpawnRoof", Vector3.new(24, 2, 32), Vector3.new(188, h + 1, 0), CONCRETE)
	add("TeamStripe", Vector3.new(24.4, 1.5, 32.4), Vector3.new(188, h - 1, 0), stripe)
	addSpawn(Vector3.new(190, 0.5, 6))
	addSpawn(Vector3.new(190, 0.5, -6))
	add("Sandbags", Vector3.new(2, 3, 10), Vector3.new(170, 1.5, 6), SANDBAG)
	add("Sandbags", Vector3.new(2, 3, 10), Vector3.new(166, 1.5, -10), SANDBAG)

	-- Base alta: una mesa de roca a 16 studs, con parapetos. Se sube por la "rampa roja"
	-- desde la zona de spawn o por una rampa desde el carril sur.
	local mx0, mx1, mz0, mz1 = 128, 164, -78, -44
	add(
		"Mesa",
		Vector3.new(mx1 - mx0, MESA_HEIGHT, mz1 - mz0),
		Vector3.new((mx0 + mx1) / 2, MESA_HEIGHT / 2, (mz0 + mz1) / 2),
		ROCK
	)
	local rampSlab = slope(
		folder,
		"TeamRamp",
		at(Vector3.new(196, 0, -60)),
		at(Vector3.new(mx1, MESA_HEIGHT, -60)),
		12,
		PLATE
	)
	rampSlab.Color = team.color.Color -- la rampa del color del equipo
	slope(folder, "MesaRamp", at(Vector3.new(146, 0, -14)), at(Vector3.new(146, MESA_HEIGHT, mz1)), 10, PLATE)
	-- Parapetos: muros bajos en los bordes, con huecos para las rampas
	local p = MESA_HEIGHT
	wallWithGaps(
		folder,
		"Parapet",
		at(Vector3.new(mx0, p, mz1)),
		at(Vector3.new(mx1, p, mz1)),
		3,
		{ { 13, 23 } },
		CONCRETE
	)
	wallWithGaps(
		folder,
		"Parapet",
		at(Vector3.new(mx0, p, mz0)),
		at(Vector3.new(mx0, p, mz1)),
		3,
		{ { 12, 22 } },
		CONCRETE
	)
	wallWithGaps(
		folder,
		"Parapet",
		at(Vector3.new(mx1, p, mz0)),
		at(Vector3.new(mx1, p, mz1)),
		3,
		{ { 12, 24 } },
		stripe
	)
	add("Crate", Vector3.new(4, 4, 4), Vector3.new(140, p + 2, -60), WOOD, 30)

	-- Cuarto lateral junto al carril sur, con granadas
	local rx0, rx1, rz0, rz1 = 50, 72, -62, -40
	local function roomWall(from: Vector3, to: Vector3, gaps)
		wallWithGaps(folder, "RoomWall", at(from), at(to), 10, gaps, CONCRETE)
	end
	roomWall(Vector3.new(rx0, 0, rz1), Vector3.new(rx1, 0, rz1), { { 8, 14 } }) -- puerta al carril
	roomWall(Vector3.new(rx0, 0, rz0), Vector3.new(rx0, 0, rz1), { { 8, 14 } }) -- puerta hacia el centro
	roomWall(Vector3.new(rx1, 0, rz0), Vector3.new(rx1, 0, rz1), {})
	roomWall(Vector3.new(rx0, 0, rz0), Vector3.new(rx1, 0, rz0), {})
	add(
		"RoomRoof",
		Vector3.new(rx1 - rx0 + 2, 2, rz1 - rz0 + 2),
		Vector3.new((rx0 + rx1) / 2, 11, (rz0 + rz1) / 2),
		CONCRETE
	)
	local grenadePad = add("GrenadePad", Vector3.new(4, 0.4, 4), Vector3.new(66, 0.2, -54), {
		Color = Color3.fromRGB(80, 200, 120),
		Material = Enum.Material.Neon,
	})
	grenadePad:SetAttribute("Pickup", "Grenades")
	grenadePad.Parent = map:FindFirstChild("WeaponPickups")

	-- Una duna en el carril norte: dos rampas que forman una loma de 3 studs (el jeep salta)
	slope(folder, "Dune", at(Vector3.new(28, 0, 52)), at(Vector3.new(40, 3, 52)), 16, SAND)
	slope(folder, "Dune", at(Vector3.new(52, 0, 52)), at(Vector3.new(40, 3, 52)), 16, SAND)

	-- Muro divisorio entre los dos carriles, con huecos para cruzar
	for _, segment in { { 24, 44 }, { 52, 72 }, { 80, 100 } } do
		local length = segment[2] - segment[1]
		add("Divider", Vector3.new(length, 6, 2), Vector3.new((segment[1] + segment[2]) / 2, 3, 0), CONCRETE)
	end

	-- Coberturas en los carriles: barreras, cajas, contenedores, sacos de arena y pilares
	local barrier = Vector3.new(8, 3.5, 2)
	local crate = Vector3.new(4, 4, 4)
	local container = Vector3.new(16, 8, 7)
	add("Barrier", barrier, Vector3.new(20, barrier.Y / 2, 26), CONCRETE, 10)
	add("Barrier", barrier, Vector3.new(38, barrier.Y / 2, -26), CONCRETE, -20)
	add("Barrier", barrier, Vector3.new(112, barrier.Y / 2, -8), CONCRETE, 90)
	add("Barrier", barrier, Vector3.new(88, barrier.Y / 2, -32), CONCRETE, 30)
	add("Crate", crate, Vector3.new(34, crate.Y / 2, 14), WOOD)
	add("Crate", crate, Vector3.new(35, crate.Y * 1.5, 14), WOOD, 25)
	add("Crate", crate, Vector3.new(90, crate.Y / 2, 30), WOOD, 10)
	add("Crate", crate, Vector3.new(94, crate.Y / 2, 34), WOOD, -15)
	add("Crate", crate, Vector3.new(128, crate.Y / 2, -26), WOOD, 40)
	add("Container", container, Vector3.new(66, container.Y / 2, -20), METAL)
	add("Container", container, Vector3.new(122, container.Y / 2, 30), METAL, 90)
	add("Sandbags", Vector3.new(10, 2.5, 2), Vector3.new(100, 1.25, 22), SANDBAG)
	add("Sandbags", Vector3.new(10, 2.5, 2), Vector3.new(56, 1.25, 40), SANDBAG, -10)
	add("Pillar", Vector3.new(3, 10, 3), Vector3.new(18, 5, 18), CONCRETE)
	add("Pillar", Vector3.new(3, 10, 3), Vector3.new(18, 5, -18), CONCRETE)

	-- Jeep: aparece frente a la base, mirando hacia el centro
	local jeepSpawns = workspace:FindFirstChild("VehicleSpawns") :: Folder
	local marker = Instance.new("Part")
	marker.Name = "JeepSpawn" .. team.name
	marker.Anchored = true
	marker.Size = Vector3.new(8, 1, 12)
	local jeepPosition = at(Vector3.new(140, 1, 10))
	marker.CFrame = CFrame.lookAt(jeepPosition, Vector3.new(0, 1, jeepPosition.Z))
	marker.Parent = jeepSpawns
end

-- Plataformas de armas que no son de ningún equipo
local function buildPickups(map: Folder)
	local pickups = Instance.new("Folder")
	pickups.Name = "WeaponPickups"
	pickups.Parent = map
	-- El lanzacohetes, en lo alto del montículo central: muy expuesto, como pide el diseño
	local pad = Instance.new("Part")
	pad.Name = "RocketLauncherPad"
	pad.Anchored = true
	pad.Size = Vector3.new(4, 0.4, 4)
	pad.CFrame = CFrame.new(0, MOUND_HEIGHT + 0.2, 0)
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
		local vehicleSpawns = Instance.new("Folder")
		vehicleSpawns.Name = "VehicleSpawns"
		vehicleSpawns.Parent = workspace
		buildCanyon(map)
		buildPickups(map)
		for _, team in TEAMS do
			buildHalf(map, team)
		end
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
