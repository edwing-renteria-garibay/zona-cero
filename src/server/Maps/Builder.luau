-- Herramientas para construir mapas con bloques (greybox). Cada mapa de esta carpeta las usa.
--
-- Los mapas son simétricos: se escribe la mitad del equipo Rojo (+X) y la mitad Azul (-X)
-- es la misma, girada 180° alrededor del centro del mapa. Builder.half() hace ese giro solo.

local Builder = {}

-- Colores y materiales: el material decide el sonido del impacto (concreto, metal o madera)
Builder.ROCK = { Color = Color3.fromRGB(150, 75, 50), Material = Enum.Material.Rock }
Builder.SAND = { Color = Color3.fromRGB(190, 130, 90), Material = Enum.Material.Sand }
Builder.CONCRETE = { Color = Color3.fromRGB(160, 155, 145), Material = Enum.Material.Concrete }
Builder.DARK_CONCRETE = { Color = Color3.fromRGB(115, 115, 110), Material = Enum.Material.Concrete }
Builder.ASPHALT = { Color = Color3.fromRGB(90, 90, 90), Material = Enum.Material.Asphalt }
Builder.SANDBAG = { Color = Color3.fromRGB(170, 150, 110), Material = Enum.Material.Fabric }
Builder.WOOD = { Color = Color3.fromRGB(140, 100, 60), Material = Enum.Material.WoodPlanks }
Builder.METAL = { Color = Color3.fromRGB(85, 92, 60), Material = Enum.Material.Metal }
Builder.PLATE = { Color = Color3.fromRGB(110, 110, 110), Material = Enum.Material.DiamondPlate }

Builder.TEAMS = {
	-- El equipo Rojo está en +X y el Azul en -X
	{ name = "Rojo", side = 1, color = BrickColor.new("Bright red") },
	{ name = "Azul", side = -1, color = BrickColor.new("Bright blue") },
}

local HALF_TURN = CFrame.Angles(0, math.pi, 0)

-- Crea un bloque anclado. style es uno de los estilos de arriba (color + material)
function Builder.block(parent: Instance, name: string, size: Vector3, cframe: CFrame, style): Part
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
function Builder.slope(
	parent: Instance,
	name: string,
	low: Vector3,
	high: Vector3,
	width: number,
	style
): Part
	local length = (high - low).Magnitude
	local middle = (low + high) / 2
	-- lookAt apunta el eje Z de la losa hacia high; luego la bajamos medio grosor
	local cframe = CFrame.lookAt(middle, high) * CFrame.new(0, -0.5, 0)
	return Builder.block(parent, name, Vector3.new(width, 1, length), cframe, style)
end

-- Un muro con huecos (puertas) a lo largo del eje X o Z.
-- from/to: los extremos del muro sobre el suelo; gaps: lista de {inicio, fin} medidos desde from
function Builder.wallWithGaps(
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
		Builder.block(
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

-- Una plataforma que da algo al tocarla (la lee PickupService).
-- attribute/value: "Weapon" = "RocketLauncher" o "Pickup" = "Grenades"
function Builder.pickupPad(
	map: Instance,
	name: string,
	position: Vector3,
	attribute: string,
	value: string
): Part
	local pad = Instance.new("Part")
	pad.Name = name
	pad.Anchored = true
	pad.Size = Vector3.new(4, 0.4, 4)
	pad.CFrame = CFrame.new(position)
	pad.Color = if attribute == "Weapon" then Color3.fromRGB(255, 170, 0) else Color3.fromRGB(80, 200, 120)
	pad.Material = Enum.Material.Neon
	pad:SetAttribute(attribute, value)
	pad.Parent = map:FindFirstChild("WeaponPickups")
	return pad
end

-- Un punto de aparición de un equipo, mirando hacia lookAt
function Builder.spawn(parent: Instance, team, position: Vector3, lookAt: Vector3): SpawnLocation
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn" .. team.name
	spawn.Size = Vector3.new(5, 1, 5)
	spawn.Anchored = true
	spawn.CFrame = CFrame.lookAt(position, Vector3.new(lookAt.X, position.Y, lookAt.Z))
	spawn.BrickColor = team.color
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TeamColor = team.color
	spawn.Neutral = false -- solo aparecen aquí los de este equipo
	spawn.AllowTeamChangeOnTouch = false
	spawn.Duration = 0 -- sin campo de fuerza: la protección la da el juego (SpawnProtected)
	spawn.Parent = parent
	return spawn
end

-- Lo que hace falta para construir la mitad de un equipo. Todas las posiciones se escriben
-- como si fuera la mitad Roja; para la Azul se giran 180° solas.
export type Half = {
	folder: Folder,
	team: any,
	stripe: any, -- estilo del color del equipo
	place: (cframe: CFrame) -> CFrame,
	at: (position: Vector3) -> Vector3,
	add: (name: string, size: Vector3, position: Vector3, style: any, yaw: number?) -> Part,
	spawn: (position: Vector3) -> SpawnLocation,
	wall: (from: Vector3, to: Vector3, height: number, gaps: { { number } }, style: any) -> (),
	slope: (name: string, low: Vector3, high: Vector3, width: number, style: any) -> Part,
	pickup: (name: string, position: Vector3, attribute: string, value: string) -> Part,
	jeep: (position: Vector3) -> (),
}

function Builder.half(map: Folder, team): Half
	local folder = Instance.new("Folder")
	folder.Name = "Half" .. team.name
	folder.Parent = map

	local half = {} :: Half
	half.folder = folder
	half.team = team
	half.stripe = { Color = team.color.Color, Material = Enum.Material.SmoothPlastic }

	function half.place(cframe: CFrame): CFrame
		return if team.side == 1 then cframe else HALF_TURN * cframe
	end
	function half.at(position: Vector3): Vector3
		return half.place(CFrame.new(position)).Position
	end
	function half.add(name: string, size: Vector3, position: Vector3, style, yaw: number?): Part
		return Builder.block(
			folder,
			name,
			size,
			half.place(CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0)),
			style
		)
	end
	function half.spawn(position: Vector3): SpawnLocation
		-- Mirando hacia el centro del mapa
		local world = half.at(position)
		return Builder.spawn(folder, team, world, Vector3.new(0, world.Y, world.Z))
	end
	function half.wall(from: Vector3, to: Vector3, height: number, gaps, style)
		Builder.wallWithGaps(folder, "Wall", half.at(from), half.at(to), height, gaps, style)
	end
	function half.slope(name: string, low: Vector3, high: Vector3, width: number, style): Part
		return Builder.slope(folder, name, half.at(low), half.at(high), width, style)
	end
	function half.pickup(name: string, position: Vector3, attribute: string, value: string): Part
		return Builder.pickupPad(map, name, half.at(position), attribute, value)
	end
	-- Un jeep que aparece aquí, mirando hacia el centro
	function half.jeep(position: Vector3)
		local marker = Instance.new("Part")
		marker.Name = "JeepSpawn" .. team.name
		marker.Anchored = true
		marker.Size = Vector3.new(8, 1, 12)
		local world = half.at(position)
		marker.CFrame = CFrame.lookAt(world, Vector3.new(0, world.Y, world.Z))
		marker.Parent = workspace:FindFirstChild("VehicleSpawns")
	end
	return half
end

return Builder
