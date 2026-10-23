-- Mapa "La Barranca": inspirado en Blood Gulch de Halo CE, el que mandó edwing. Es un cañón
-- largo y abierto, con pasto y montañas, hecho para pelear con jeeps. Es el primer mapa hecho
-- con Terrain (el terreno de Roblox: pasto, tierra y roca que se ven naturales) en lugar de
-- solo bloques.
--
--   * El cañón: 600 de largo (de base a base) por 260 de ancho, cerrado por paredes de roca
--     de 100 de alto, con peñascos para que no se vean rectas.
--   * 5 montañas de distinta altura: una en cada esquina y una en el centro. Los jeeps no
--     las pueden subir (hay que rodearlas), pero a pie sí. En la cima de la del centro están
--     el lanzacohetes y el cañón de iones.
--   * Un camino de tierra va de cada base a la montaña del centro y le da la vuelta.
--   * Cada base es un búnker de metal con puertas por los 4 lados y azotea, a la que se sube
--     por una rampa por detrás. Frente a cada base aparecen 2 jeeps.
--
-- Vista desde arriba (el Rojo está en +X, a la derecha; el Azul es igual, girado 180°):
--
--   +------------------------------------------------------------------+
--   | /\ montaña                                           montaña /\ |
--   |                           .-----.                              |
--   | [BASE]  jeeps  ~~camino~~ ( /\ ) ~~camino~~  jeeps [BASE]       |
--   |                           '-----'                              |
--   | /\ montaña           montaña del centro             montaña /\ |
--   +------------------------------------------------------------------+
--
-- Medidas desde el centro del mapa: X va de base a base, Z de lado a lado. El terreno
-- (Terrain) no está dentro de la carpeta del mapa: MapService lo borra al cambiar de mapa.

local Builder = require(script.Parent.Builder)

local Barranca = {}

local HALF_LENGTH = 300 -- del centro a las paredes del fondo
local HALF_WIDTH = 130 -- del centro a las paredes de los lados
local WALL_HEIGHT = 100 -- alto de las paredes de roca
local ROAD_WIDTH = 20
local CENTER_RADIUS = 45 -- la montaña del centro
local CENTER_HEIGHT = 40
local RING = 60 -- el camino rodea la montaña del centro a esta distancia

local GRASS = Enum.Material.Grass
local DIRT = Enum.Material.Ground
local ROCK = Enum.Material.Rock

-- Bloques de las bases: metal gris azulado, como los búnkeres de Halo
local METAL = { Color = Color3.fromRGB(112, 122, 134), Material = Enum.Material.DiamondPlate }
local WALL = { Color = Color3.fromRGB(96, 106, 118), Material = Enum.Material.Metal }
local STONE = { Color = Color3.fromRGB(110, 104, 96), Material = Enum.Material.Slate }

-- La base Roja está en x = BASE_X; el búnker mide BASE_SIZE por lado y BASE_HEIGHT de alto
local BASE_X = 250
local BASE_SIZE = 28
local BASE_HEIGHT = 10

local function terrain(): Terrain
	return workspace.Terrain
end

-- Una loma suave: el casquete de una esfera muy grande. radius = qué tan ancha es en el
-- piso; height = qué tan alta es en el centro
local function mound(x: number, z: number, radius: number, height: number, material: Enum.Material)
	local sphere = (radius * radius + height * height) / (2 * height)
	terrain():FillBall(Vector3.new(x, height - sphere, z), sphere, material)
end

-- Un tramo del camino de tierra, de a hasta b (en el piso), con una curva redonda en cada
-- punta para que los tramos se unan sin esquinas
local function road(a: Vector3, b: Vector3)
	local flatA = Vector3.new(a.X, -2, a.Z)
	local flatB = Vector3.new(b.X, -2, b.Z)
	terrain():FillBlock(
		CFrame.lookAt((flatA + flatB) / 2, flatB),
		Vector3.new(ROAD_WIDTH, 4, (flatB - flatA).Magnitude),
		DIRT
	)
	for _, point in { flatA, flatB } do
		terrain():FillCylinder(CFrame.new(point), 4, ROAD_WIDTH / 2, DIRT)
	end
end

-- Una montaña: una loma ancha de pasto con una punta de roca encima. Los jeeps no pueden
-- subirla (hay que rodearla), pero a pie sí. radius = qué tan ancha es en el piso
local function mountain(x: number, z: number, radius: number, height: number)
	mound(x, z, radius, height * 0.6, GRASS)
	local peak = radius * 0.45
	terrain():FillBall(Vector3.new(x, height - peak, z), peak, ROCK)
end

