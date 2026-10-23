-- Mapa "Fortines": dos fuertes amurallados, uno frente al otro, con una plaza en medio.
-- Diseño de edwing (SketchUp). Mide 200 × 200 studs. Mapa de infantería: aquí no hay jeeps.
--
-- Vista desde arriba del fuerte Rojo (+X). El Azul es el mismo, girado 180°.
-- "d" es la distancia desde la entrada del fuerte hacia el fondo:
--
--   d=80  ============================ muro del fondo ============================
--         [spawn]        [spawn]  rampa /plataforma\ rampa  [spawn]        [spawn]
--                                       (bandera, 8)
--   d=52  ==========brazo==   ====== muro bajo (10) ======   ==brazo==========
--   d=26      [  muro de en medio  ]                       [  muro de en medio  ]
--                                         [granadas]
--   d=0   |   [   muro de enfrente   ]                 [   muro de enfrente   ]   |
--         ^ acceso lateral                ^ acceso central                acceso lateral ^
--                              ------ plaza central (lanzacohetes) ------
--
-- Todo lo alto son muros macizos (no se puede subir a ellos). La plataforma del fondo
-- tiene un puente en medio; por debajo se pasa caminando. La base de la bandera está en
-- la esquina del fondo de cada fuerte.

local Builder = require(script.Parent.Builder)

local CONCRETE, DARK = Builder.CONCRETE, Builder.DARK_CONCRETE
local PLATE, SANDBAG, WOOD = Builder.PLATE, Builder.SANDBAG, Builder.WOOD
local STONE, PAVEMENT = Builder.STONE, Builder.PAVEMENT -- muros de afuera y piso

local Fortines = {}

-- Medidas principales, en studs. Todo el mapa mide (PLAZA + DEPTH + THICK) * 2 = 200
-- de largo y (INNER + THICK) * 2 = 200 de ancho.
local PLAZA = 16 -- del centro del mapa a la entrada de cada fuerte (eje X)
local DEPTH = 80 -- de la entrada al muro del fondo, por dentro
local INNER = 96 -- del centro a cada muro de los lados, por dentro (eje Z)
local THICK = 4 -- grosor de los muros de afuera
local OUTER_HEIGHT = 20 -- muros de afuera y brazos
local INNER_HEIGHT = 12 -- muros de dentro
local LOW_HEIGHT = 10 -- muro bajo frente a la plataforma: desde arriba se ve por encima
local PLATFORM_HEIGHT = 8

-- Una posición dentro del fuerte Rojo: d hacia el fondo, y hacia arriba, z hacia los lados
local function pos(d: number, y: number, z: number): Vector3
	return Vector3.new(PLAZA + d, y, z)
end

-- Un bloque apoyado en el suelo, dado por sus bordes: d0..d1 y z0..z1
local function wallBox(
	half: Builder.Half,
	name: string,
	d0: number,
	d1: number,
	z0: number,
	z1: number,
	height: number,
	style
)
	half.add(
		name,
		Vector3.new(d1 - d0, height, z1 - z0),
		pos((d0 + d1) / 2, height / 2, (z0 + z1) / 2),
		style
	)
end

