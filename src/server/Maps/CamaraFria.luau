-- Mapa "Cámara Fría": inspirado en Chill Out de Halo CE, el que mandó edwing. Es un cuarto
-- rectangular cerrado (con techo) y de dos pisos. En Halo una base era distinta de la otra;
-- aquí las dos son iguales: cada base tiene su túnel con ventanas, como pidió edwing.
--
--   * Arriba (a 20 studs): una plataforma corrida pegada a cada muro de los lados, que une
--     las cubiertas de las dos bases. Al centro, unas pasarelas la unen con el puente que
--     cruza todo el mapa. Encima, sobre un poste, la plataforma del lanzacohetes, a la que
--     se sube por rampas angostas desde las plataformas de los lados.
--   * Cada base: una cubierta alta al fondo con la bandera. Debajo corre el túnel, con
--     ventanas que miran al centro.
--   * Abajo: el piso con cajas para cubrirse. Si te caes, subes por la escalera que hay en
--     medio de cada lado o por la rampa de una esquina de base, junto a su spawn.
--
-- Vista desde arriba (el Rojo está en +X, a la derecha; el Azul es igual, girado 180°):
--
--   +--------------------------------------------------------------+
--   |[==================== plataforma del lado ===================]|
--   |[cubierta]           pasarela  #  pasarela          [cubierta]|
--   |[ túnel  ]=========== puente ==[o]== puente =========[ túnel  ]|
--   |[cubierta]           pasarela  #  pasarela          [cubierta]|
--   |[==================== plataforma del lado ===================]|
--   +--------------------------------------------------------------+
--          [o] = plataforma del lanzacohetes     # = escalera
--
-- Medidas desde el centro del mapa: X va de base a base, Z de lado a lado.

local Builder = require(script.Parent.Builder)

local CamaraFria = {}

-- Colores y materiales de este mapa: concreto gris azulado y pisos claros, como en Chill Out
local FLOOR = { Color = Color3.fromRGB(120, 140, 150), Material = Enum.Material.Slate }
local DECK = { Color = Color3.fromRGB(178, 164, 140), Material = Enum.Material.Concrete }
local BEAM = { Color = Color3.fromRGB(46, 52, 60), Material = Enum.Material.DiamondPlate }
local WALL = { Color = Color3.fromRGB(84, 100, 110), Material = Enum.Material.Concrete }
local DARK = { Color = Color3.fromRGB(44, 50, 58), Material = Enum.Material.Concrete }
local CEILING = { Color = Color3.fromRGB(60, 72, 82), Material = Enum.Material.Concrete }
local PILLAR = { Color = Color3.fromRGB(96, 110, 120), Material = Enum.Material.Concrete }
local CRATE = { Color = Color3.fromRGB(130, 148, 156), Material = Enum.Material.Concrete }
local GLOW = { Color = Color3.fromRGB(170, 225, 255), Material = Enum.Material.Neon }

local HALF_LENGTH = 140 -- del centro a los muros de las bases, por dentro
local HALF_WIDTH = 70 -- del centro a los muros de los lados, por dentro
local WALL_THICK = 4
local HEIGHT = 56 -- del piso al techo
local UPPER = 20 -- altura del piso de arriba
local SLAB = 1 -- grosor de los pisos de arriba
local ROCKET_HEIGHT = 32 -- altura de la plataforma del lanzacohetes
local SHELF_FROM = 46 -- las plataformas de los lados van de z = 46 al muro (y de -46 al otro)
local CORNER_FROM = 96 -- desde x = 96, en la esquina de la base, hay hueco para una rampa
local CORNER_STRIP = 10 -- lo que queda de plataforma junto al hueco

-- Base de cada equipo (medidas en X, para el Rojo)
local TUNNEL_FROM = 106 -- el túnel va de x = 106 a x = 122, por debajo de la cubierta
local TUNNEL_TO = 122
local TUNNEL_CLEARANCE = 12 -- altura del túnel por dentro
local DECK_FROM = 104 -- la cubierta va de x = 104 hasta el muro
local DECK_HALF = 30 -- y de z = -30 a z = 30

