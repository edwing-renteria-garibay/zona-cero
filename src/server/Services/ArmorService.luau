-- Armadura de la tienda: placas encima del avatar de cada jugador, por partes (casco, torso,
-- brazos y piernas). Es solo visual: las balas la atraviesan y pegan en el cuerpo.
--
-- Cada placa es un Part soldado a una parte del cuerpo. Las medidas son proporcionales a esa
-- parte (por ejemplo, el casco mide 1.15 veces la cabeza), así queda bien en avatares grandes
-- o chicos, R15 (el normal) o R6 (el clásico). Todas se llaman "Armor" para encontrarlas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = require(ReplicatedStorage.Shared.Config.Shop)

local ArmorService = {}

type Style = {
	primary: Color3,
	secondary: Color3,
	accent: Color3,
	material: Enum.Material,
}

local function findStyle(styleId: string?): Style?
	for _, style in Shop.armor do
		if style.id == styleId then
			return style
		end
	end
	return nil
end

-- Una placa pegada a bodyPart. offset se mide desde el centro de esa parte del cuerpo
-- (X derecha, Y arriba, Z negativo = al frente)
local function plate(
	bodyPart: BasePart,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material
)
	local part = Instance.new("Part")
	part.Name = "Armor"
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false -- las balas la atraviesan
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.CFrame = bodyPart.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = bodyPart
	weld.Part1 = part
	weld.Parent = part
	part.Parent = bodyPart
end

local function find(character: Model, ...: string): BasePart?
	for _, name in { ... } do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local C = CFrame.new
local V = Vector3.new

local function buildHelmet(character: Model, style: Style)
	local head = find(character, "Head")
	if not head then
		return
	end
	local s = head.Size
	plate(head, V(s.X * 1.15, s.Y * 0.45, s.Z * 1.15), C(0, s.Y * 0.32, 0.02), style.primary, style.material)
	plate(head, V(s.X * 1.18, s.Y * 0.1, s.Z * 1.18), C(0, s.Y * 0.1, 0), style.secondary, style.material)
	-- Visor levantado sobre la frente (no tapa la cara)
	plate(head, V(s.X * 0.8, s.Y * 0.12, 0.08), C(0, s.Y * 0.2, -s.Z * 0.6), style.accent, Enum.Material.Neon)
	-- Protectores de las orejas
	for _, side in { -1, 1 } do
		plate(
			head,
			V(0.12, s.Y * 0.38, s.Z * 0.45),
			C(side * s.X * 0.57, 0, 0),
			style.secondary,
			style.material
		)
	end
	-- El pelo y los sombreros del avatar se esconden para que no atraviesen el casco
	for _, accessory in character:GetChildren() do
		if accessory:IsA("Accessory") then
			local kind = accessory.AccessoryType
			local handle = accessory:FindFirstChild("Handle")
			if
				handle
				and handle:IsA("BasePart")
				and (kind == Enum.AccessoryType.Hat or kind == Enum.AccessoryType.Hair)
			then
				handle:SetAttribute("HiddenByHelmet", true)
				handle.Transparency = 1
			end
		end
	end
end

local function buildTorso(character: Model, style: Style)
	local torso = find(character, "UpperTorso", "Torso")
	if not torso then
		return
	end
	local s = torso.Size
	-- Placa de pecho y de espalda
	for _, side in { -1, 1 } do
		plate(
			torso,
			V(s.X * 0.9, s.Y * 0.7, 0.25),
			C(0, s.Y * 0.08, side * (s.Z / 2 + 0.1)),
			style.primary,
			style.material
		)
	end
	plate(torso, V(s.X * 1.04, s.Y * 0.12, s.Z * 1.15), C(0, -s.Y * 0.34, 0), style.secondary, style.material)
	plate(torso, V(s.X * 0.6, 0.16, s.Z * 1.08), C(0, s.Y * 0.45, 0), style.secondary, style.material)
	-- Una lucecita en el pecho
	plate(
		torso,
		V(0.22, 0.12, 0.06),
		C(s.X * 0.25, s.Y * 0.28, -s.Z / 2 - 0.25),
		style.accent,
		Enum.Material.Neon
	)
