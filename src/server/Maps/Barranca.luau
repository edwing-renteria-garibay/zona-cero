-- Mapa "La Barranca": inspirado en Blood Gulch de Halo CE, el que mandó edwing. Es un cañón
-- largo y abierto, con pasto y montañas, hecho para pelear con jeeps. Es el primer mapa hecho
-- con Terrain (el terreno de Roblox: pasto, tierra y roca que se ven naturales) en lugar de
-- solo bloques.
--
--   * El cañón: 800 de largo (de base a base) por 480 de ancho, cerrado por paredes de roca
--     de 100 de alto, con peñascos para que no se vean rectas.
--   * 4 cerros iguales en cruz alrededor del centro, con forma de triángulo y la punta
--     hacia el centro (el dibujo de edwing): uno frente a cada base y uno a cada lado. Son
--     muy altos (80, casi como las paredes), de pasto con paredes de roca: entre ellos se
--     siente como cruzar un valle. A pie se escalan; el jeep no puede. Entre ellos quedan
--     pasos en diagonal y el centro abierto, así que los jeeps cruzan por en medio en
--     cualquier dirección, o los rodean por el camino de afuera. En el cruce del centro
--     están el lanzacohetes y el cañón de iones; el láser, entre cada base y su cerro.
--   * Caminos de tierra: un anillo alrededor de las 4 montañas, una X por los pasos del
--     centro y uno de cada base al anillo.
--   * Cada base es un búnker de metal con puertas por los 4 lados y azotea, a la que se sube
--     por una rampa por detrás. Frente a cada base aparecen 6 jeeps: 3 con ametralladora
--     y 3 con lanzacohetes.
--
-- Vista desde arriba (el Rojo está en +X, a la derecha; el Azul es igual, girado 180°):
--
--   +--------------------------------------------------------------+
--   |           .---------- anillo de tierra -----------.          |
--   |          /                    \/                   \         |
--   | [BASE] ---        |>        centro        <|       --- [BASE]|
--   |          \                    /\                   /         |
--   |           '---------------------------------------'          |
--   +--------------------------------------------------------------+
--   (las 4 montañas son triángulos con la punta hacia el centro; entre ellas, pasos en X)
--
-- Medidas desde el centro del mapa: X va de base a base, Z de lado a lado. El terreno
-- (Terrain) no está dentro de la carpeta del mapa: MapService lo borra al cambiar de mapa.

local Builder = require(script.Parent.Builder)

local Barranca = {}

local HALF_LENGTH = 400 -- del centro a las paredes del fondo
local HALF_WIDTH = 240 -- del centro a las paredes de los lados
local WALL_HEIGHT = 100 -- alto de las paredes de roca
local ROAD_WIDTH = 20
-- Las 4 montañas: el centro de cada triángulo está a MOUNTAIN_DISTANCE del centro del mapa;
-- TRIANGLE_SIDE es lo que mide cada lado del triángulo y MOUNTAIN_HEIGHT su altura
local MOUNTAIN_DISTANCE = 110
local TRIANGLE_SIDE = 120
local MOUNTAIN_HEIGHT = 80 -- casi tan altas como las paredes: cruzar se siente como un valle
local ROCK_RADIUS = 55 -- qué tan ancho es cada cerro en el piso (más ancho = pendiente más suave)
local RING = 195 -- el camino de afuera rodea las 4 montañas a esta distancia del centro

local GRASS = Enum.Material.Grass
local DIRT = Enum.Material.Ground
local ROCK = Enum.Material.Rock

-- Bloques de las bases: metal gris azulado, como los búnkeres de Halo
local METAL = { Color = Color3.fromRGB(112, 122, 134), Material = Enum.Material.DiamondPlate }
local WALL = { Color = Color3.fromRGB(96, 106, 118), Material = Enum.Material.Metal }
local STONE = { Color = Color3.fromRGB(110, 104, 96), Material = Enum.Material.Slate }

-- La base Roja está en x = BASE_X; el búnker mide BASE_SIZE por lado y BASE_HEIGHT de alto
local BASE_X = 330
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

