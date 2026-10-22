-- Mapa "El Cruce": inspirado en Rat Race de Halo CE, el mapa que eligió edwing.
--
-- La base Azul está en lo alto, al noroeste (14 studs). De ahí bajan tres rampas: una al
-- cuarto oeste, un pasillo largo al cuarto este y un túnel hacia el centro. En medio hay
-- muros y túneles techados que cruzan el mapa de lado a lado, así que no hay líneas de tiro
-- largas. La base Roja es el cuarto grande del sur, con columnas.
--
-- El plano está dibujado abajo, en PLAN: cada letra es una celda de 5 × 5 studs.
--   #  muro
--   .  piso (abajo)
--   t  túnel: piso con techo
--   ^  piso alto (base Azul)
--   R  rampa al aire libre      r  rampa dentro de un túnel   (ver RAMPS)
--   P  columna en el piso de abajo      p  columna en el piso alto
-- El norte está arriba. Cambia una letra y el mapa cambia la próxima vez que pruebes.

local Builder = require(script.Parent.Builder)

local CONCRETE, DARK, ASPHALT = Builder.CONCRETE, Builder.DARK_CONCRETE, Builder.ASPHALT
local PLATE = Builder.PLATE

local Cruce = {}

local CELL = 5 -- studs por celda
local WALL_TOP = 32 -- altura de los muros
local HIGH = 14 -- altura del piso alto
local TUNNEL_HEIGHT = 12 -- del piso al techo de los túneles
local COLUMN_HEIGHT = 10

-- 72 columnas × 60 filas: unos 360 × 300 studs
local PLAN = {
	"########################################################################",
	"###^^^^^^^^^^^^^^^^^^^^^^^^^^###########################################",
	"###^^^^^^^^^^^^^^^^^^^^^^^^^^###########################################",
	"###^^^^^^^^^^^^^^^^^^^^^^^^^^###########################################",
	"#^^^^^^^^^^^^^^^^^^^^^^^^^^^^###########################################",
	"#^^^^^^^^^^^^^^^^^^^^^^^^^^^^###########################################",
	"#^^^^^^^^^^pp^^^^^^^^pp^^^^^^###########################################",
	"#^^^^^^^^^^pp^^^^^^^^pp^^^^^^###########################################",
	"#^^^^^^^^^^^^^^^^^^^^^^^^^^^^#########################......##.....#####",
	"#^^^^^^^^^^^^^^^^^^^^^^^^^^^^#########################......##......####",
	"#^^^^^^^^^^^^^^^^^^^^^^^^^^^^RRRRRRRRRRRRRRRRRRR######...............###",
	"#^^^^^^^^^^^^^^^^^^^^^^^^^^^^RRRRRRRRRRRRRRRRRRRRRRRRR.............#####",
	"#^^^^^^^^^^pp^^^^^^^^pp^^^^^^RRRRRRRRRRRRRRRRRRRRRRRRR.............#####",
	"#^^^^^^^^^^pp^^^^^^^^pp^^^^^^RRRRRRRRRRRRRRRRRRRRRRRRR.............#####",
	"#^^^^^^^^^^^^^^^^^^^^^^^^^^^^RRRRRRRRRRRRRRRRRRRRRRRRR.............#####",
	"#^^^^^^^^^^^^^^^^^^^^^^^^^^^^#########################.....PPP......####",
	"###^^^^^^^^^^^^^^^^^^^^^^^^^^rrrrrrrrrrrrttttt########.....PPP........##",
	"###^^^^^^^^^^^^^^^^^^^^^^^^^^rrrrrrrrrrrrtttttt#######.....PPP........##",
	"###^^^^^^^^^^^^^^^^^^^^^^^^^^rrrrrrrrrrrrtt##ttt######................##",
	"###RRRRRRRRR##################rrrrrrrrrrrttttttt######................##",
	"###RRRRRRRR#############################ttttttttt#####................##",
	"###RRRRRRRR#####################ttttttt##tttttttt#####................##",
	"##RRRRRRRRR#####################tttttttt##ttttttt#####................##",
	"##RRRRRRRRR#############tttttttttttttttt##ttttttt#####................##",
	"##RRRRRRRRR#########ttttttttttttttttttttttttttttt#####.....PPP........##",
	"##RRRRRRRRR#######ttttttttttttttttttttttttttttttt#####.....PPP........##",
	"##RRRRRRRRR#####ttttttttttttttttttttttttttttttttt#####.....PPP........##",
	"#............tttttttttttttttttttttttttttttttttttt#######..............##",
	"#............tttttttttttttttttttttttttttttttttttt#######..........######",
	"#............tttttttttttttttttttttttttttttttttttt#######..........######",
	"#............ttttttttttt...............tttttttttt#######.........#######",
	"#............tttttttttt..............######ttttttt#######........#######",
	"#............ttttttttt...............#######ttttttt#######......########",
	"#............tttttttt................########tttttt#######......########",
	"#....................................########ttttttt#####........#######",
	"#....................................#########ttttttt#####.....#########",
	"####......#################..........##########tttttt#####.....#########",
	"####......#################..........##########ttttttt####......########",
	"###########################..........###########ttttttt##........#######",
	"###########################..........############ttttttttttttt...#######",
	"###########################..........###########tttttttttttttt...#######",
	"###########################.....................ttttttttttttttt..#######",
	"#########################........................tttttttttttttt......###",
	"#########################........................tttttttttttttt......###",
	"#########################........................ttttttttttttttt......##",
	"#########################....PP.......PP.......PP......PP.......PP....##",
	"#######################......PP.......PP.......PP......PP.......PP.....#",
	"#######################................................................#",
	"#######################................................................#",
	"#######################................................................#",
	"#######################................................................#",
	"#######################......PP.......PP.......PP......PP.......PP.....#",
	"#########################....PP.......PP.......PP......PP.......PP....##",
	"#########################.............................................##",
	"#########################............................................###",
	"##########################.............................#################",
	"###########################.......................######################",
	"############################........####################################",
	"############################........####################################",
	"########################################################################",
}

