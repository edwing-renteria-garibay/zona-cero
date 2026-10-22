-- Mapa "El Cruce": inspirado en un mapa de Halo CE que eligió edwing. Cuatro zonas en las
-- orillas (cuarto noroeste, cuarto este, cuarto oeste y cuarto sur) unidas por pasillos, y en
-- medio un abismo con una plataforma alta y tres puentes en forma de Y.
-- En lugar de teletransportes hay un corredor por fuera (oeste, sur y este) para flanquear.
--
-- El plano está dibujado abajo, en PLAN: cada letra es una celda de 5 × 5 studs.
--   #  muro alto (no se puede subir)
--   .  piso
--   P  pilar o muro bajo para cubrirse
--   o  abismo: si caes, mueres
-- El norte está arriba. Cambia una letra y el mapa cambia la próxima vez que pruebes.

local Builder = require(script.Parent.Builder)

local CONCRETE, DARK, ASPHALT = Builder.CONCRETE, Builder.DARK_CONCRETE, Builder.ASPHALT
local PLATE, METAL = Builder.PLATE, Builder.METAL

local Cruce = {}

local CELL = 5 -- studs por celda
local WALL_HEIGHT = 20
local PILLAR_HEIGHT = 8
local RAIL_HEIGHT = 3 -- barandal: se dispara por encima pero no te caes por accidente
local HUB_HEIGHT = 8 -- plataforma del centro
local PIT_DEPTH = 40

-- 44 columnas × 41 filas
local PLAN = {
	"############################################",
	"###..................#######################",
	"###..................#######################",
	"####.....................#####.........#####",
	"####.......PPP..............##.........#####",
	"####.......PPP.........................#####",
	"####...................................#####",
	"####.................oooo..............#####",
	"####...................oooooo..........#####",
	"####.....................ooooo...PP......###",
	"####.......oooooooooooo..ooooo.............#",
	"####.......ooooooooooooo.ooooo.............#",
	"####.......ooooooooooooooooooo.............#",
	"###.......oooooooooooooooooooo.............#",
	"###.......oooooooooooooooooooo...PP.....#..#",
	"###.......oooooooooooooooooooo.........##..#",
	"###.......oooooooooooooooooooo.........##..#",
	"##.......ooooooooooooooooooooo.........##P.#",
	"##.......ooooooooooooooooooooo.........##..#",
	"#..............ooooooooooooooo.........##..#",
	"#.......................oooooo.........##..#",
	"#......................oooooooo......####..#",
	"#......................ooooooooo....#####..#",
	"#......................ooooooooo....#####..#",
	"####....##########.....ooooooooo....#####..#",
	"####..#############.....oooooooo....#####.P#",
	"####..#############......ooooooo....#####..#",
	"####..#############......ooooooo.....####..#",
	"####..##########.............oooo....####..#",
	"####..##########.............oooo....####..#",
	"####..#########........................##..#",
	"####P.#########........................##..#",
	"####..#########.......PP...............##..#",
	"####..#########........................##..#",
	"####..#########........................##..#",
	"####..#########.......................###..#",
	"####..##########..............###########..#",
	"####..##############.....################..#",
	"####.........P.............................#",
	"####...........................P...........#",
	"############################################",
}

local COLUMNS, ROWS = #PLAN[1], #PLAN

-- Centro de la celda (fila, columna), en studs. El centro del mapa queda en (0, 0)
local function cellCenter(row: number, column: number): (number, number)
	return (column - 0.5 - COLUMNS / 2) * CELL, (row - 0.5 - ROWS / 2) * CELL
end

local function cellAt(row: number, column: number): string
	local line = PLAN[row]
	return if line then string.sub(line, column, column) else "#"
end

-- Junta celdas iguales en rectángulos, para no crear una pieza por celda.
-- Devuelve una lista de {fila1, fila2, columna1, columna2}
local function rectangles(isWanted: (string) -> boolean): { { number } }
	local result = {}
	local open = {} -- rectángulos que todavía pueden crecer hacia abajo, por "col1:col2"
	for row = 1, ROWS do
		local nextOpen = {}
		local column = 1
		while column <= COLUMNS do
			if isWanted(cellAt(row, column)) then
				local last = column
				while last < COLUMNS and isWanted(cellAt(row, last + 1)) do
					last += 1
				end
				local key = column .. ":" .. last
				local rect = open[key]
				if rect then
					rect[2] = row -- crece una fila más
				else
					rect = { row, row, column, last }
					table.insert(result, rect)
				end
				nextOpen[key] = rect
				column = last + 1
			else
				column += 1
			end
		end
		open = nextOpen
	end
	return result