-- Suelo y lo que no es de ningún equipo: la plaza central
local function buildPlaza(map: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "Plaza"
	folder.Parent = map
	local length = (PLAZA + DEPTH + THICK) * 2
	local width = (INNER + THICK) * 2
	Builder.block(folder, "Floor", Vector3.new(length, 2, width), CFrame.new(0, -1, 0), PAVEMENT)
	-- Muros de los lados de la plaza: cierran el hueco entre los dos fuertes
	for _, side in { 1, -1 } do
		Builder.block(
			folder,
			"PlazaWall",
			Vector3.new(PLAZA * 2, OUTER_HEIGHT, THICK),
			CFrame.new(0, OUTER_HEIGHT / 2, side * (INNER + THICK / 2)),
			STONE
		)
	end
	-- El lanzacohetes en el centro, sin nada que lo cubra
	Builder.pickupPad(map, "RocketLauncherPad", Vector3.new(0, 0.2, 0), "Weapon", "RocketLauncher")
end

local function buildFort(map: Folder, team)
	local half = Builder.half(map, team)

	-- Muros de afuera: el del fondo y los dos de los lados (abiertos hacia la plaza)
	wallBox(half, "BackWall", DEPTH, DEPTH + THICK, -INNER - THICK, INNER + THICK, OUTER_HEIGHT, STONE)
	for _, side in { 1, -1 } do
		local z0, z1 = INNER, INNER + THICK
		if side == -1 then
			z0, z1 = -z1, -z0
		end
		wallBox(half, "SideWall", 0, DEPTH, z0, z1, OUTER_HEIGHT, STONE)
	end
	-- Franja del color del equipo en el muro del fondo
	half.add("TeamStripe", Vector3.new(0.4, 2, INNER * 2), pos(DEPTH - 0.2, OUTER_HEIGHT - 4, 0), half.stripe)

	-- Lo de dentro es igual a los dos lados del pasillo central; side = 1 o -1 elige el lado
	for _, side in { 1, -1 } do
		local function box(
			name: string,
			d0: number,
			d1: number,
			za: number,
			zb: number,
			height: number,
			style
		)
			-- za y zb se dan del lado positivo; del otro lado se usan en negativo
			local z0, z1 = za * side, zb * side
			wallBox(half, name, d0, d1, math.min(z0, z1), math.max(z0, z1), height, style)
		end
		-- Brazos que salen de los muros de los lados (la "T" del dibujo)
		box("Arm", 42, 50, 50, INNER, OUTER_HEIGHT, STONE)
		half.add("TeamStripe", Vector3.new(8.4, 2, 0.4), pos(46, OUTER_HEIGHT - 4, 49.8 * side), half.stripe)
		-- Muro de enfrente: entre él y el de en medio pasa un pasillo de 10 studs.
		-- Acceso central de 20 studs (z de -10 a 10) y laterales de 18 (z de 78 a 96)
		box("FrontWall", 0, 16, 10, 78, INNER_HEIGHT, DARK)
		-- Muro de en medio
		box("MiddleWall", 26, 34, 10, 76, INNER_HEIGHT, DARK)

		-- Plataforma del fondo: rampa (de z=44 a z=18), bloque (de 18 a 5) y el puente en medio
		half.slope("PlatformRamp", pos(66, 0, 44 * side), pos(66, PLATFORM_HEIGHT, 18 * side), 8, PLATE)
		box("PlatformBlock", 62, 70, 5, 18, PLATFORM_HEIGHT, DARK)

		-- Puntos de aparición: detrás de la plataforma y en los rincones de los brazos
		half.spawn(pos(75, 0.5, 30 * side))
		half.spawn(pos(68, 0.5, 76 * side))
		-- Algo de cobertura en los rincones
		half.add("Sandbags", Vector3.new(2, 3, 10), pos(58, 1.5, 76 * side), SANDBAG)
		half.add("Crate", Vector3.new(4, 4, 4), pos(21, 2, 88 * side), WOOD, 20)
	end

	-- Muro bajo frente a la plataforma
	wallBox(half, "LowWall", 52, 56, -48, 48, LOW_HEIGHT, DARK)
	-- Puente de la plataforma: por abajo queda un paso de 10 studs de ancho y 7 de alto
	half.add("PlatformBridge", Vector3.new(8, 1, 10), pos(66, PLATFORM_HEIGHT - 0.5, 0), DARK)
	-- Base de la bandera, en la esquina del fondo, detrás del brazo
	half.flagStand(pos(75, 0, 90))

	-- Cobertura en la plaza, del lado de este fuerte
	half.add("Sandbags", Vector3.new(2, 3, 12), pos(-8, 1.5, 30), SANDBAG)
	half.add("Barrier", Vector3.new(2, 3.5, 8), pos(-11, 1.75, -55), CONCRETE, 20)

	-- Granadas en el cruce del pasillo central, entre los muros de enfrente y los de en medio
	half.pickup("GrenadePad", pos(21, 0.2, 0), "Pickup", "Grenades")
end

-- Construye todo el mapa dentro de la carpeta map
function Fortines.Build(map: Folder)
	buildPlaza(map)
	for _, team in Builder.TEAMS do
		buildFort(map, team)
	end
end

return Fortines