-- Lo que no es de ningún equipo: piso, muros, techo, luces y el poste del centro
local function buildShell(map: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "CamaraFria"
	folder.Parent = map

	local outerX = HALF_LENGTH + WALL_THICK
	local outerZ = HALF_WIDTH + WALL_THICK
	Builder.block(
		folder,
		"Floor",
		Vector3.new(outerX * 2 + 8, 2, outerZ * 2 + 8),
		CFrame.new(0, -1, 0),
		FLOOR
	)
	-- El techo no lo tocan las balas ni la mira (nadie está encima); solo cierra el cuarto
	local ceiling = Builder.block(
		folder,
		"Ceiling",
		Vector3.new(outerX * 2 + 8, 2, outerZ * 2 + 8),
		CFrame.new(0, HEIGHT + 1, 0),
		CEILING
	)
	ceiling.CanQuery = false

	-- Muros: dos largos a los lados y dos cortos detrás de las bases
	for _, side in { 1, -1 } do
		Builder.block(
			folder,
			"Wall",
			Vector3.new(outerX * 2, HEIGHT, WALL_THICK),
			CFrame.new(0, HEIGHT / 2, side * (HALF_WIDTH + WALL_THICK / 2)),
			WALL
		)
		Builder.block(
			folder,
			"Wall",
			Vector3.new(WALL_THICK, HEIGHT, outerZ * 2),
			CFrame.new(side * (HALF_LENGTH + WALL_THICK / 2), HEIGHT / 2, 0),
			WALL
		)
		-- Franja de luz a lo largo de los muros de los lados
		Builder.block(
			folder,
			"WallLight",
			Vector3.new(HALF_LENGTH * 1.4, 0.6, 0.4),
			CFrame.new(0, UPPER + 10, side * (HALF_WIDTH - 0.2)),
			GLOW
		)
	end

	-- Poste del centro y la plataforma del lanzacohetes encima
	Builder.block(
		folder,
		"Pillar",
		Vector3.new(3, ROCKET_HEIGHT, 3),
		CFrame.new(0, ROCKET_HEIGHT / 2, 0),
		DARK
	)
	Builder.block(
		folder,
		"RocketDeck",
		Vector3.new(12, SLAB, 12),
		CFrame.new(0, ROCKET_HEIGHT - SLAB / 2, 0),
		DECK
	)

	-- Lámparas del techo
	for _, x in { -105, -35, 35, 105 } do
		for _, z in { -35, 35 } do
			local lamp = Builder.block(
				folder,
				"CeilingLight",
				Vector3.new(10, 0.4, 4),
				CFrame.new(x, HEIGHT - 0.2, z),
				GLOW
			)
			local light = Instance.new("PointLight")
			light.Color = GLOW.Color
			light.Range = 50
			light.Brightness = 1.2
			light.Parent = lamp
		end
	end

	Builder.pickupPad(
		map,
		"RocketLauncherPad",
		Vector3.new(0, ROCKET_HEIGHT + 0.2, 0),
		"Weapon",
		"RocketLauncher"
	)
	-- Una escalera en medio de cada lado, para volver a subir si te caes
	for _, side in { 1, -1 } do
		local ladder = Instance.new("TrussPart")
		ladder.Name = "Ladder"
		ladder.Anchored = true
		ladder.Size = Vector3.new(2, UPPER, 2)
		ladder.CFrame = CFrame.new(0, UPPER / 2, side * (SHELF_FROM - 1))
		ladder.Color = DARK.Color
		ladder.Material = Enum.Material.Metal
		ladder.Parent = folder
	end

	Builder.pickupPad(map, "FlamethrowerPad", Vector3.new(0, 0.2, 22), "Weapon", "Flamethrower")
end

-- Lo de cada equipo. Todo se escribe para el Rojo (+X); el Azul es igual, girado 180°.
-- Lo que va en los dos lados (Z positivo y negativo) se repite con side = 1 y side = -1.
local function buildHalf(map: Folder, team)
	local half = Builder.half(map, team)

	-- Mitad del puente que cruza todo el mapa, de la cubierta de esta base al centro
	half.add(
		"Bridge",
		Vector3.new(DECK_FROM, SLAB, 10),
		Vector3.new(DECK_FROM / 2, UPPER - SLAB / 2, 0),
		BEAM
	)
	half.add(
		"BridgeLight",
		Vector3.new(DECK_FROM - 4, 0.1, 0.5),
		Vector3.new(DECK_FROM / 2 + 2, UPPER + 0.05, 0),
		GLOW
	)
	for _, x in { 50, 80 } do
		half.add("Pillar", Vector3.new(3, UPPER - SLAB, 3), Vector3.new(x, (UPPER - SLAB) / 2, 0), PILLAR)
	end

	for _, side in { 1, -1 } do
		-- Plataforma alta pegada al muro del lado, del centro hasta la cubierta de la base,
		-- con columnas debajo
		local shelfDepth = HALF_WIDTH - SHELF_FROM
		half.add(
			"Shelf",
			Vector3.new(CORNER_FROM, SLAB, shelfDepth),
			Vector3.new(CORNER_FROM / 2, UPPER - SLAB / 2, side * (SHELF_FROM + shelfDepth / 2)),
			DECK
		)
		-- En la esquina de la base la plataforma se angosta, para dejar el hueco de la rampa
		local cornerLength = HALF_LENGTH - CORNER_FROM
		half.add(
			"Shelf",
			Vector3.new(cornerLength, SLAB, CORNER_STRIP),
			Vector3.new(
				CORNER_FROM + cornerLength / 2,
				UPPER - SLAB / 2,
				side * (SHELF_FROM + CORNER_STRIP / 2)
			),
			DECK
		)
		-- Rampa de la esquina: sube del piso (junto al spawn) a la plataforma del lado
		local laneZ = side * (SHELF_FROM + CORNER_STRIP + 6)
		half.slope(
			"Ramp",
			Vector3.new(CORNER_FROM + 32, 0, laneZ),
			Vector3.new(CORNER_FROM, UPPER, laneZ),
			12,
			DECK
		)
		half.spawn(Vector3.new(CORNER_FROM + 38, 0.5, laneZ))
		for _, x in { 20, 60, 90 } do
			half.add(
				"Pillar",
				Vector3.new(4, UPPER - SLAB, 4),
				Vector3.new(x, (UPPER - SLAB) / 2, side * (SHELF_FROM + 6)),
				PILLAR
			)
		end
		-- Pasarela de la repisa al puente
		half.add(
			"Walkway",
			Vector3.new(10, SLAB, SHELF_FROM - 5),
			Vector3.new(35, UPPER - SLAB / 2, side * (SHELF_FROM + 5) / 2),
			BEAM
		)
		-- Rampa angosta de la repisa a la plataforma del lanzacohetes
		half.slope(
			"RocketRamp",
			Vector3.new(10, UPPER, side * SHELF_FROM),
			Vector3.new(4, ROCKET_HEIGHT, side * 6),
			4,
			BEAM
		)
	end

	-- Cubierta de la base, encima del túnel. Llega hasta las plataformas de los lados
	local deckLength = HALF_LENGTH - DECK_FROM
	half.add(
		"BaseDeck",
		Vector3.new(deckLength, SLAB, SHELF_FROM * 2),
		Vector3.new(DECK_FROM + deckLength / 2, UPPER - SLAB / 2, 0),
		DECK
	)
	-- Bloque macizo detrás del túnel, que sostiene la cubierta
	local blockLength = HALF_LENGTH - TUNNEL_TO
	half.add(
		"BaseBlock",
		Vector3.new(blockLength, UPPER - SLAB, DECK_HALF * 2),
		Vector3.new(TUNNEL_TO + blockLength / 2, (UPPER - SLAB) / 2, 0),
		DARK
	)
	-- Muro del túnel que mira al centro, con dos ventanas (de y = 6 a y = 9)
	local wallX = (DECK_FROM + TUNNEL_FROM) / 2
	local wallThick = TUNNEL_FROM - DECK_FROM
	half.add("TunnelWall", Vector3.new(wallThick, 6, DECK_HALF * 2), Vector3.new(wallX, 3, 0), DARK)
	half.add(
		"TunnelWall",
		Vector3.new(wallThick, UPPER - SLAB - 9, DECK_HALF * 2),
		Vector3.new(wallX, (9 + UPPER - SLAB) / 2, 0),
		DARK
	)
	for _, z in { -25, 0, 25 } do
		half.add(
			"TunnelPost",
			Vector3.new(wallThick, 3, if z == 0 then 4 else 10),
			Vector3.new(wallX, 7.5, z),
			DARK
		)
	end
	-- Techo del túnel: la cubierta está muy arriba, así que el túnel tiene su propio techo
	-- más bajo (relleno macizo hasta la cubierta)
	local tunnelWidth = TUNNEL_TO - TUNNEL_FROM
	half.add(
		"TunnelRoof",
		Vector3.new(tunnelWidth, UPPER - SLAB - TUNNEL_CLEARANCE, DECK_HALF * 2),
		Vector3.new((TUNNEL_FROM + TUNNEL_TO) / 2, (TUNNEL_CLEARANCE + UPPER - SLAB) / 2, 0),
		DARK
	)
	half.add(
		"TunnelLight",
		Vector3.new(0.4, 0.4, DECK_HALF * 2 - 4),
		Vector3.new(TUNNEL_TO - 0.2, 9, 0),
		GLOW
	)

	-- Cobertura en la cubierta: un muro bajo al frente y la bandera al fondo
	half.add("Barrier", Vector3.new(2, 4, 16), Vector3.new(DECK_FROM + 8, UPPER + 2, 0), DARK)
	half.flagStand(Vector3.new(132, UPPER, 0))
	half.add(
		"TeamStripe",
		Vector3.new(0.4, 2, 40),
		Vector3.new(HALF_LENGTH - 0.2, UPPER + 10, 0),
		half.stripe
	)
	half.add("TeamStripe", Vector3.new(0.4, 1, 30), Vector3.new(TUNNEL_TO - 0.2, 4, 0), half.stripe)

	-- Puntos de aparición: dos en la cubierta (los otros dos están abajo, en las esquinas)
	half.spawn(Vector3.new(126, UPPER + 0.5, 18))
	half.spawn(Vector3.new(126, UPPER + 0.5, -18))

	-- Cajas en el piso de abajo
	for _, spot in
		{
			Vector3.new(30, 0, 12),
			Vector3.new(14, 0, -22),
			Vector3.new(58, 0, 24),
			Vector3.new(58, 0, -40),
			Vector3.new(88, 0, -16),
			Vector3.new(92, 0, 34),
		}
	do
		half.add("Crate", Vector3.new(5, 4, 5), spot + Vector3.new(0, 2, 0), CRATE, 15)
	end
	half.add("Crate", Vector3.new(4, 3, 4), Vector3.new(66, 1.5, -10), CRATE, -20)
	half.add("Crate", Vector3.new(4, 3, 4), Vector3.new(114, 1.5, 48), CRATE)
	half.add("Crate", Vector3.new(4, 3, 4), Vector3.new(76, 1.5, 12), CRATE, 30)

	-- Armas de este lado
	half.pickup("SniperPad", Vector3.new(134, UPPER + 0.2, -20), "Weapon", "Sniper")
	half.pickup("ShotgunPad", Vector3.new(114, 0.2, 0), "Weapon", "Shotgun")
	half.pickup("GrenadePad", Vector3.new(50, 0.2, 8), "Pickup", "Grenades")
	half.pickup("LaserRiflePad", Vector3.new(20, UPPER + 0.2, 60), "Weapon", "LaserRifle")
	half.pickup("IceGunPad", Vector3.new(28, 0.2, -10), "Weapon", "IceGun")
end

function CamaraFria.Build(map: Folder)
	buildShell(map)
	for _, team in Builder.TEAMS do
		buildHalf(map, team)
	end
end

return CamaraFria