end

-- Un bloque que cubre un rectángulo de celdas, desde la altura y0 hasta y1
local function fillCells(parent: Instance, name: string, rect: { number }, y0: number, y1: number, style)
	local x0, z0 = cellCenter(rect[1], rect[3])
	local x1, z1 = cellCenter(rect[2], rect[4])
	local width, depth = x1 - x0 + CELL, z1 - z0 + CELL
	Builder.block(
		parent,
		name,
		Vector3.new(width, y1 - y0, depth),
		CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		style
	)
end

-- Distancia (vista desde arriba) de un punto a un segmento: sirve para no poner
-- barandales donde llega un puente
local function distanceToSegment(p: Vector3, a: Vector3, b: Vector3): number
	local flatP, flatA, flatB = Vector3.new(p.X, 0, p.Z), Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z)
	local ab = flatB - flatA
	local t = math.clamp((flatP - flatA):Dot(ab) / ab:Dot(ab), 0, 1)
	return (flatP - (flatA + ab * t)).Magnitude
end

-- Los tres puentes: de la orilla de la plataforma (alto) al piso de una zona (bajo)
local HUB = { x0 = -15, x1 = 20, z0 = -37.5, z1 = -7.5 }
local BRIDGES = {
	{ name = "PuenteOeste", high = Vector3.new(-15, HUB_HEIGHT, -12.5), low = Vector3.new(-62.5, 0, 0) },
	{ name = "PuenteNorte", high = Vector3.new(12.5, HUB_HEIGHT, -37.5), low = Vector3.new(17.5, 0, -70) },
	{ name = "PuenteSur", high = Vector3.new(15, HUB_HEIGHT, -7.5), low = Vector3.new(55, 0, 37.5) },
}
local BRIDGE_WIDTH = 10

local function nearBridge(position: Vector3): boolean
	for _, bridge in BRIDGES do
		if distanceToSegment(position, bridge.high, bridge.low) < BRIDGE_WIDTH / 2 + 2 then
			return true
		end
	end
	return false
end

-- Barandal de una celda de largo, en el borde entre dos celdas
local function rail(parent: Instance, position: Vector3, alongX: boolean)
	if nearBridge(position) then
		return
	end
	local size = if alongX then Vector3.new(CELL, RAIL_HEIGHT, 0.6) else Vector3.new(0.6, RAIL_HEIGHT, CELL)
	Builder.block(parent, "Rail", size, CFrame.new(position + Vector3.new(0, RAIL_HEIGHT / 2, 0)), METAL)
end

