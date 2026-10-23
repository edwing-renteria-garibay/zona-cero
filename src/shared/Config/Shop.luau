-- La tienda: armadura por partes y skins de armas. Todo es solo visual, nadie gana ventaja
-- por comprar. Se paga con créditos (¢), que se ganan jugando o se compran con Robux.
--
-- Cada estilo de armadura se vende por partes: casco, torso, brazos y piernas. Así un
-- jugador puede combinar, por ejemplo, casco Élite con torso Desierto.
-- primary: color principal · secondary: color de los detalles · accent: lo que brilla
-- (visor, luces) · material: el material de las placas

local Shop = {}

-- Créditos que se ganan jugando
Shop.rewards = {
	kill = 10, -- por cada baja
	headshot = 5, -- extra si la baja fue a la cabeza
	match = 25, -- por terminar una partida
	win = 75, -- extra si tu equipo (o tú, en solitario) gana
}

Shop.startingCredits = 200 -- con lo que empieza un jugador nuevo
Shop.testingCredits = 5000 -- con Modes.Testing.enabled, para probar la tienda sin jugar

-- Las cuatro partes de la armadura, en el orden en que salen en la tienda
Shop.slots = {
	{ id = "Helmet", name = "Casco" },
	{ id = "Torso", name = "Torso" },
	{ id = "Arms", name = "Brazos" },
	{ id = "Legs", name = "Piernas" },
}

-- Estilos de armadura. price es lo que cuesta cada parte
Shop.armor = {
	{
		id = "Militar",
		name = "Militar",
		price = 100,
		primary = Color3.fromRGB(86, 92, 62),
		secondary = Color3.fromRGB(56, 60, 42),
		accent = Color3.fromRGB(255, 170, 60),
		material = Enum.Material.SmoothPlastic,
	},
	{
		id = "Urbano",
		name = "Urbano",
		price = 150,
		primary = Color3.fromRGB(110, 114, 120),
		secondary = Color3.fromRGB(60, 62, 66),
		accent = Color3.fromRGB(120, 200, 255),
		material = Enum.Material.SmoothPlastic,
	},
	{
		id = "Desierto",
		name = "Desierto",
		price = 150,
		primary = Color3.fromRGB(196, 170, 120),
		secondary = Color3.fromRGB(140, 112, 76),
		accent = Color3.fromRGB(255, 120, 40),
		material = Enum.Material.SmoothPlastic,
	},
	{
		id = "Artico",
		name = "Ártico",
		price = 200,
		primary = Color3.fromRGB(228, 232, 236),
		secondary = Color3.fromRGB(150, 160, 170),
		accent = Color3.fromRGB(90, 200, 255),
		material = Enum.Material.SmoothPlastic,
	},
	{
		id = "Noche",
		name = "Noche",
		price = 300,
		primary = Color3.fromRGB(34, 36, 40),
		secondary = Color3.fromRGB(18, 18, 20),
		accent = Color3.fromRGB(60, 140, 255),
		material = Enum.Material.Metal,
	},
	{
		id = "Elite",
		name = "Élite",
		price = 500,
		primary = Color3.fromRGB(30, 30, 32),
		secondary = Color3.fromRGB(212, 168, 60),
		accent = Color3.fromRGB(255, 210, 80),
		material = Enum.Material.Metal,
	},
}

-- Skins de armas: pintan todas tus armas (las piezas que brillan no cambian).
-- color: el tono de la pintura; material: el acabado
Shop.weaponSkins = {
	{
		id = "Desierto",
		name = "Desierto",
		price = 150,
		color = Color3.fromRGB(196, 165, 110),
		material = nil,
	},
	{ id = "Bosque", name = "Bosque", price = 150, color = Color3.fromRGB(70, 110, 60), material = nil },
	{ id = "Artico", name = "Ártico", price = 200, color = Color3.fromRGB(225, 232, 240), material = nil },
	{ id = "Carmesi", name = "Carmesí", price = 300, color = Color3.fromRGB(170, 30, 40), material = nil },
	{
		id = "Cromo",
		name = "Cromo",
		price = 500,
		color = Color3.fromRGB(200, 205, 215),
		material = Enum.Material.Metal,
	},
	{
		id = "Oro",
		name = "Oro",
		price = 800,
		color = Color3.fromRGB(230, 180, 50),
		material = Enum.Material.Metal,
	},
}

-- Paquetes de créditos que se compran con Robux. Cada uno es un "Developer Product" que
-- se crea en el Creator Dashboard (ver docs/aprende/23-tienda.md). Pon aquí su ID; los que
-- tengan productId = 0 salen en la tienda como "Próximamente".
Shop.creditPacks = {
	{ credits = 500, robux = 49, productId = 0 },
	{ credits = 1200, robux = 99, productId = 0 },
	{ credits = 3000, robux = 199, productId = 0 },
}

-- Busca un objeto de la tienda por su id ("Helmet.Elite", "Skin.Oro"...).
-- Devuelve su información y su precio, o nil si no existe
function Shop.Find(itemId: string): (any, number?)
	local kind, style = string.match(itemId, "^(%w+)%.(%w+)$")
	if kind == "Skin" then
		for _, skin in Shop.weaponSkins do
			if skin.id == style then
				return skin, skin.price
			end
		end
		return nil, nil
	end
	for _, slot in Shop.slots do
		if slot.id == kind then
			for _, armor in Shop.armor do
				if armor.id == style then
					return armor, armor.price
				end
			end
		end
	end
	return nil, nil
end

return Shop
