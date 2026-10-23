-- Mapa "Cañón Rojo": un cañón largo con una base baja, una zona de spawn y una base alta
-- por equipo. Es el mapa estándar.
--
-- Vista desde arriba de la mitad Roja (+X). La mitad Azul es la misma, girada 180°:
--
--   z=+80 ==================== pared del cañón ====================================
--          [cornisa alta, a 8 studs, con rampas en las puntas]      |  BASE BAJA   |
--                                                                   |  (cerrada,   |
--      montículo       carril norte: cajas, contenedor, barreras    |  2 spawns)   |
--     con el lanza- ---- muro divisorio con huecos ----              ---------------
--     cohetes (x=0)    carril sur                                    ZONA DE SPAWN
--                         [cuarto lateral                            (2 spawns)
--                          con granadas]       rampa  /BASE ALTA\ ---- rampa roja
--          [cornisa alta]                             \(mesa 16)/
--   z=-80 ==================== pared del cañón ====================================
--                                                                        x=+200
-- Tres rutas entre bases: los carriles del centro, las cornisas altas junto a las paredes
-- y los cuartos laterales. No tiene jeeps: es muy chico para ellos (los vehículos van en
-- mapas grandes).

local Builder = require(script.Parent.Builder)

local block, slope = Builder.block, Builder.slope
local ROCK, SAND, CONCRETE = Builder.ROCK, Builder.SAND, Builder.CONCRETE
local SANDBAG, WOOD, METAL, PLATE = Builder.SANDBAG, Builder.WOOD, Builder.METAL, Builder.PLATE

local CanonRojo = {}

-- Medidas principales, en studs
local HALF_LENGTH = 200 -- del centro a la pared del fondo (eje X)
local HALF_WIDTH = 80 -- del centro a cada pared del cañón (eje Z)
local WALL_HEIGHT = 60
local LEDGE_HEIGHT = 8 -- cornisas junto a las paredes del cañón
local MESA_HEIGHT = 16 -- base alta
local MOUND_HEIGHT = 4 -- montículo del centro
local ROOM_HEIGHT = 14 -- paredes de las bases

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
	local half = Builder.half(map, team)
	local folder, stripe = half.folder, half.stripe
	local at, add, addSpawn = half.at, half.add, half.spawn

	-- Base baja: un cuarto cerrado en la esquina, con dos puertas angostas (8 studs:
	-- una persona pasa, un jeep no). Una da al centro y otra a la zona de spawn.
	local x0, x1, z0, z1 = 156, 198, 34, 78
	local h = ROOM_HEIGHT
	local function wall(from: Vector3, to: Vector3, gaps)
		local a, b = at(from), at(to)
		Builder.wallWithGaps(folder, "BaseWall", a, b, h, gaps, CONCRETE)
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
	Builder.wallWithGaps(
		folder,
		"Parapet",
		at(Vector3.new(mx0, p, mz1)),
		at(Vector3.new(mx1, p, mz1)),
		3,
		{ { 13, 23 } },
		CONCRETE
	)
	Builder.wallWithGaps(
		folder,
		"Parapet",
		at(Vector3.new(mx0, p, mz0)),
		at(Vector3.new(mx0, p, mz1)),
		3,
		{ { 12, 22 } },
		CONCRETE
	)
	Builder.wallWithGaps(
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
		Builder.wallWithGaps(folder, "RoomWall", at(from), at(to), 10, gaps, CONCRETE)
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
	half.pickup("GrenadePad", Vector3.new(66, 0.2, -54), "Pickup", "Grenades")

	-- Base de la bandera: en la esquina del fondo de la base baja
	half.flagStand(Vector3.new(192, 0, 72))

	-- Una duna en el carril norte: dos rampas que forman una loma de 3 studs
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
end

-- Construye todo el mapa dentro de la carpeta map
function CanonRojo.Build(map: Folder)
	buildCanyon(map)
	-- El lanzacohetes, en lo alto del montículo central: muy expuesto, como pide el diseño
	Builder.pickupPad(
		map,
		"RocketLauncherPad",
		Vector3.new(0, MOUND_HEIGHT + 0.2, 0),
		"Weapon",
		"RocketLauncher"
	)
	for _, team in Builder.TEAMS do
		buildHalf(map, team)
	end
	-- Armas especiales (ver Config/Weapons): francotirador y escopeta, una de cada lado;
	-- las demás a la misma distancia de las dos bases
	Builder.pickupPad(map, "SniperPad", Vector3.new(120, 0.2, -39), "Weapon", "Sniper")
	Builder.pickupPad(map, "SniperPad", Vector3.new(-120, 0.2, 39), "Weapon", "Sniper")
	Builder.pickupPad(map, "ShotgunPad", Vector3.new(30, 0.2, 6), "Weapon", "Shotgun")
	Builder.pickupPad(map, "ShotgunPad", Vector3.new(-30, 0.2, -6), "Weapon", "Shotgun")
	Builder.pickupPad(map, "LaserRiflePad", Vector3.new(-9, 0.2, 60), "Weapon", "LaserRifle")
	Builder.pickupPad(map, "IonCannonPad", Vector3.new(9, 0.2, -60), "Weapon", "IonCannon")
	Builder.pickupPad(map, "FlamethrowerPad", Vector3.new(-3, 0.2, 27), "Weapon", "Flamethrower")
	Builder.pickupPad(map, "IceGunPad", Vector3.new(3, 0.2, -30), "Weapon", "IceGun")
end

return CanonRojo