-- Un cerro alto y empinado, como los de un valle: una torre que se va angostando hacia
-- arriba, hecha de discos (cilindros chatos, uno encima de otro) cada vez más chicos y un poco
-- chuecos, para que se vea natural. Abajo va cubierto de pasto con paredes de roca que
-- se asoman de lado; la punta es de roca. Se angosta parejo (como un cono), con discos
-- bajitos para que no queden escalones: a pie se escala, pero es muy empinado para el jeep
local function rockTower(x: number, z: number, radius: number, height: number)
	for y = 0, height, 3 do
		local t = y / height
		local r = math.max(radius * (1 - t), 3)
		-- El cerro se tuerce poquito y despacio al subir (cuenta fija: el mapa es siempre igual).
		-- Despacio, para que no queden salientes que no se puedan escalar
		local wobble = r * 0.12
		local cx = x + math.sin(y * 0.06 + x * 0.1) * wobble
		local cz = z + math.cos(y * 0.05 + z * 0.1) * wobble
		local disc = CFrame.new(cx, y + 2, cz)
		if t < 0.65 then
			terrain():FillCylinder(disc, 4, r, GRASS)
			-- Una pared de roca que se asoma por un lado, girando un poco en cada disco
			local angle = y * 0.04 + x * 0.05
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle)) * r * 0.45
			terrain():FillCylinder(disc + out, 4, r * 0.6, ROCK)
		else
			terrain():FillCylinder(disc, 4, r, ROCK)
		end
	end
end

-- Una montaña en forma de triángulo, con su centro en center y la punta hacia toward (el
-- centro del mapa). En medio, un cerro muy alto y ancho; en cada esquina del
-- triángulo, uno más bajo, así se ve triangular. Al pie, una falda de pasto
local function triangleMountain(center: Vector3, toward: Vector3)
	local forward = Vector3.new(toward.X - center.X, 0, toward.Z - center.Z).Unit
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local fromCenter = TRIANGLE_SIDE / math.sqrt(3) -- del centro del triángulo a cada esquina
	local corners = {
		center + forward * fromCenter, -- la punta, hacia el centro del mapa
		center - forward * fromCenter / 2 + right * TRIANGLE_SIDE / 2,
		center - forward * fromCenter / 2 - right * TRIANGLE_SIDE / 2,
	}
	for _, corner in corners do
		-- Un poco hacia adentro, para que las esquinas no se coman los pasos entre montañas
		local spot = center:Lerp(corner, 0.7)
		mound(spot.X, spot.Z, 30, 8, GRASS)
		rockTower(spot.X, spot.Z, 28, MOUNTAIN_HEIGHT * 0.55)
	end
	mound(center.X, center.Z, ROCK_RADIUS + 15, 10, GRASS)
	rockTower(center.X, center.Z, ROCK_RADIUS, MOUNTAIN_HEIGHT)
end

