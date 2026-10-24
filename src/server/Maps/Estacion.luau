-- Mapa "La Estación": inspirado en Derelict de Halo CE, el que mandó edwing. Es un cuarto
-- octagonal cerrado (con techo) y de dos pisos:
--
--   * Abajo: el piso grande, con columnas bajo los puentes, cajas y rejillas de luz verde.
--     Junto a los muros, bajo el anillo de arriba, queda un pasillo techado todo alrededor.
--   * Arriba (a 14 studs): un anillo que corre pegado a los 8 muros, una plataforma
--     octagonal en el centro y 4 puentes en cruz que la unen con el anillo.
--
-- En Halo se subía con teletransportes; aquí hay 4 rampas, una en cada esquina diagonal,
-- que suben del piso de abajo al anillo. Desde arriba se puede saltar abajo en cualquier lado.
--
-- Vista desde arriba (el Rojo está en +X, a la derecha; el Azul es igual, girado 180°):
--
--              muro N
--         /------||------\
--        / rampa ||  rampa\          || = puentes en cruz (arriba)
--       |   ======[]======  |        [] = plataforma del centro (arriba)
--        \ rampa ||  rampa/          el anillo de arriba va pegado a todos los muros
--         \------||------/
--              muro S
--
-- Medidas desde el centro del mapa. "Apotema" = distancia del centro a un lado del octágono.

local Builder = require(script.Parent.Builder)

local Estacion = {}

-- Colores y materiales de este mapa: metal azul oscuro, como una estación espacial
local FLOOR = { Color = Color3.fromRGB(52, 68, 74), Material = Enum.Material.Slate }
local DECK = { Color = Color3.fromRGB(78, 92, 116), Material = Enum.Material.DiamondPlate }
local WALL = { Color = Color3.fromRGB(62, 72, 96), Material = Enum.Material.Concrete }
local CEILING = { Color = Color3.fromRGB(40, 48, 66), Material = Enum.Material.Concrete }
local PILLAR = { Color = Color3.fromRGB(96, 106, 124), Material = Enum.Material.Concrete }
local CRATE = { Color = Color3.fromRGB(74, 84, 100), Material = Enum.Material.Metal }
local GLOW_BLUE = { Color = Color3.fromRGB(110, 190, 255), Material = Enum.Material.Neon }
local GLOW_GREEN = { Color = Color3.fromRGB(120, 255, 170), Material = Enum.Material.Neon }

local APOTHEM = 100 -- del centro a los muros, por dentro
local WALL_THICK = 4
local HEIGHT = 56 -- del piso al techo (alto, para que quepan las granadas y los SimiOs)
local UPPER = 14 -- altura del piso de arriba
local RING = 12 -- ancho del anillo de arriba
local CENTER = 18 -- apotema de la plataforma del centro
local BRIDGE = 14 -- ancho de los puentes
local SLAB = 1 -- grosor de los pisos de arriba

local TAN = math.tan(math.rad(22.5)) -- para el largo del lado de un octágono

-- Dirección (en el piso) que apunta hacia el ángulo dado, en grados
local function direction(degrees: number): Vector3
	local angle = math.rad(degrees)
	return Vector3.new(math.cos(angle), 0, math.sin(angle))
end

-- CFrame girado para que su eje X local apunte hacia el ángulo dado
local function facing(position: Vector3, degrees: number): CFrame
	return CFrame.new(position) * CFrame.Angles(0, -math.rad(degrees), 0)
end

-- Un octágono plano con apotema a: se forma con 4 rectángulos de 2a × lado, girados 45°
-- entre sí (juntos llenan exactamente el octágono)
local function octagon(parent: Instance, name: string, apothem: number, y: number, thickness: number, style)
	local side = 2 * apothem * TAN
	for k = 0, 3 do
		Builder.block(
			parent,
			name,
			Vector3.new(2 * apothem, thickness, side),
			facing(Vector3.new(0, y, 0), k * 45),
			style
		)
	end
end

