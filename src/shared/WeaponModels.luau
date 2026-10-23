-- La forma de cada arma, hecha con piezas (Parts). La usan el servidor (el arma que todos ven en
-- la mano y en las plataformas) y el cliente (el arma en primera persona, ver ViewModel).
--
-- Cada pieza se mide desde el punto donde la mano derecha agarra el arma:
--   X = hacia la derecha · Y = hacia arriba · Z negativo = hacia el frente (hacia donde dispara)
-- La primera pieza de cada arma es el cuerpo: se vuelve la Handle de la herramienta.
-- muzzle: la boca del cañón (de ahí salen el fogonazo y la trazadora)
-- leftHand: dónde va la mano izquierda en primera persona
-- view: dónde queda el arma en primera persona, medido desde la cámara

local WeaponModels = {}

local rad = math.rad

-- Colores y materiales
local BLACK = { Color3.fromRGB(34, 34, 36), Enum.Material.Metal }
local STEEL = { Color3.fromRGB(78, 80, 84), Enum.Material.Metal }
local POLYMER = { Color3.fromRGB(44, 44, 42), Enum.Material.SmoothPlastic }
local OLIVE = { Color3.fromRGB(78, 82, 58), Enum.Material.SmoothPlastic }
local OLIVE_DARK = { Color3.fromRGB(56, 60, 42), Enum.Material.Metal }

-- Un cilindro de Roblox es largo en X; girado 90° queda a lo largo de Z (como un cañón)
local ALONG_Z = CFrame.Angles(0, rad(90), 0)

export type Piece = {
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	cylinder: boolean?,
}

export type Spec = {
	pieces: { Piece },
	muzzle: CFrame,
	leftHand: CFrame,
	view: CFrame,
	kick: number, -- cuánto se va hacia atrás al disparar (studs)
	kickAngle: number, -- cuánto sube al disparar (grados)
}

local function box(name: string, size: Vector3, cframe: CFrame, look): Piece
	return { name = name, size = size, cframe = cframe, color = look[1], material = look[2] }
end

-- Cilindro a lo largo de Z: size = (largo, grosor, grosor)
local function tube(name: string, length: number, thickness: number, position: Vector3, look): Piece
	return {
		name = name,
		size = Vector3.new(length, thickness, thickness),
		cframe = CFrame.new(position) * ALONG_Z,
		color = look[1],
		material = look[2],
		cylinder = true,
	}
end

local V = Vector3.new
local C = CFrame.new

