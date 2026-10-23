-- Mapa "Cámara Fría": inspirado en Chill Out de Halo CE, el que mandó edwing. Es un cuarto
-- rectangular cerrado (con techo) y de dos pisos. En Halo una base era distinta de la otra;
-- aquí las dos son iguales: cada base tiene su túnel con ventanas, como pidió edwing.
--
--   * Al centro, en alto (a 20 studs): dos repisas a los lados, unidas por pasarelas con el
--     puente que cruza todo el mapa. Encima, sobre un poste, la plataforma del lanzacohetes,
--     a la que se sube por rampas angostas desde las repisas.
--   * Cada base: una cubierta alta al fondo con la bandera. Debajo corre el túnel, con
--     ventanas que miran al centro. Se sube por dos rampas pegadas a los muros de los lados.
--   * Abajo: el piso con cajas para cubrirse.
--
-- Vista desde arriba (el Rojo está en +X, a la derecha; el Azul es igual, girado 180°):
--
--   +--------------------------------------------------------------+
--   |  rampa/     [repisa]   |   [repisa]     \rampa               |
--   |      [cubierta]  pasarela  |  pasarela    [cubierta]         |
--   |  túnel|=========== puente ==[o]== puente ===========|túnel   |
--   |      [cubierta]  pasarela  |  pasarela    [cubierta]         |
--   |  rampa\     [repisa]   |   [repisa]     /rampa               |
--   +--------------------------------------------------------------+
--                     [o] = plataforma del lanzacohetes
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

local HALF_LENGTH = 110 -- del centro a los muros de las bases, por dentro
local HALF_WIDTH = 70 -- del centro a los muros de los lados, por dentro
local WALL_THICK = 4
local HEIGHT = 56 -- del piso al techo
local UPPER = 20 -- altura del piso de arriba
local SLAB = 1 -- grosor de los pisos de arriba
local ROCKET_HEIGHT = 32 -- altura de la plataforma del lanzacohetes

-- Base de cada equipo (medidas en X, para el Rojo)
local TUNNEL_FROM = 76 -- el túnel va de x = 76 a x = 92, por debajo de la cubierta
local TUNNEL_TO = 92
local TUNNEL_CLEARANCE = 12 -- altura del túnel por dentro
local DECK_FROM = 74 -- la cubierta va de x = 74 hasta el muro
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
	for _, x in { -70, 0, 70 } do
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
	half.add("Pillar", Vector3.new(3, UPPER - SLAB, 3), Vector3.new(50, (UPPER - SLAB) / 2, 0), PILLAR)

	for _, side in { 1, -1 } do
		-- Repisa alta del centro (40 × 40) con su columna
		half.add("Shelf", Vector3.new(40, SLAB, 40), Vector3.new(20, UPPER - SLAB / 2, side * 50), DECK)
		half.add(
			"Pillar",
			Vector3.new(4, UPPER - SLAB, 4),
			Vector3.new(20, (UPPER - SLAB) / 2, side * 36),
			PILLAR
		)
		-- Pasarela de la repisa al puente
		half.add("Walkway", Vector3.new(10, SLAB, 25), Vector3.new(35, UPPER - SLAB / 2, side * 17.5), BEAM)
		-- Rampa del piso a la repisa, pegada al muro del lado
		half.slope("Ramp", Vector3.new(78, 0, side * 60), Vector3.new(40, UPPER, side * 60), 12, DECK)
		-- Rampa angosta de la repisa a la plataforma del lanzacohetes
		half.slope(
			"RocketRamp",
			Vector3.new(10, UPPER, side * 30),
			Vector3.new(4, ROCKET_HEIGHT, side * 6),
			4,
			BEAM
		)

		-- Rampa del piso a la cubierta de la base, pegada al muro del lado
		half.slope(
			"Ramp",
			Vector3.new(100, 0, side * 66),
			Vector3.new(100, UPPER, side * DECK_HALF),
			12,
			DECK
		)
	end

	-- Cubierta de la base, encima del túnel
	local deckLength = HALF_LENGTH - DECK_FROM
	half.add(
		"BaseDeck",
		Vector3.new(deckLength, SLAB, DECK_HALF * 2),
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
	half.flagStand(Vector3.new(102, UPPER, 0))
	half.add(
		"TeamStripe",
		Vector3.new(0.4, 2, 40),
		Vector3.new(HALF_LENGTH - 0.2, UPPER + 10, 0),
		half.stripe
	)
	half.add("TeamStripe", Vector3.new(0.4, 1, 30), Vector3.new(TUNNEL_TO - 0.2, 4, 0), half.stripe)

	-- Puntos de aparición: dos en la cubierta y dos en el túnel
	half.spawn(Vector3.new(96, UPPER + 0.5, 18))
	half.spawn(Vector3.new(96, UPPER + 0.5, -18))
	half.spawn(Vector3.new(84, 0.5, 22))
	half.spawn(Vector3.new(84, 0.5, -22))

	-- Cajas en el piso de abajo
	for _, spot in
		{ Vector3.new(30, 0, 12), Vector3.new(14, 0, -22), Vector3.new(58, 0, 24), Vector3.new(58, 0, -40) }
	do
		half.add("Crate", Vector3.new(5, 4, 5), spot + Vector3.new(0, 2, 0), CRATE, 15)
	end
	half.add("Crate", Vector3.new(4, 3, 4), Vector3.new(66, 1.5, -10), CRATE, -20)
	half.add("Crate", Vector3.new(4, 3, 4), Vector3.new(84, 1.5, 48), CRATE)

	-- Armas de este lado
	half.pickup("SniperPad", Vector3.new(104, UPPER + 0.2, -20), "Weapon", "Sniper")
	half.pickup("ShotgunPad", Vector3.new(84, 0.2, 0), "Weapon", "Shotgun")
	half.pickup("GrenadePad", Vector3.new(50, 0.2, 8), "Pickup", "Grenades")
	half.pickup("LaserRiflePad", Vector3.new(20, UPPER + 0.2, 56), "Weapon", "LaserRifle")
	half.pickup("IceGunPad", Vector3.new(28, 0.2, -10), "Weapon", "IceGun")
end

function CamaraFria.Build(map: Folder)
	buildShell(map)
	for _, team in Builder.TEAMS do
		buildHalf(map, team)
	end
end

return CamaraFria