-- Una plataforma de piedra en la cima de una montaña, para poner un arma encima
local function summit(map: Folder, name: string, position: Vector3)
	Builder.block(map, name, Vector3.new(10, 2, 10), CFrame.new(position - Vector3.new(0, 1, 0)), STONE)
end

-- El cañón: piso de pasto, paredes de roca, peñascos y la montaña del centro
local function buildShell(map: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "Barranca"
	folder.Parent = map

	local outerX = HALF_LENGTH + 24
	local outerZ = HALF_WIDTH + 24
	-- Piso: pasto de 8 de grueso, con la superficie en y = 0
	terrain():FillBlock(CFrame.new(0, -4, 0), Vector3.new(outerX * 2, 8, outerZ * 2), GRASS)
	-- Paredes de roca alrededor
	local wallY = WALL_HEIGHT / 2 - 8
	for _, side in { 1, -1 } do
		terrain():FillBlock(
			CFrame.new(0, wallY, side * (HALF_WIDTH + 12)),
			Vector3.new(outerX * 2, WALL_HEIGHT, 24),
			ROCK
		)
		terrain():FillBlock(
			CFrame.new(side * (HALF_LENGTH + 12), wallY, 0),
			Vector3.new(24, WALL_HEIGHT, outerZ * 2),
			ROCK
		)
	end
	-- Peñascos pegados a las paredes de los lados, para que no se vean rectas. Los tamaños
	-- salen de una cuenta fija, así el mapa es siempre igual
	for i = 0, 11 do
		local x = -HALF_LENGTH + 25 + i * 50
		for _, side in { 1, -1 } do
			local radius = 14 + 6 * math.abs(math.sin(i * 1.7 + side))
			terrain():FillBall(Vector3.new(x, 6, side * (HALF_WIDTH + 4)), radius, ROCK)
		end
	end

	-- La montaña del centro, la más alta: el camino le da la vuelta (ver buildHalf). En la
	-- cima están el lanzacohetes y el cañón de iones: hay que subir a pie por ellos
	mountain(0, 0, CENTER_RADIUS, CENTER_HEIGHT)
	summit(folder, "Summit", Vector3.new(0, CENTER_HEIGHT, 0))
	Builder.pickupPad(
		map,
		"RocketLauncherPad",
		Vector3.new(-2.5, CENTER_HEIGHT + 0.2, 0),
		"Weapon",
		"RocketLauncher"
	)
	Builder.pickupPad(map, "IonCannonPad", Vector3.new(2.5, CENTER_HEIGHT + 0.2, 0), "Weapon", "IonCannon")

	-- Marcas invisibles en las esquinas: así el Rey de la colina sabe qué tan grande es el
	-- mapa (el terreno no cuenta, porque no está en la carpeta del mapa)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local marker = Builder.block(
				folder,
				"BoundsMarker",
				Vector3.new(1, 1, 1),
				CFrame.new(x * (HALF_LENGTH - 20), -20, z * (HALF_WIDTH - 20)),
				STONE
			)
			marker.Transparency = 1
			marker.CanCollide = false
			marker.CanQuery = false
			marker.CanTouch = false
		end
	end
end

-- El búnker de un equipo, con su azotea y la rampa de atrás
local function buildBase(half)
	local x0 = BASE_X - BASE_SIZE / 2 -- frente (mira al centro)
	local x1 = BASE_X + BASE_SIZE / 2 -- fondo
	local z1 = BASE_SIZE / 2
	local door = 8

	half.add("BaseFloor", Vector3.new(BASE_SIZE, 1, BASE_SIZE), Vector3.new(BASE_X, -0.4, 0), METAL)
	-- Muros con una puerta al centro de cada lado (el techo hace de dintel)
	local middleGap = { { BASE_SIZE / 2 - door / 2, BASE_SIZE / 2 + door / 2 } }
	half.wall(Vector3.new(x0 + 1, 0, -z1), Vector3.new(x0 + 1, 0, z1), BASE_HEIGHT, middleGap, WALL)
	half.wall(Vector3.new(x1 - 1, 0, -z1), Vector3.new(x1 - 1, 0, z1), BASE_HEIGHT, middleGap, WALL)
	local sideLength = BASE_SIZE - 4
	local sideGap = { { sideLength / 2 - door / 2, sideLength / 2 + door / 2 } }
	for _, side in { 1, -1 } do
		half.wall(
			Vector3.new(x0 + 2, 0, side * (z1 - 1)),
			Vector3.new(x1 - 2, 0, side * (z1 - 1)),
			BASE_HEIGHT,
			sideGap,
			WALL
		)
	end
	-- Azotea, con pretiles al frente para cubrirse (con un hueco al centro)
	half.add("Roof", Vector3.new(BASE_SIZE, 1, BASE_SIZE), Vector3.new(BASE_X, BASE_HEIGHT + 0.5, 0), METAL)
	local roofTop = BASE_HEIGHT + 1
	for _, side in { 1, -1 } do
		half.add("Barrier", Vector3.new(1.5, 3, 10), Vector3.new(x0 + 0.75, roofTop + 1.5, side * 9), WALL)
		half.add(
			"TeamStripe",
			Vector3.new(0.4, 0.8, 10),
			Vector3.new(x0 - 0.1, roofTop + 1.5, side * 9),
			half.stripe
		)
	end
	-- Rampa por detrás, del pasto a la azotea
	half.slope("Ramp", Vector3.new(x1 + 30, 0, 0), Vector3.new(x1, roofTop, 0), 10, METAL)

	-- Bandera en una esquina del fondo, adentro
	half.flagStand(Vector3.new(x1 - 6, 0.3, 8))
	-- Puntos de aparición: dos adentro y dos afuera, a los lados de la base
	half.spawn(Vector3.new(x0 + 6, 0.6, -8))
	half.spawn(Vector3.new(x0 + 6, 0.6, 8))
	half.spawn(Vector3.new(BASE_X + 20, 0.5, -45))
	half.spawn(Vector3.new(BASE_X + 20, 0.5, 45))
	-- Armas de la base: escopeta adentro, francotirador en la azotea
	half.pickup("ShotgunPad", Vector3.new(x1 - 6, 0.3, -8), "Weapon", "Shotgun")
	half.pickup("SniperPad", Vector3.new(x1 - 5, roofTop + 0.2, 0), "Weapon", "Sniper")
end

-- Lo de cada equipo. Todo se escribe para el Rojo (+X); el Azul es igual, girado 180°
local function buildHalf(map: Folder, team)
	local half = Builder.half(map, team)

	-- Camino de tierra: de la base a la montaña del centro, y luego media vuelta alrededor
	-- de ella. La otra mitad hace lo mismo (girada), así que las dos medias vueltas forman
	-- un anillo completo
	local diagonal = RING * math.cos(math.rad(45))
	local path = {
		Vector3.new(BASE_X - 15, 0, 0),
		Vector3.new(200, 0, -30),
		Vector3.new(150, 0, -45),
		Vector3.new(100, 0, -25),
		Vector3.new(RING, 0, 0),
		Vector3.new(diagonal, 0, -diagonal),
		Vector3.new(0, 0, -RING),
		Vector3.new(-diagonal, 0, -diagonal),
		Vector3.new(-RING, 0, 0),
	}
	for i = 1, #path - 1 do
		road(half.at(path[i]), half.at(path[i + 1]))
	end

	-- Las montañas de las dos esquinas de este lado, de distinta altura (después del
	-- camino: si se tocan, gana la montaña)
	local cornerX = HALF_LENGTH - 25
	local cornerZ = HALF_WIDTH - 25
	for _, corner in { { cornerZ, 30 }, { -cornerZ, 22 } } do
		local spot = half.at(Vector3.new(cornerX, 0, corner[1]))
		mountain(spot.X, spot.Z, 55, corner[2])
	end
	-- Una loma baja en el campo, para saltar con el jeep
	local bump = half.at(Vector3.new(150, 0, 40))
	mound(bump.X, bump.Z, 30, 5, GRASS)
	-- Rocas sueltas para cubrirse a pie
	for _, rock in
		{
			{ 165, -15, 4 },
			{ 95, 15, 5 },
			{ 215, 20, 3 },
			{ 135, -80, 5 },
			{ 70, 40, 4 },
		}
	do
		terrain():FillBall(half.at(Vector3.new(rock[1], 1, rock[2])), rock[3], ROCK)
	end

	-- Láser en la cima de la montaña más alta de las esquinas de este lado
	summit(map, "Summit", half.at(Vector3.new(cornerX, 30, cornerZ)))
	half.pickup("LaserRiflePad", Vector3.new(cornerX, 30.2, cornerZ), "Weapon", "LaserRifle")
	half.pickup("GrenadePad", Vector3.new(150, 0.2, -20), "Pickup", "Grenades")
	half.pickup("IceGunPad", Vector3.new(90, 0.2, 30), "Weapon", "IceGun")
	half.pickup("FlamethrowerPad", Vector3.new(200, 0.2, -60), "Weapon", "Flamethrower")

	buildBase(half)

	-- Dos jeeps frente a la base, mirando al centro
	half.jeep(Vector3.new(BASE_X - 30, 1, -28))
	half.jeep(Vector3.new(BASE_X - 30, 1, 28))
end

function Barranca.Build(map: Folder)
	buildShell(map)
	for _, team in Builder.TEAMS do
		buildHalf(map, team)
	end
end

return Barranca
