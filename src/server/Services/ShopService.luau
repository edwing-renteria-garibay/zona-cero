-- La tienda (Config/Shop): créditos, compras, lo que cada jugador tiene equipado y el guardado.
--
-- Cada jugador tiene un "perfil" que se guarda en un DataStore (el almacenamiento de Roblox
-- que no se borra al salir del juego):
--   credits  = créditos (¢)
--   owned    = lo que compró: { ["Helmet.Elite"] = true, ["Skin.Oro"] = true, ... }
--   equipped = lo que lleva puesto: { Helmet = "Elite", Torso = "Desierto", Skin = "Oro" }
--
-- El cliente nunca cambia el perfil directamente: pide "comprar" o "equipar" con el
-- RemoteFunction "Shop" y el servidor revisa que tenga créditos y que el objeto exista.
--
-- En Studio el DataStore solo funciona si el juego está publicado y activaste "Enable Studio
-- Access to API Services". Si no, la tienda funciona igual, pero no guarda nada.
-- Con Modes.Testing.enabled tampoco guarda, y todos empiezan con Shop.testingCredits.

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modes = require(ReplicatedStorage.Shared.Config.Modes)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local WeaponModels = require(ReplicatedStorage.Shared.WeaponModels)
local WeaponSkins = require(ReplicatedStorage.Shared.WeaponSkins)
local ArmorService = require(script.Parent.ArmorService)
local HealthService = require(script.Parent.HealthService)
local MatchService = require(script.Parent.MatchService)
local Rules = require(script.Parent.Rules)

local shopRemote = ReplicatedStorage.Remotes.Shop :: RemoteFunction

local MAX_RECEIPTS = 50 -- compras con Robux recordadas por jugador (para no darlas dos veces)

local ShopService = {}

type Profile = {
	credits: number,
	owned: { [string]: boolean },
	equipped: { [string]: string },
	receipts: { string },
}

local profiles: { [Player]: Profile } = {}
local dirty: { [Player]: boolean } = {} -- cambió algo desde la última vez que se guardó

local testing = Modes.Testing.enabled
local store: DataStore? = nil
if not testing then
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("ZonaCeroPerfiles")
	end)
	if ok then
		store = result
	else
		warn("[Tienda] No hay DataStore (¿juego sin publicar?). La tienda no guardará nada.")
	end
end

local function keyOf(player: Player): string
	return "jugador_" .. player.UserId
end

local function newProfile(): Profile
	return {
		credits = if testing then Shop.testingCredits else Shop.startingCredits,
		owned = {},
		equipped = {},
		receipts = {},
	}
end

local function save(player: Player): boolean
	local profile = profiles[player]
	if not store or not profile then
		return true -- sin DataStore no hay nada que guardar
	end
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync(keyOf(player), profile)
	end)
	if ok then
		dirty[player] = nil
	else
		warn("[Tienda] No se pudo guardar el perfil de", player.Name, err)
	end
	return ok
end

local function load(player: Player): Profile
	local profile = newProfile()
	if store then
		local ok, data = pcall(function()
			return (store :: DataStore):GetAsync(keyOf(player))
		end)
		if ok and type(data) == "table" then
			profile.credits = tonumber(data.credits) or profile.credits
			profile.owned = if type(data.owned) == "table" then data.owned else {}
			profile.equipped = if type(data.equipped) == "table" then data.equipped else {}
			profile.receipts = if type(data.receipts) == "table" then data.receipts else {}
		elseif not ok then
			warn("[Tienda] No se pudo cargar el perfil de", player.Name, data)
			if RunService:IsStudio() then
				-- En Studio casi siempre es porque falta publicar o activar el acceso a la API
				warn("[Tienda] En Studio: la tienda funciona, pero no guardará nada.")
				store = nil
			end
		end
	end
	return profile
end

-- Lo que el cliente necesita para dibujar la tienda
local function snapshot(profile: Profile)
	return { credits = profile.credits, owned = profile.owned, equipped = profile.equipped }
end

local function addCredits(player: Player, amount: number)
	local profile = profiles[player]
	if not profile or amount <= 0 then
		return
	end
	profile.credits += amount
	dirty[player] = true
	player:SetAttribute("Credits", profile.credits) -- el cliente lo muestra en la tienda
end

-- Le pone a un arma la skin que tenga equipada su dueño
local function skinTool(player: Player, tool: Instance)
	local profile = profiles[player]
	if not profile or not tool:IsA("Tool") or not WeaponModels.Specs[tool.Name] then
		return
	end
	local skin = profile.equipped.Skin
	if tool:GetAttribute("Skin") ~= skin then
		WeaponSkins.ApplyToTool(tool, skin)
	end
end

local function skinAllTools(player: Player)
	for _, container in { player.Character, player:FindFirstChildOfClass("Backpack") } do
		if container then
			for _, tool in container:GetChildren() do
				skinTool(player, tool)
			end
		end
	end
end

local function applyArmor(player: Player)
	local profile = profiles[player]
	local character = player.Character
	-- Los zombis de Infección van sin armadura
	if not profile or not character or player:GetAttribute("Side") == "Zombie" then
		return
	end
	ArmorService.Apply(character, profile.equipped)
end