end

local function buildArms(character: Model, style: Style)
	for _, side in { "Left", "Right" } do
		local upper = find(character, side .. "UpperArm", side .. " Arm")
		if not upper then
			continue
		end
		local s = upper.Size
		local r6 = upper.Name == side .. " Arm"
		-- Hombrera arriba del brazo
		local padHeight = math.min(s.Y * 0.3, 0.6)
		local top = s.Y / 2 - padHeight / 2 + 0.08
		plate(upper, V(s.X * 1.35, padHeight, s.Z * 1.3), C(0, top, 0), style.primary, style.material)
		plate(
			upper,
			V(s.X * 1.38, 0.08, s.Z * 1.33),
			C(0, top - padHeight / 2, 0),
			style.secondary,
			style.material
		)
		-- Brazalete en el antebrazo
		local lower = if r6 then upper else find(character, side .. "LowerArm")
		if lower then
			local l = lower.Size
			local y = if r6 then -s.Y * 0.25 else 0
			plate(
				lower,
				V(l.X * 1.15, (if r6 then s.Y * 0.3 else l.Y * 0.6), l.Z * 1.15),
				C(0, y, 0),
				style.secondary,
				style.material
			)
		end
	end
end

local function buildLegs(character: Model, style: Style)
	for _, side in { "Left", "Right" } do
		local upper = find(character, side .. "UpperLeg", side .. " Leg")
		if not upper then
			continue
		end
		local s = upper.Size
		local r6 = upper.Name == side .. " Leg"
		-- Placa en el muslo
		local thighY = if r6 then s.Y * 0.2 else 0
		local thighHeight = if r6 then s.Y * 0.35 else s.Y * 0.6
		plate(
			upper,
			V(s.X * 0.9, thighHeight, 0.18),
			C(0, thighY, -s.Z / 2 - 0.06),
			style.primary,
			style.material
		)
		-- Rodillera
		local lower = if r6 then upper else find(character, side .. "LowerLeg")
		if lower then
			local l = lower.Size
			local y = if r6 then -s.Y * 0.1 else l.Y / 2 - 0.2
			plate(lower, V(l.X * 0.8, 0.35, 0.2), C(0, y, -l.Z / 2 - 0.08), style.secondary, style.material)
		end
	end
end

local BUILDERS = {
	Helmet = buildHelmet,
	Torso = buildTorso,
	Arms = buildArms,
	Legs = buildLegs,
}

-- Uniforme base (Shop.uniform): quita la ropa y los accesorios del avatar de Roblox y pinta
-- el cuerpo con los colores del uniforme
function ArmorService.ApplyUniform(character: Model)
	local uniform = Shop.uniform
	if not uniform.enabled then
		return
	end
	for _, item in character:GetChildren() do
		if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") or item:IsA("Accessory") then
			item:Destroy()
		end
	end
	local colors = character:FindFirstChildOfClass("BodyColors") or Instance.new("BodyColors")
	colors.HeadColor3 = uniform.skin
	colors.TorsoColor3 = uniform.shirt
	colors.LeftArmColor3 = uniform.shirt
	colors.RightArmColor3 = uniform.shirt
	colors.LeftLegColor3 = uniform.pants
	colors.RightLegColor3 = uniform.pants
	colors.Parent = character
end

-- Quita toda la armadura (y vuelve a mostrar el pelo y los sombreros)
function ArmorService.Remove(character: Model)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			if part.Name == "Armor" then
				part:Destroy()
			elseif part:GetAttribute("HiddenByHelmet") then
				part:SetAttribute("HiddenByHelmet", nil)
				part.Transparency = 0
			end
		end
	end
end

-- Pone la armadura que el jugador tiene equipada: equipped = { Helmet = "Elite", Torso = ... }
function ArmorService.Apply(character: Model, equipped: { [string]: string })
	ArmorService.Remove(character)
	for slot, build in BUILDERS do
		local style = findStyle(equipped[slot])
		if style then
			build(character, style)
		end
	end
end

return ArmorService