-- Lo que no es de ningún equipo: piso, muros, techo, anillo, puentes, centro, columnas
local function buildShell(map: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "Estacion"
	folder.Parent = map

	local outer = APOTHEM + WALL_THICK
	Builder.block(folder, "Floor", Vector3.new(outer * 2 + 8, 2, outer * 2 + 8), CFrame.new(0, -1, 0), FLOOR)
	-- El techo no lo tocan las balas ni la mira (nadie está encima); solo cierra el cuarto
	local ceiling = Builder.block(
		folder,
		"Ceiling",
		Vector3.new(outer * 2 + 8, 2, outer * 2 + 8),
		CFrame.new(0, HEIGHT + 1, 0),
		CEILING
	)
	ceiling.CanQuery = false

	for k = 0, 7 do
		local angle = k * 45
		local out = direction(angle)
		-- Muro de este lado del octágono
		Builder.block(
			folder,
			"Wall",
			Vector3.new(WALL_THICK, HEIGHT, 2 * outer * TAN),
			facing(out * (APOTHEM + WALL_THICK / 2) + Vector3.new(0, HEIGHT / 2, 0), angle),
			WALL
		)
		-- Anillo de arriba, pegado al muro
		Builder.block(
			folder,
			"Ring",
			Vector3.new(RING, SLAB, 2 * APOTHEM * TAN),
			facing(out * (APOTHEM - RING / 2) + Vector3.new(0, UPPER - SLAB / 2, 0), angle),
			DECK
		)
		-- Franja de luz en el muro, a la altura del pasillo de abajo y del anillo
		for _, y in { 6, UPPER + 8 } do
			Builder.block(
				folder,
				"WallLight",
				Vector3.new(0.4, 0.6, 2 * APOTHEM * TAN * 0.6),
				facing(out * (APOTHEM - 0.2) + Vector3.new(0, y, 0), angle),
				GLOW_BLUE
			)
		end
		-- Columnas bajo el borde del anillo, en cada esquina del octágono
		local corner = direction(angle + 22.5) * ((APOTHEM - RING + 1) / math.cos(math.rad(22.5)))
		Builder.block(
			folder,
			"Pillar",
			Vector3.new(3, UPPER - SLAB, 3),
			CFrame.new(corner + Vector3.new(0, (UPPER - SLAB) / 2, 0)),
			PILLAR
		)
	end

	-- Plataforma del centro y su borde de luz
	octagon(folder, "CenterDeck", CENTER, UPPER - SLAB / 2, SLAB, DECK)
	-- Columnas que la sostienen (también son cobertura abajo)
	for k = 0, 3 do
		local spot = direction(45 + k * 90) * (CENTER - 4)
		Builder.block(
			folder,
			"Pillar",
			Vector3.new(4, UPPER - SLAB, 4),
			CFrame.new(spot + Vector3.new(0, (UPPER - SLAB) / 2, 0)),
			PILLAR
		)
	end

	-- 4 puentes en cruz, del centro al anillo, con una línea de luz al medio
	local bridgeLength = APOTHEM - RING - CENTER + 2
	local bridgeMiddle = CENTER - 1 + bridgeLength / 2
	for k = 0, 3 do
		local angle = k * 90
		local out = direction(angle)
		Builder.block(
			folder,
			"Bridge",
			Vector3.new(bridgeLength, SLAB, BRIDGE),
			facing(out * bridgeMiddle + Vector3.new(0, UPPER - SLAB / 2, 0), angle),
			DECK
		)
		Builder.block(
			folder,
			"BridgeLight",
			Vector3.new(bridgeLength, 0.1, 0.5),
			facing(out * bridgeMiddle + Vector3.new(0, UPPER + 0.05, 0), angle),
			GLOW_BLUE
		)
		-- Columnas bajo el puente: el paso de abajo queda libre a los lados
		for _, distance in { 38, 62 } do
			Builder.block(
				folder,
				"Pillar",
				Vector3.new(4, UPPER - SLAB, 4),
				CFrame.new(out * distance + Vector3.new(0, (UPPER - SLAB) / 2, 0)),
				PILLAR
			)
		end
	end

	-- Luces: unas pocas lámparas en el techo y bajo la plataforma del centro
	for k = 0, 7 do
		local lamp = Builder.block(
			folder,
			"CeilingLight",
			Vector3.new(6, 0.4, 6),
			CFrame.new(direction(k * 45 + 22.5) * 55 + Vector3.new(0, HEIGHT - 0.2, 0)),
			GLOW_BLUE
		)
		local light = Instance.new("PointLight")
		light.Color = GLOW_BLUE.Color
		light.Range = 45
		light.Brightness = 1.2
		light.Parent = lamp
	end
	local underLamp = Builder.block(
		folder,
		"CenterLight",
		Vector3.new(4, 0.3, 4),
		CFrame.new(0, UPPER - SLAB - 0.15, 0),
		GLOW_GREEN
	)
	local underLight = Instance.new("PointLight")
	underLight.Color = GLOW_GREEN.Color
	underLight.Range = 30
	underLight.Brightness = 1
	underLight.Parent = underLamp

	-- Armas en el centro: lanzacohetes arriba, lanzallamas abajo
	Builder.pickupPad(map, "RocketLauncherPad", Vector3.new(0, UPPER + 0.2, 0), "Weapon", "RocketLauncher")
	Builder.pickupPad(map, "FlamethrowerPad", Vector3.new(6, 0.2, 6), "Weapon", "Flamethrower")
end

-- Lo de cada equipo. Todo se escribe para el Rojo (+X); el Azul es igual, girado 180°
local function buildHalf(map: Folder, team)
	local half = Builder.half(map, team)

	-- Rampas en las dos esquinas diagonales de este lado (a 45° y a -45°): suben del piso
	-- de abajo hasta el borde del anillo
	for _, angle in { 45, -45 } do
		local out = direction(angle)
		local ringEdge = APOTHEM - RING
		half.slope("Ramp", out * (ringEdge - 44), out * ringEdge + Vector3.new(0, UPPER, 0), 12, DECK)
		-- Rejilla de luz verde en el piso, junto a la rampa
		local side = direction(angle + 90) * 14
		half.add(
			"FloorGrate",
			Vector3.new(8, 0.1, 5),
			out * 50 + side + Vector3.new(0, 0.05, 0),
			GLOW_GREEN,
			-angle
		)
	end

	-- Puntos de aparición: dos arriba en el anillo del muro este y dos abajo, en el pasillo
	-- techado bajo el anillo
	local spawnX = APOTHEM - RING / 2
	half.spawn(Vector3.new(spawnX, UPPER + 0.5, 26))
	half.spawn(Vector3.new(spawnX, UPPER + 0.5, -26))
	half.spawn(Vector3.new(spawnX, 0.5, 30))
	half.spawn(Vector3.new(spawnX, 0.5, -30))
	-- Franja del color del equipo en el muro de su lado
	half.add("TeamStripe", Vector3.new(0.4, 2, 50), Vector3.new(APOTHEM - 0.2, UPPER + 12, 0), half.stripe)
	half.add("TeamStripe", Vector3.new(0.4, 1, 50), Vector3.new(APOTHEM - 0.2, 10, 0), half.stripe)

	-- Bandera: arriba, en la esquina del anillo a 45° (lo más al fondo de este lado)
	half.flagStand(direction(45) * (APOTHEM - RING / 2) + Vector3.new(0, UPPER, 0))

	-- Cobertura abajo: cajas y muretes en los cuadrantes de este lado
	half.add("Crate", Vector3.new(5, 5, 5), Vector3.new(58, 2.5, 30), CRATE, 15)
	half.add("Crate", Vector3.new(5, 5, 5), Vector3.new(30, 2.5, -56), CRATE, -20)
	half.add("Barrier", Vector3.new(2, 3.5, 10), Vector3.new(34, 1.75, 22), PILLAR, 30)
	half.add("Barrier", Vector3.new(2, 3.5, 10), Vector3.new(66, 1.75, -26), PILLAR, -10)
	-- Cobertura arriba, en el puente de este lado
	half.add("Barrier", Vector3.new(2, 3, 8), Vector3.new(50, UPPER + 1.5, 0), PILLAR)

	-- Armas de este lado
	half.pickup(
		"SniperPad",
		direction(-45) * (APOTHEM - RING / 2) + Vector3.new(0, UPPER + 0.2, 0),
		"Weapon",
		"Sniper"
	)
	half.pickup("ShotgunPad", Vector3.new(30, 0.2, 58), "Weapon", "Shotgun")
	half.pickup("IceGunPad", Vector3.new(58, 0.2, -28), "Weapon", "IceGun")
	half.pickup("LaserRiflePad", Vector3.new(0, UPPER + 0.2, 60), "Weapon", "LaserRifle")
	half.pickup("GrenadePad", Vector3.new(52, 0.2, 0), "Pickup", "Grenades")
end

function Estacion.Build(map: Folder)
	buildShell(map)
	for _, team in Builder.TEAMS do
		buildHalf(map, team)
	end
end

return Estacion
