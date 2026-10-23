-- Pinta un arma con una skin de la tienda (Config/Shop.weaponSkins). La usan el servidor (el arma
-- que todos ven en tu mano) y el cliente (el arma en primera persona, ver ViewModel).
--
-- Para no perder los detalles, no pinta todo del mismo color: cada pieza toma el tono de la
-- skin pero conserva qué tan clara u oscura era. Así el cargador sigue siendo más oscuro que
-- el cuerpo, aunque los dos sean dorados. Las piezas que brillan (Neon) no cambian.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = require(ReplicatedStorage.Shared.Config.Shop)

local WeaponSkins = {}

local function findSkin(skinId: string?)
	for _, skin in Shop.weaponSkins do
		if skin.id == skinId then
			return skin
		end
	end
	return nil
end

-- El color de una pieza con la skin: tono y saturación de la skin, brillo de la pieza
-- (subido un poco, porque casi todas las piezas de las armas son oscuras)
local function tint(original: Color3, skinColor: Color3): Color3
	local hue, saturation, value = skinColor:ToHSV()
	local _, _, pieceValue = original:ToHSV()
	return Color3.fromHSV(hue, saturation, math.clamp(value * (0.45 + pieceValue), 0, 1))
end

-- Pinta las piezas (parts) con la skin skinId, o les regresa su color original si es nil.
-- El color y material originales se guardan en atributos para poder cambiar de skin.
function WeaponSkins.Apply(parts: { BasePart }, skinId: string?)
	local skin = findSkin(skinId)
	for _, part in parts do
		if part:GetAttribute("BaseColor") == nil then
			if part.Material == Enum.Material.Neon then
				continue
			end
			part:SetAttribute("BaseColor", part.Color)
			part:SetAttribute("BaseMaterial", part.Material.Name)
		end
		local baseColor = part:GetAttribute("BaseColor") :: Color3
		local baseMaterial = (Enum.Material :: any)[part:GetAttribute("BaseMaterial")]
		if skin then
			part.Color = tint(baseColor, skin.color)
			part.Material = skin.material or baseMaterial
		else
			part.Color = baseColor
			part.Material = baseMaterial
		end
	end
end

-- Igual, pero para una herramienta completa (la Handle y las piezas soldadas a ella)
function WeaponSkins.ApplyToTool(tool: Tool, skinId: string?)
	local parts = {}
	for _, part in tool:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(parts, part)
		end
	end
	WeaponSkins.Apply(parts, skinId)
	tool:SetAttribute("Skin", skinId)
end

return WeaponSkins
