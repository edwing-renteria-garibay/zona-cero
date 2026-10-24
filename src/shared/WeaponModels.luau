-- La forma de cada arma, hecha con piezas (Parts). La usan el servidor (el arma que todos ven en
-- la mano y en las plataformas) y el cliente (el arma en primera persona, ver ViewModel).
--
-- Cada pieza se mide desde el punto donde la mano derecha agarra el arma:
--   X = hacia la derecha · Y = hacia arriba · Z negativo = hacia el frente (hacia donde dispara)
-- La primera pieza de cada arma es el cuerpo: se vuelve la Handle de la herramienta.
-- muzzle: la boca del cañón (de ahí salen el fogonazo y la trazadora)
-- leftHand: dónde va la mano izquierda (en primera persona y, en las armas de dos manos,
--   también en el cuerpo que ven todos: ver TwoHands en el servidor)
-- oneHand: se agarra con una sola mano (pistola, arma de hielo y armas de golpe)
-- view: dónde queda el arma en primera persona, medido desde la cámara

local WeaponModels = {}

local rad = math.rad

-- Colores y materiales
local BLACK = { Color3.fromRGB(34, 34, 36), Enum.Material.Metal }
local STEEL = { Color3.fromRGB(78, 80, 84), Enum.Material.Metal }
local POLYMER = { Color3.fromRGB(44, 44, 42), Enum.Material.SmoothPlastic }
local OLIVE = { Color3.fromRGB(78, 82, 58), Enum.Material.SmoothPlastic }
local OLIVE_DARK = { Color3.fromRGB(56, 60, 42), Enum.Material.Metal }
local WOOD = { Color3.fromRGB(92, 60, 38), Enum.Material.Wood }
local GUNMETAL = { Color3.fromRGB(70, 74, 72), Enum.Material.Metal }
local WHITE = { Color3.fromRGB(215, 225, 232), Enum.Material.SmoothPlastic }
local TANK_RED = { Color3.fromRGB(150, 40, 30), Enum.Material.SmoothPlastic }
local ION_GREY = { Color3.fromRGB(84, 74, 72), Enum.Material.Metal }
-- Piezas que brillan (Neon)
local GLOW_GREEN = { Color3.fromRGB(80, 255, 90), Enum.Material.Neon }
local GLOW_ICE = { Color3.fromRGB(120, 210, 255), Enum.Material.Neon }
local GLOW_RED = { Color3.fromRGB(255, 50, 50), Enum.Material.Neon }
local GLOW_FIRE = { Color3.fromRGB(255, 140, 40), Enum.Material.Neon }
-- Armas de golpe
local BLADE = { Color3.fromRGB(165, 168, 172), Enum.Material.Metal }
local DARK_WOOD = { Color3.fromRGB(60, 38, 24), Enum.Material.Wood }
local RUBBER_YELLOW = { Color3.fromRGB(250, 210, 40), Enum.Material.SmoothPlastic }
local RUBBER_ORANGE = { Color3.fromRGB(240, 120, 30), Enum.Material.SmoothPlastic }
local RUBBER_RED = { Color3.fromRGB(215, 40, 35), Enum.Material.SmoothPlastic }

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
	oneHand: boolean?,
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
		oneHand = true,
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
	-- Escopeta de corredera, con madera
	Shotgun = {
		pieces = {
			box("Receiver", V(0.3, 0.4, 1.1), C(0, 0.3, -0.3), BLACK),
			tube("Barrel", 2.0, 0.16, V(0, 0.42, -1.85), BLACK),
			tube("Tube", 1.6, 0.16, V(0, 0.22, -1.7), STEEL),
			box("Pump", V(0.3, 0.26, 0.7), C(0, 0.22, -1.6), WOOD),
			box("Stock", V(0.24, 0.36, 1.1), C(0, 0.18, 0.75) * CFrame.Angles(rad(8), 0, 0), WOOD),
			box("Grip", V(0.2, 0.42, 0.24), C(0, -0.05, 0.08) * CFrame.Angles(rad(-20), 0, 0), BLACK),
			box("Bead", V(0.05, 0.06, 0.05), C(0, 0.53, -2.8), STEEL),
		},
		muzzle = C(0, 0.42, -2.9),
		leftHand = C(0, 0.1, -1.6),
		view = C(0.6, -0.8, -1.3) * CFrame.Angles(0, rad(5), 0),
		kick = 0.3,
		kickAngle = 8,
	},
	-- Lanzallamas con tanque rojo y piloto encendido
	Flamethrower = {
		pieces = {
			box("Body", V(0.36, 0.4, 1.4), C(0, 0.35, -0.4), OLIVE_DARK),
			tube("Nozzle", 1.2, 0.2, V(0, 0.4, -1.7), STEEL),
			tube("Tip", 0.2, 0.28, V(0, 0.4, -2.35), BLACK),
			tube("Tank", 0.8, 0.5, V(0, -0.02, -0.55), TANK_RED),
			box("Pilot", V(0.08, 0.08, 0.08), C(0, 0.25, -2.4), GLOW_FIRE),
			box("Grip", V(0.2, 0.45, 0.24), C(0, -0.05, 0.05) * CFrame.Angles(rad(-15), 0, 0), POLYMER),
			box("ForeGrip", V(0.18, 0.4, 0.2), C(0, 0.12, -1.35), POLYMER),
		},
		muzzle = C(0, 0.4, -2.5),
		leftHand = C(0, 0.05, -1.35),
		view = C(0.65, -0.85, -1.3) * CFrame.Angles(0, rad(5), 0),
		kick = 0.02,
		kickAngle = 0.3,
	},
	-- Rayo de energía: cuerpo gris con líneas verdes que brillan
	LaserRifle = {
		pieces = {
			box("Body", V(0.34, 0.5, 1.6), C(0, 0.35, -0.4), GUNMETAL),
			box("Shroud", V(0.3, 0.2, 1.4), C(0, 0.68, -0.7), BLACK),
			box("Barrel", V(0.22, 0.24, 1.3), C(0, 0.4, -1.8), GUNMETAL),
			tube("Emitter", 0.2, 0.3, V(0, 0.4, -2.5), BLACK),
			box("GlowTop", V(0.36, 0.06, 1.5), C(0, 0.47, -0.6), GLOW_GREEN),
			box("GlowBarrel", V(0.24, 0.05, 1.2), C(0, 0.27, -1.8), GLOW_GREEN),
			box("Cell", V(0.38, 0.18, 0.3), C(0, 0.3, 0.1), GLOW_GREEN),
			box("Stock", V(0.26, 0.4, 0.8), C(0, 0.25, 0.75), GUNMETAL),
			box("Grip", V(0.2, 0.45, 0.24), C(0, -0.05, 0.05) * CFrame.Angles(rad(-15), 0, 0), POLYMER),
		},
		muzzle = C(0, 0.4, -2.7),
		leftHand = C(0, 0.15, -1.6),
		view = C(0.62, -0.8, -1.35) * CFrame.Angles(0, rad(5), 0),
		kick = 0.2,
		kickAngle = 5,
	},
	-- Francotirador: cañón largo y mira telescópica
	Sniper = {
		pieces = {
			box("Receiver", V(0.26, 0.36, 1.2), C(0, 0.32, -0.2), BLACK),
			tube("Barrel", 2.8, 0.14, V(0, 0.36, -2.2), BLACK),
			tube("Brake", 0.3, 0.22, V(0, 0.36, -3.65), STEEL),
			tube("Scope", 1.3, 0.26, V(0, 0.78, -0.3), BLACK),
			tube("ScopeFront", 0.12, 0.34, V(0, 0.78, -1.0), BLACK),
			tube("ScopeBack", 0.12, 0.3, V(0, 0.78, 0.4), BLACK),
			box("MountFront", V(0.1, 0.18, 0.1), C(0, 0.58, -0.6), STEEL),
			box("MountBack", V(0.1, 0.18, 0.1), C(0, 0.58, 0.05), STEEL),
			box("Stock", V(0.24, 0.42, 1.2), C(0, 0.2, 0.95), OLIVE),
			box("Cheek", V(0.22, 0.12, 0.6), C(0, 0.46, 0.85), OLIVE),
			box("Magazine", V(0.2, 0.36, 0.3), C(0, 0.0, -0.45), POLYMER),
			box("Grip", V(0.2, 0.45, 0.24), C(0, -0.05, 0.08) * CFrame.Angles(rad(-18), 0, 0), POLYMER),
		},
		muzzle = C(0, 0.36, -3.85),
		leftHand = C(0, 0.15, -1.3),
		view = C(0.6, -0.8, -1.2) * CFrame.Angles(0, rad(5), 0),
		kick = 0.35,
		kickAngle = 9,
	},
	-- Arma de hielo: blanca, con una bobina azul que brilla
	IceGun = {
		pieces = {
			box("Body", V(0.32, 0.42, 1.2), C(0, 0.32, -0.3), WHITE),
			tube("Core", 1.1, 0.2, V(0, 0.36, -1.3), GLOW_ICE),
			tube("Ring1", 0.1, 0.42, V(0, 0.36, -0.95), WHITE),
			tube("Ring2", 0.1, 0.42, V(0, 0.36, -1.3), WHITE),
			tube("Ring3", 0.1, 0.42, V(0, 0.36, -1.65), WHITE),
			tube("Tip", 0.2, 0.26, V(0, 0.36, -1.95), STEEL),
			tube("Tank", 0.6, 0.3, V(0, 0.68, -0.2), GLOW_ICE),
			box("Grip", V(0.2, 0.45, 0.24), C(0, -0.05, 0.05) * CFrame.Angles(rad(-15), 0, 0), POLYMER),
		},
		muzzle = C(0, 0.36, -2.1),
		oneHand = true,
		leftHand = C(0, 0.05, -1.3),
		view = C(0.55, -0.75, -1.35) * CFrame.Angles(0, rad(5), 0),
		kick = 0.12,
		kickAngle = 3,
	},
	-- Cañón de iones: grande, con anillos rojos y un puntero láser abajo
	IonCannon = {
		pieces = {
			box("Body", V(0.5, 0.6, 1.8), C(0, 0.4, -0.5), ION_GREY),
			box("Barrel", V(0.44, 0.5, 1.0), C(0, 0.45, -1.8), ION_GREY),
			box("Ring1", V(0.5, 0.56, 0.1), C(0, 0.45, -1.45), GLOW_RED),
			box("Ring2", V(0.5, 0.56, 0.1), C(0, 0.45, -1.65), GLOW_RED),
			box("Ring3", V(0.5, 0.56, 0.1), C(0, 0.45, -1.85), GLOW_RED),
			tube("Emitter", 0.4, 0.36, V(0, 0.45, -2.5), GLOW_RED),
			box("Back", V(0.4, 0.5, 0.6), C(0, 0.35, 0.65), ION_GREY),
			box("Pointer", V(0.08, 0.08, 0.4), C(0, 0.12, -1.8), BLACK),
			box("PointerTip", V(0.06, 0.06, 0.04), C(0, 0.12, -2.02), GLOW_RED),
			box("Grip", V(0.22, 0.5, 0.28), C(0, -0.05, 0.05) * CFrame.Angles(rad(-12), 0, 0), POLYMER),
		},
		muzzle = C(0, 0.45, -2.75),
		leftHand = C(0, 0.12, -1.3),
		view = C(0.75, -0.95, -1.5) * CFrame.Angles(0, rad(4), 0),
		kick = 0.5,
		kickAngle = 10,
	},
	-- Machete (armas de golpe, ver Config/Melee): la hoja apunta al frente. Muzzle no se usa
	-- para disparar; marca la punta. La mano izquierda queda libre, en guardia.
	Machete = {
		pieces = {
			box("Grip", V(0.18, 0.26, 0.9), C(0, 0, 0.1), DARK_WOOD),
			box("Guard", V(0.24, 0.36, 0.08), C(0, 0.02, -0.38), BLACK),
			box("Blade", V(0.05, 0.42, 2.5), C(0, 0.06, -1.65), BLADE),
			box("Spine", V(0.07, 0.06, 2.5), C(0, 0.27, -1.65), STEEL),
			box("Tip", V(0.05, 0.3, 0.42), C(0, 0.02, -2.95) * CFrame.Angles(rad(-35), 0, 0), BLADE),
		},
		muzzle = C(0, 0.06, -3.1),
		oneHand = true,
		leftHand = C(-0.85, -0.45, -0.1),
		view = C(0.75, -0.95, -1.5) * CFrame.Angles(rad(25), rad(12), rad(-10)),
		kick = 0,
		kickAngle = 0,
	},
	-- Pollo de hule: se agarra de las patas y se usa como garrote
	RubberChicken = {
		pieces = {
			box("Legs", V(0.12, 0.12, 0.6), C(0, 0, 0), RUBBER_ORANGE),
			box("Feet", V(0.3, 0.06, 0.25), C(0, -0.02, 0.32), RUBBER_ORANGE),
			box("Body", V(0.5, 0.45, 1.2), C(0, 0.05, -0.9), RUBBER_YELLOW),
			box("LeftWing", V(0.08, 0.3, 0.7), C(-0.29, 0.06, -0.85), RUBBER_YELLOW),
			box("RightWing", V(0.08, 0.3, 0.7), C(0.29, 0.06, -0.85), RUBBER_YELLOW),
			box("Neck", V(0.24, 0.24, 0.6), C(0, 0.3, -1.6) * CFrame.Angles(rad(30), 0, 0), RUBBER_YELLOW),
			box("Head", V(0.3, 0.32, 0.36), C(0, 0.5, -1.95), RUBBER_YELLOW),
			box("Beak", V(0.1, 0.1, 0.3), C(0, 0.45, -2.25), RUBBER_ORANGE),
			box("Comb", V(0.06, 0.18, 0.3), C(0, 0.72, -1.95), RUBBER_RED),
		},
		muzzle = C(0, 0.45, -2.4),
		oneHand = true,
		leftHand = C(-0.85, -0.45, -0.1),
		view = C(0.75, -0.95, -1.5) * CFrame.Angles(rad(20), rad(12), rad(-10)),
		kick = 0,
		kickAngle = 0,
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

	-- Dónde agarra la mano izquierda en las armas de dos manos (la busca TwoHands)
	if not spec.oneHand then
		local leftGrip = Instance.new("Attachment")
		leftGrip.Name = "LeftHandGrip"
		leftGrip.Position = (body.cframe:Inverse() * spec.leftHand).Position
		leftGrip.Parent = handle
	end
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