-- El cañón: piso de pasto, paredes de roca, peñascos y las montañas de los lados
local function buildShell(map: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "Barranca"
	folder.Parent = map

	local outerX = HALF_LENGTH + 24
	local outerZ = HALF_WIDTH + 24
	-- Piso: pasto de 8 de grueso, con la superficie en y = 0
	terrain():FillBlock(CFrame.new(0, -4, 0), Vector3.new(outerX * 2, 8, outerZ * 2), GRASS)
	-- Debajo del pasto, un piso invisible de bloques. Al crear el terreno, Roblox tarda un
	-- momento en hacerlo sólido, y los jeeps (que aparecen enseguida) lo atravesaban y caían
	-- al vacío. Este piso sí es sólido desde el principio. Su cara de arriba queda en y = 0,
	-- justo con el pasto, así que no se nota al caminar ni al manejar.
	local ground =
		Builder.block(folder, "Ground", Vector3.new(outerX * 2, 2, outerZ * 2), CFrame.new(0, -1, 0), STONE)
	ground.Transparency = 1
	ground.CastShadow = false
	ground.Material = Enum.Material.Grass -- pasos e impactos de bala suenan a pasto
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
	for i = 0, 15 do
		local x = -HALF_LENGTH + 25 + i * 50
		for _, side in { 1, -1 } do
			local radius = 14 + 6 * math.abs(math.sin(i * 1.7 + side))
			terrain():FillBall(Vector3.new(x, 6, side * (HALF_WIDTH + 4)), radius, ROCK)
		end
	end

	-- Las montañas de los dos lados (las de frente a cada base van en buildHalf)
	for _, side in { 1, -1 } do
		triangleMountain(Vector3.new(0, 0, side * MOUNTAIN_DISTANCE), Vector3.zero)
	end
	-- El lanzacohetes y el cañón de iones van en el cruce del centro, el lugar más peleado
	-- del mapa
	Builder.pickupPad(map, "RocketLauncherPad", Vector3.new(0, 0.2, 5), "Weapon", "RocketLauncher")
	Builder.pickupPad(map, "IonCannonPad", Vector3.new(0, 0.2, -5), "Weapon", "IonCannon")

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

	-- Caminos de tierra (antes que las montañas: si se tocan, gana la montaña):
	-- de la base al anillo de afuera
	road(half.at(Vector3.new(BASE_X - 15, 0, 0)), half.at(Vector3.new(RING, 0, 0)))
	-- media vuelta del anillo, de un lado al otro por este lado. La otra mitad hace lo mismo
	-- (girada), así que las dos medias vueltas forman el anillo completo
	local previous = nil
	for angle = -90, 90, 15 do
		local point = half.at(Vector3.new(math.cos(math.rad(angle)), 0, math.sin(math.rad(angle))) * RING)
		if previous then
			road(previous, point)
		end
		previous = point
	end
	-- y dos diagonales del anillo al centro, por los pasos entre montañas (con las de la otra
	-- mitad forman una X)
	local diagonal = RING * math.cos(math.rad(45))
	for _, side in { 1, -1 } do
		road(half.at(Vector3.new(diagonal, 0, side * diagonal)), half.at(Vector3.zero))
	end

	-- La montaña de frente a esta base, con la punta hacia el centro. El láser, en el camino
	-- entre la base y la montaña
	triangleMountain(half.at(Vector3.new(MOUNTAIN_DISTANCE, 0, 0)), Vector3.zero)
	half.pickup("LaserRiflePad", Vector3.new(205, 0.2, 0), "Weapon", "LaserRifle")

	-- Lomas bajas en el campo, para saltar con el jeep
	for _, z in { 120, -150 } do
		local bump = half.at(Vector3.new(270, 0, z))
		mound(bump.X, bump.Z, 30, 5, GRASS)
	end
	-- Rocas sueltas para cubrirse a pie
	for _, rock in
		{
			{ 240, -100, 5 },
			{ 225, 95, 4 },
			{ 150, -215, 5 },
			{ 140, 215, 4 },
			{ 300, 190, 5 },
		}
	do
		terrain():FillBall(half.at(Vector3.new(rock[1], 1, rock[2])), rock[3], ROCK)
	end

	half.pickup("GrenadePad", Vector3.new(240, 0.2, -45), "Pickup", "Grenades")
	half.pickup("IceGunPad", Vector3.new(240, 0.2, 45), "Weapon", "IceGun")
	half.pickup("FlamethrowerPad", Vector3.new(120, 0.2, -150), "Weapon", "Flamethrower")

	buildBase(half)

	-- Seis jeeps frente a la base, mirando al centro: adelante 3 con ametralladora y
	-- atrás 3 con lanzacohetes
	for _, z in { -36, 0, 36 } do
		half.jeep(Vector3.new(BASE_X - 52, 1, z), "TurretJeep")
		half.jeep(Vector3.new(BASE_X - 30, 1, z), "RocketJeep")
	end
end

function Barranca.Build(map: Folder)
	buildShell(map)
	for _, team in Builder.TEAMS do
		buildHalf(map, team)
	end
end

return Barranca