-- Lo que el cliente puede pedir: "get", "buy" (comprar) o "equip" (equipar o quitar)
local function onShopRequest(player: Player, action: any, itemId: any)
	local profile = profiles[player]
	if not profile then
		return nil
	end
	if action == "get" then
		return snapshot(profile)
	end
	if type(itemId) ~= "string" then
		return snapshot(profile)
	end
	local kind, style = string.match(itemId, "^(%w+)%.(%w*)$")
	if not kind then
		return snapshot(profile)
	end

	if action == "buy" then
		local item, price = Shop.Find(itemId)
		if item and price and not profile.owned[itemId] and profile.credits >= price then
			profile.credits -= price
			profile.owned[itemId] = true
			profile.equipped[kind] = style -- lo recién comprado se pone de una vez
			dirty[player] = true
			save(player) -- una compra se guarda en seguida
		end
	elseif action == "equip" then
		if style == "" then
			profile.equipped[kind] = nil -- "Helmet." = quitarse el casco
			dirty[player] = true
		elseif profile.owned[itemId] then
			profile.equipped[kind] = style
			dirty[player] = true
		end
	end

	player:SetAttribute("Credits", profile.credits)
	player:SetAttribute("WeaponSkin", profile.equipped.Skin)
	if kind == "Skin" then
		skinAllTools(player)
	else
		applyArmor(player)
	end
	return snapshot(profile)
end

-- Compras con Robux (Developer Products de Shop.creditPacks). Roblox llama a esta función
-- y solo da por buena la compra si devolvemos PurchaseGranted. Si algo falla, devolvemos
-- NotProcessedYet y Roblox lo vuelve a intentar más tarde (el jugador no pierde sus Robux).
local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = player and profiles[player]
	if not player or not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if table.find(profile.receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- ya se había dado
	end
	local pack = nil
	for _, candidate in Shop.creditPacks do
		if candidate.productId ~= 0 and candidate.productId == receipt.ProductId then
			pack = candidate
		end
	end
	if not pack then
		warn("[Tienda] Producto desconocido", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	addCredits(player, pack.credits)
	table.insert(profile.receipts, purchaseId)
	if #profile.receipts > MAX_RECEIPTS then
		table.remove(profile.receipts, 1)
	end
	if not save(player) then
		-- No se guardó: se deshace y Roblox lo reintenta después
		profile.credits -= pack.credits
		table.remove(profile.receipts)
		player:SetAttribute("Credits", profile.credits)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Créditos por bajas
local function onKilled(victim: Player, killer: Player?, _cause: string?, headshot: boolean)
	if not killer or killer == victim or ReplicatedStorage:GetAttribute("MatchPhase") ~= "Playing" then
		return
	end
	if Rules.current.teams and killer.Team == victim.Team then
		return
	end
	addCredits(killer, Shop.rewards.kill + (if headshot then Shop.rewards.headshot else 0))
end

-- ¿Este jugador está en el lado que ganó?
local function isWinner(player: Player, rules, winner): boolean
	if rules.scoreBy == "infection" then
		local side = if winner.name == "Zombis" then "Zombie" else "Survivor"
		return player:GetAttribute("Side") == side
	elseif rules.teams then
		return player.Team ~= nil and player.Team.Name == winner.name
	end
	return player.Name == winner.name
end

-- Créditos al terminar una partida: a todos por jugar, y extra a los ganadores
local function onMatchEnded(rules, winner)
	for _, player in Players:GetPlayers() do
		local reward = Shop.rewards.match
		if winner and isWinner(player, rules, winner) then
			reward += Shop.rewards.win
		end
		addCredits(player, reward)
	end
end

local function onPlayerAdded(player: Player)
	local profile = load(player)
	if not player.Parent then
		return -- se fue mientras cargaba
	end
	profiles[player] = profile
	player:SetAttribute("Credits", profile.credits)
	player:SetAttribute("WeaponSkin", profile.equipped.Skin)

	local function onCharacter(character: Model)
		-- Espera a que el avatar termine de cargar (cambia las partes del cuerpo)
		if not player:HasAppearanceLoaded() then
			local loaded = false
			task.delay(5, function()
				loaded = true
			end)
			local connection = player.CharacterAppearanceLoaded:Connect(function()
				loaded = true
			end)
			while not loaded do
				task.wait(0.1)
			end
			connection:Disconnect()
		end
		if player.Character ~= character then
			return
		end
		applyArmor(player)
		-- Toda arma que llegue a la mochila o a la mano recibe la skin
		character.ChildAdded:Connect(function(child)
			skinTool(player, child)
		end)
		local backpack = player:WaitForChild("Backpack", 5)
		if backpack then
			backpack.ChildAdded:Connect(function(child)
				skinTool(player, child)
			end)
		end
		skinAllTools(player)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	if dirty[player] then
		save(player)
	end
	profiles[player] = nil
	dirty[player] = nil
end

function ShopService.Start()
	shopRemote.OnServerInvoke = onShopRequest
	MarketplaceService.ProcessReceipt = processReceipt
	HealthService.Killed:Connect(onKilled)
	MatchService.Ended:Connect(onMatchEnded)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	-- Al cerrar el servidor, se guarda a todos los que siguen dentro
	game:BindToClose(function()
		for player in profiles do
			if dirty[player] then
				save(player)
			end
		end
	end)
	-- Cada 2 minutos se guardan los créditos ganados jugando
	task.spawn(function()
		while true do
			task.wait(120)
			for player in profiles do
				if dirty[player] then
					task.spawn(save, player)
				end
			end
		end
	end)
end

return ShopService