local function buildGround(map: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "Ground"
	folder.Parent = map

	local function isFloor(cell: string): boolean
		return cell == "." or cell == "P"
	end
	for _, rect in rectangles(isFloor) do
		fillCells(folder, "Floor", rect, -2, 0, ASPHALT)
	end
	for _, rect in
		rectangles(function(cell)
			return cell == "#"
		end)
	do
		fillCells(folder, "Wall", rect, -PIT_DEPTH, WALL_HEIGHT, CONCRETE)
	end
	for _, rect in
		rectangles(function(cell)
			return cell == "P"
		end)
	do
		fillCells(folder, "Pillar", rect, 0, PILLAR_HEIGHT, DARK)
	end

	-- Fondo del abismo (se ve oscuro desde arriba) y la zona que mata al caer
	local width, depth = COLUMNS * CELL, ROWS * CELL
	Builder.block(
		folder,
		"PitBottom",
		Vector3.new(width, 2, depth),
		CFrame.new(0, -PIT_DEPTH - 1, 0),
		{ Color = Color3.fromRGB(20, 20, 25), Material = Enum.Material.Slate }
	)
	local killZone = Builder.block(
		folder,
		"KillZone",
		Vector3.new(width, 4, depth),
		CFrame.new(0, -PIT_DEPTH + 10, 0),
		CONCRETE
	)
	killZone.Transparency = 1
	killZone.CanCollide = false
	killZone.CanQuery = false
	killZone:SetAttribute("KillZone", true) -- MapService mata a quien la toca

	-- Barandales en cada orilla de piso que da al abismo
	for row = 1, ROWS do
		for column = 1, COLUMNS do
			if isFloor(cellAt(row, column)) then
				local x, z = cellCenter(row, column)
				local half = CELL / 2
				if cellAt(row - 1, column) == "o" then
					rail(folder, Vector3.new(x, 0, z - half), true)
				end
				if cellAt(row + 1, column) == "o" then
					rail(folder, Vector3.new(x, 0, z + half), true)
				end
				if cellAt(row, column - 1) == "o" then
					rail(folder, Vector3.new(x - half, 0, z), false)
				end
				if cellAt(row, column + 1) == "o" then
					rail(folder, Vector3.new(x + half, 0, z), false)
				end
			end
		end
	end
end

-- La plataforma del centro, los puentes y lo que hay arriba
local function buildCenter(map: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "Center"
	folder.Parent = map

	local hubX, hubZ = (HUB.x0 + HUB.x1) / 2, (HUB.z0 + HUB.z1) / 2
	local hubWidth, hubDepth = HUB.x1 - HUB.x0, HUB.z1 - HUB.z0
	Builder.block(
		folder,
		"Hub",
		Vector3.new(hubWidth, 2, hubDepth),
		CFrame.new(hubX, HUB_HEIGHT - 1, hubZ),
		DARK
	)
	-- Columna que sostiene la plataforma desde el fondo del abismo
	local columnHeight = HUB_HEIGHT - 2 + PIT_DEPTH
	Builder.block(
		folder,
		"HubColumn",
		Vector3.new(10, columnHeight, 10),
		CFrame.new(hubX, HUB_HEIGHT - 2 - columnHeight / 2, hubZ),
		CONCRETE
	)
	-- Pirámide del centro: un escalón para cubrirse, con el lanzacohetes arriba
	Builder.block(
		folder,
		"Pyramid",
		Vector3.new(10, 3, 10),
		CFrame.new(hubX, HUB_HEIGHT + 1.5, hubZ),
		CONCRETE
	)
	Builder.pickupPad(
		map,
		"RocketLauncherPad",
		Vector3.new(hubX, HUB_HEIGHT + 3.2, hubZ),
		"Weapon",
		"RocketLauncher"
	)

	-- Barandales alrededor de la plataforma, con huecos donde llegan los puentes
	for x = HUB.x0 + CELL / 2, HUB.x1, CELL do
		rail(folder, Vector3.new(x, HUB_HEIGHT, HUB.z0), true)
		rail(folder, Vector3.new(x, HUB_HEIGHT, HUB.z1), true)
	end
	for z = HUB.z0 + CELL / 2, HUB.z1, CELL do
		rail(folder, Vector3.new(HUB.x0, HUB_HEIGHT, z), false)
		rail(folder, Vector3.new(HUB.x1, HUB_HEIGHT, z), false)
	end

	-- Cada puente es una rampa con barandales a los lados
	for _, bridge in BRIDGES do
		local slab = Builder.slope(folder, bridge.name, bridge.low, bridge.high, BRIDGE_WIDTH, PLATE)
		for _, side in { 1, -1 } do
			Builder.block(
				folder,
				"BridgeRail",
				Vector3.new(0.6, RAIL_HEIGHT, slab.Size.Z),
				slab.CFrame * CFrame.new(side * (BRIDGE_WIDTH / 2 - 0.3), 0.5 + RAIL_HEIGHT / 2, 0),
				METAL
			)
		end
	end
end

-- Puntos de aparición: Azul al oeste y noroeste, Rojo al este y al sur
local SPAWNS = {
	Azul = { { 2, 6 }, { 2, 17 }, { 22, 2 }, { 17, 4 } },
	Rojo = { { 4, 35 }, { 19, 36 }, { 34, 33 }, { 33, 18 } },
}
-- Granadas: pasillo norte, cuarto sur y a medio corredor de afuera
local GRENADES = { { 6, 18 }, { 33, 30 }, { 38, 22 } }

local function buildTeams(map: Folder)
	for _, team in Builder.TEAMS do
		local folder = Instance.new("Folder")
		folder.Name = "Spawns" .. team.name
		folder.Parent = map
		for _, cell in SPAWNS[team.name] do
			-- Las tablas de arriba usan filas y columnas contadas desde 0, como el dibujo
			local x, z = cellCenter(cell[1] + 1, cell[2] + 1)
			Builder.spawn(folder, team, Vector3.new(x, 0.5, z), Vector3.new(0, 0, -20))
		end
	end
	for _, cell in GRENADES do
		local x, z = cellCenter(cell[1] + 1, cell[2] + 1)
		Builder.pickupPad(map, "GrenadePad", Vector3.new(x, 0.2, z), "Pickup", "Grenades")
	end
end

-- Construye todo el mapa dentro de la carpeta map
function Cruce.Build(map: Folder)
	buildGround(map)
	buildCenter(map)
	buildTeams(map)
end

return Cruce