-- Las rampas: un rectángulo de celdas (filas y columnas de PLAN, contando desde 1) y el lado
-- que queda arriba ("N", "S", "E" u "O"). tunnel = true si lleva techo.
local RAMPS = {
	{ rows = { 20, 27 }, columns = { 2, 12 }, high = "N", tunnel = false },
	{ rows = { 11, 15 }, columns = { 30, 54 }, high = "O", tunnel = false },
	{ rows = { 17, 20 }, columns = { 30, 41 }, high = "O", tunnel = true },
}

-- Puntos importantes, como {fila, columna} de PLAN
local SPAWNS = {
	Azul = { { 4, 6 }, { 4, 27 }, { 17, 6 }, { 17, 27 } },
	Rojo = { { 55, 28 }, { 55, 68 }, { 55, 47 }, { 46, 68 } },
}
local FLAGS = { Azul = { 9, 8 }, Rojo = { 48, 65 } } -- base de la bandera (para Captura la bandera)
local GRENADES = { { 31, 3 }, { 22, 61 }, { 10, 4 }, { 49, 27 } }
local ROCKET = { 27, 35 } -- el lanzacohetes, a medio túnel

local COLUMNS, ROWS = #PLAN[1], #PLAN

-- Centro de la celda (fila, columna), en studs. El centro del mapa queda en (0, 0)
local function cellCenter(row: number, column: number): (number, number)
	return (column - 0.5 - COLUMNS / 2) * CELL, (row - 0.5 - ROWS / 2) * CELL
end

local function cellAt(row: number, column: number): string
	return string.sub(PLAN[row], column, column)
end

-- Altura del piso en una celda
local function floorHeight(row: number, column: number): number
	local cell = cellAt(row, column)
	return if cell == "^" or cell == "p" then HIGH else 0
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
	Builder.block(
		parent,
		name,
		Vector3.new(x1 - x0 + CELL, y1 - y0, z1 - z0 + CELL),
		CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		style
	)
end

local function fill(parent: Instance, name: string, letters: string, y0: number, y1: number, style)
	for _, rect in
		rectangles(function(cell)
			return string.find(letters, cell, 1, true) ~= nil
		end)
	do
		fillCells(parent, name, rect, y0, y1, style)
	end