WeaponModels.Specs = {
	-- Rifle de asalto, estilo militar con riel arriba
	AssaultRifle = {
		pieces = {
			box("Receiver", V(0.28, 0.38, 1.3), C(0, 0.32, -0.25), BLACK),
			box("Rail", V(0.2, 0.08, 1.9), C(0, 0.55, -0.6), STEEL),
			box("Handguard", V(0.32, 0.34, 1.0), C(0, 0.3, -1.4), OLIVE),
			tube("Barrel", 0.9, 0.12, V(0, 0.33, -2.3), BLACK),
			tube("FlashHider", 0.22, 0.17, V(0, 0.33, -2.85), STEEL),
			box("FrontSight", V(0.06, 0.24, 0.08), C(0, 0.62, -1.75), BLACK),
			box("RearSight", V(0.16, 0.14, 0.14), C(0, 0.65, 0.2), BLACK),
			box("Magazine", V(0.2, 0.62, 0.32), C(0, -0.1, -0.55) * CFrame.Angles(rad(14), 0, 0), POLYMER),
			box("Grip", V(0.2, 0.46, 0.24), C(0, -0.05, 0.05) * CFrame.Angles(rad(-18), 0, 0), POLYMER),
			box("Trigger", V(0.05, 0.14, 0.05), C(0, 0.06, -0.15), STEEL),
			box("Stock", V(0.24, 0.32, 0.9), C(0, 0.27, 0.85), OLIVE),
			box("ButtPad", V(0.26, 0.5, 0.12), C(0, 0.2, 1.32), POLYMER),
		},
		muzzle = C(0, 0.33, -3.0),
		leftHand = C(0, 0.15, -1.45),
		view = C(0.62, -0.78, -1.3) * CFrame.Angles(0, rad(5), 0),
		kick = 0.1,
		kickAngle = 1.2,
	},
	-- Pistola grande, estilo Desert Eagle
	Pistol = {
		pieces = {
			box("Slide", V(0.2, 0.26, 1.05), C(0, 0.32, -0.32), STEEL),
			box("Frame", V(0.18, 0.14, 0.9), C(0, 0.14, -0.27), BLACK),
			tube("Barrel", 0.1, 0.12, V(0, 0.33, -0.88), BLACK),
			box("FrontSight", V(0.04, 0.07, 0.05), C(0, 0.48, -0.8), BLACK),
			box("RearSight", V(0.16, 0.06, 0.06), C(0, 0.48, 0.15), BLACK),
			box("Grip", V(0.18, 0.5, 0.28), C(0, -0.12, 0.05) * CFrame.Angles(rad(-15), 0, 0), POLYMER),
			box("TriggerGuard", V(0.06, 0.05, 0.32), C(0, -0.02, -0.27), BLACK),
			box("Trigger", V(0.04, 0.12, 0.04), C(0, 0.04, -0.2), STEEL),
		},
		muzzle = C(0, 0.33, -0.95),
		leftHand = C(-0.12, -0.12, 0.02),
		view = C(0.45, -0.62, -1.6) * CFrame.Angles(0, rad(4), 0),
		kick = 0.25,
		kickAngle = 7,
	},
	-- Lanzacohetes de dos tubos, al hombro
	RocketLauncher = {
		pieces = {
			box("Body", V(0.95, 0.55, 1.5), C(0, 0.65, -0.1), OLIVE),
			tube("TubeLeft", 4.2, 0.6, V(-0.3, 0.78, -0.6), OLIVE),
			tube("TubeRight", 4.2, 0.6, V(0.3, 0.78, -0.6), OLIVE),
			tube("FrontLeft", 0.3, 0.68, V(-0.3, 0.78, -2.65), OLIVE_DARK),
			tube("FrontRight", 0.3, 0.68, V(0.3, 0.78, -2.65), OLIVE_DARK),
			tube("BackLeft", 0.3, 0.68, V(-0.3, 0.78, 1.45), OLIVE_DARK),
			tube("BackRight", 0.3, 0.68, V(0.3, 0.78, 1.45), OLIVE_DARK),
			box("Grip", V(0.2, 0.45, 0.25), C(0, 0.12, 0) * CFrame.Angles(rad(-10), 0, 0), POLYMER),
			box("ForeGrip", V(0.18, 0.42, 0.22), C(0, 0.18, -1.4), POLYMER),
			box("Sight", V(0.2, 0.26, 0.55), C(-0.62, 0.95, -0.4), BLACK),
			box(
				"Stripe",
				V(0.97, 0.12, 0.3),
				C(0, 0.9, -1.0),
				{ Color3.fromRGB(190, 160, 40), Enum.Material.SmoothPlastic }
			),
		},
		muzzle = C(0, 0.78, -2.85),
		leftHand = C(0, 0.1, -1.4),
		view = C(1.1, -1.15, -1.4) * CFrame.Angles(0, rad(3), 0),
		kick = 0.45,
		kickAngle = 9,
	},
} :: { [string]: Spec }

local function makePart(piece: Piece): Part
	local part = Instance.new("Part")
	part.Name = piece.name
	part.Size = piece.size
	part.Color = piece.color
	part.Material = piece.material
	if piece.cylinder then
		part.Shape = Enum.PartType.Cylinder
	end
	part.CanCollide = false
	part.CanQuery = false -- las balas y la mira lo atraviesan
	part.CanTouch = false
	part.Massless = true
	return part
end

-- Servidor: le da forma a una herramienta de ServerStorage.Weapons. El cuerpo se vuelve la
-- Handle y las demás piezas quedan dentro de ella, soldadas. Así, al clonar la herramienta
-- (o solo su Handle, como hacen las plataformas) se clona el arma completa.
function WeaponModels.Dress(tool: Tool)
	local spec = WeaponModels.Specs[tool.Name]
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not spec or not handle or handle:FindFirstChild("Muzzle") then
		return
	end
	local body = spec.pieces[1]
	handle.Size = body.size
	handle.Color = body.color
	handle.Material = body.material
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	-- Tool.Grip dice dónde queda la mano respecto a la Handle
	tool.Grip = body.cframe:Inverse()

	for i = 2, #spec.pieces do
		local part = makePart(spec.pieces[i])
		-- Una Weld guarda la posición de la pieza respecto a la Handle (C0)
		local weld = Instance.new("Weld")
		weld.Part0 = handle
		weld.Part1 = part
		weld.C0 = body.cframe:Inverse() * spec.pieces[i].cframe
		weld.Parent = part
		part.Parent = handle
	end

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.CFrame = body.cframe:Inverse() * spec.muzzle
	muzzle.Parent = handle
end

-- Cliente: las piezas sueltas (sin soldar) para moverlas cada fotograma en primera persona.
-- Devuelve las piezas y dónde va cada una, medido desde la mano.
function WeaponModels.BuildLoose(name: string): ({ BasePart }, { CFrame })
	local spec = WeaponModels.Specs[name]
	local parts, offsets = {}, {}
	if not spec then
		return parts, offsets
	end
	for _, piece in spec.pieces do
		local part = makePart(piece)
		part.Anchored = true
		part.CastShadow = false
		table.insert(parts, part)
		table.insert(offsets, piece.cframe)
	end
	return parts, offsets
end

return WeaponModels