end

local function buildGround(map: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "Ground"
	folder.Parent = map
	fill(folder, "Floor", ".tRrPp^", -2, 0, ASPHALT) -- piso bajo todo lo que no es muro
	fill(folder, "Wall", "#", -2, WALL_TOP, CONCRETE)
	fill(folder, "HighFloor", "^p", 0, HIGH, DARK)
	fill(folder, "Column", "P", 0, COLUMN_HEIGHT, DARK)
	fill(folder, "Column", "p", HIGH, HIGH + COLUMN_HEIGHT, DARK)
	-- El techo de los túneles es un bloque macizo hasta lo alto de los muros: nadie camina encima
	fill(folder, "TunnelRoof", "t", TUNNEL_HEIGHT, WALL_TOP, CONCRETE)
end

-- Cada rampa es una losa inclinada; si va en un túnel, lleva encima un techo inclinado igual
local function buildRamps(map: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "Ramps"
	folder.Parent = map
	for _, ramp in RAMPS do
		local x0 = (ramp.columns[1] - 1 - COLUMNS / 2) * CELL
		local x1 = (ramp.columns[2] - COLUMNS / 2) * CELL
		local z0 = (ramp.rows[1] - 1 - ROWS / 2) * CELL
		local z1 = (ramp.rows[2] - ROWS / 2) * CELL
		local xMid, zMid = (x0 + x1) / 2, (z0 + z1) / 2
		local low, high, width
		if ramp.high == "N" or ramp.high == "S" then
			local highZ, lowZ = if ramp.high == "N" then z0 else z1, if ramp.high == "N" then z1 else z0
			low, high, width = Vector3.new(xMid, 0, lowZ), Vector3.new(xMid, HIGH, highZ), x1 - x0
		else
			local highX, lowX = if ramp.high == "O" then x0 else x1, if ramp.high == "O" then x1 else x0
			low, high, width = Vector3.new(lowX, 0, zMid), Vector3.new(highX, HIGH, zMid), z1 - z0
		end
		local slab = Builder.slope(folder, "Ramp", low, high, width, PLATE)
		if ramp.tunnel then
			-- Grosor justo para que arriba de la rampa llegue a lo alto de los muros
			local thickness = WALL_TOP - TUNNEL_HEIGHT - HIGH
			Builder.block(
				folder,
				"TunnelRoof",
				Vector3.new(width, thickness, slab.Size.Z),
				slab.CFrame * CFrame.new(0, 0.5 + TUNNEL_HEIGHT + thickness / 2, 0),
				CONCRETE
			)
		end
	end
end

-- Posición sobre el piso de una celda {fila, columna}
local function onFloor(cell: { number }, lift: number): Vector3
	local x, z = cellCenter(cell[1], cell[2])
	return Vector3.new(x, floorHeight(cell[1], cell[2]) + lift, z)
end

local function buildPoints(map: Folder)
	for _, team in Builder.TEAMS do
		local folder = Instance.new("Folder")
		folder.Name = "Base" .. team.name
		folder.Parent = map
		for _, cell in SPAWNS[team.name] do
			Builder.spawn(folder, team, onFloor(cell, 0.5), Vector3.zero)
		end
		local flagStand = Builder.block(
			folder,
			"FlagStand",
			Vector3.new(4, 0.2, 4),
			CFrame.new(onFloor(FLAGS[team.name], 0.1)),
			{ Color = team.color.Color, Material = Enum.Material.Neon }
		)
		flagStand:SetAttribute("Team", team.name)
	end
	for _, cell in GRENADES do
		Builder.pickupPad(map, "GrenadePad", onFloor(cell, 0.2), "Pickup", "Grenades")
	end
	Builder.pickupPad(map, "RocketLauncherPad", onFloor(ROCKET, 0.2), "Weapon", "RocketLauncher")
end

-- Construye todo el mapa dentro de la carpeta map
function Cruce.Build(map: Folder)
	buildGround(map)
	buildRamps(map)
	buildPoints(map)
end

return Cruce
