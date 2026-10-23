-- Objetos del mapa que se recogen al tocar su plataforma y reaparecen después de un tiempo.
-- Las plataformas están dentro de Map.WeaponPickups y dicen qué dan con un atributo:
--   Weapon = "RocketLauncher"  → da esa arma (se copia de ServerStorage.Weapons);
--                                si ya la tienes, te rellena la munición. Solo se cargan
--                                Modes.Common.maxWeapons armas: con las manos llenas hay
--                                que pulsar E en la plataforma para cambiar la de la mano
--   Pickup = "Grenades"        → da granadas (Config/Grenades)
-- En los modos con pickups = false (SWAT) las plataformas se apagan.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Grenades = require(ReplicatedStorage.Shared.Config.Grenades)
local Modes = require(ReplicatedStorage.Shared.Config.Modes)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Rules = require(script.Parent.Rules)

local DEFAULT_RESPAWN = 60 -- segundos, si el objeto no indica otro tiempo

local PickupService = {}

-- Lo que hace falta saber de cada tipo de objeto
type PickupKind = {
	label: string, -- texto que flota encima
	model: BasePart, -- lo que gira sobre la plataforma
	respawnTime: number,
	-- Intenta dárselo al jugador; devuelve false si no lo necesita (y no se gasta).
	-- swap = true: si ya carga el máximo de armas, cambia la de la mano por esta
	give: (player: Player, character: Model, swap: boolean) -> boolean,
	isWeapon: boolean,
}

-- Las armas de fuego que lleva el jugador (en la mano y en la mochila). La primera es la
-- de la mano, si lleva una
local function carriedWeapons(character: Model, backpack: Backpack): { Tool }
	local tools = {}
	for _, container in { character, backpack } do
		for _, tool in container:GetChildren() do
			if tool:IsA("Tool") and Weapons[tool.Name] then
				table.insert(tools, tool)
			end
		end
	end
	return tools
end

-- Rellena el cargador y el repuesto de un arma que el jugador ya tiene.
-- Devuelve false si ya estaba llena (así la plataforma no se gasta).
local function refillAmmo(tool: Tool, stats): boolean
	if not stats then
		return false
	end
	local ammo = tool:GetAttribute("Ammo")
	local reserve = tool:GetAttribute("Reserve")
	local full = (ammo == nil or ammo >= stats.magazine)
		and (stats.reserve == nil or reserve == nil or reserve >= stats.reserve)
	if full then
		return false
	end
	if stats.reserve then
		tool:SetAttribute("Reserve", stats.reserve)
	end
	-- Durante una recarga solo se rellena el repuesto: la recarga ya va a sumar balas al cargador
	if not tool:GetAttribute("Reloading") then
		tool:SetAttribute("Ammo", stats.magazine)
	end
	return true
end

local function weaponKind(weaponName: string): PickupKind?
	local template = ServerStorage.Weapons:FindFirstChild(weaponName) :: Tool?
	if not template then
		return nil
	end
	local stats = Weapons[weaponName]
	return {
		label = template.ToolTip,
		model = (template:FindFirstChild("Handle") :: BasePart):Clone(),
		respawnTime = stats and stats.pickupRespawn or DEFAULT_RESPAWN,
		isWeapon = true,
		give = function(player, character, swap)
			local backpack = player:FindFirstChildOfClass("Backpack")
			if not backpack then
				return false
			end
			-- Si ya la tiene (en la mano o en la mochila), la plataforma le rellena la munición
			local owned = (
				character:FindFirstChild(weaponName) or backpack:FindFirstChild(weaponName)
			) :: Tool?
			if owned then
				return refillAmmo(owned, stats)
			end
			local carried = carriedWeapons(character, backpack)
			local limit = Rules.current.maxWeapons or Modes.Common.maxWeapons
			if Modes.Testing.enabled and Modes.Testing.loadout and not Rules.current.testingKeepsLoadout then
				limit = math.huge -- en el modo de prueba se cargan las 9
			end
			if #carried >= limit then
				if not swap then
					return false -- manos llenas: hay que pulsar E para cambiar
				end
				-- Suelta la de la mano (o, si no lleva ninguna en la mano, la primera que carga)
				carried[1]:Destroy()
			end
			local tool = template:Clone()
			tool.Parent = backpack
			if swap then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid:EquipTool(tool)
				end
			end
			return true
		end,
	}
end

local function grenadeKind(): PickupKind
	local model = Instance.new("Part")
	model.Shape = Enum.PartType.Ball
	model.Size = Vector3.one * 1.2
	model.Color = Color3.fromRGB(60, 70, 45)
	model.Material = Enum.Material.Metal
	return {
		label = "Granadas",
		model = model,
		respawnTime = Grenades.pickupRespawn,
		isWeapon = false,
		give = function(_player, character, _swap)
			local count = character:GetAttribute("Grenades") or 0
			if count >= Grenades.max then
				return false
			end
			character:SetAttribute("Grenades", math.min(count + Grenades.pickupAmount, Grenades.max))
			return true
		end,
	}
end

local function setupPad(pad: BasePart)
	local weaponName = pad:GetAttribute("Weapon") :: string?
	local kind = if weaponName
		then weaponKind(weaponName)
		elseif pad:GetAttribute("Pickup") == "Grenades" then grenadeKind()
		else nil
	if not kind then
		warn("[Pickup] No sé qué da la plataforma", pad:GetFullName())
		return
	end

	local display = kind.model
	display.Name = "Display"
	display.Anchored = true
	display.CanCollide = false
	display.CanTouch = false
	display.CanQuery = false
	display.Parent = pad

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 24)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.MaxDistance = 80
	billboard.Parent = display
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextSize = 16
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.4
	text.Text = kind.label
	text.Parent = billboard

	local available = true
	local prompt: ProximityPrompt? = nil -- botón de "Cambiar" (solo en armas)
	-- Las armas traen sus piezas dentro de la Handle: se muestran y esconden todas juntas
	local pieces = { display }
	for _, part in display:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(pieces, part)
		end
	end

	-- Girar y flotar un poco; desaparece mientras no está disponible
	local spin = 0
	local connection = RunService.Heartbeat:Connect(function(dt)
		spin += dt
		display.CFrame = pad.CFrame
			* CFrame.new(0, 2 + math.sin(spin * 2) * 0.3, 0)
			* CFrame.Angles(0, spin, 0)
		local shown = available and Rules.current.pickups ~= false
		for _, part in pieces do
			part.Transparency = if shown then 0 else 1
		end
		billboard.Enabled = shown
		if prompt then
			prompt.Enabled = shown
		end
	end)
	-- Al cambiar de mapa la plataforma se borra: deja de girar
	pad.Destroying:Connect(function()
		connection:Disconnect()
	end)

	local function tryGive(character: Instance?, swap: boolean)
		if not available or Rules.current.pickups == false then
			return
		end
		local player = character and Players:GetPlayerFromCharacter(character)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not player or not humanoid or humanoid.Health <= 0 then
			return
		end
		if kind.give(player, character :: Model, swap) then
			available = false
			task.delay(kind.respawnTime, function()
				available = true
			end)
		end
	end

	-- Al pisarla se recoge, si cabe
	pad.Touched:Connect(function(hit: BasePart)
		tryGive(hit.Parent, false)
	end)

	-- Con las manos llenas: E (o mantener el botón en móvil) cambia el arma de la mano por esta
	if kind.isWeapon then
		local newPrompt = Instance.new("ProximityPrompt")
		newPrompt.ActionText = "Cambiar"
		newPrompt.ObjectText = kind.label
		newPrompt.KeyboardKeyCode = Enum.KeyCode.E
		newPrompt.GamepadKeyCode = Enum.KeyCode.DPadUp -- X ya es recargar
		newPrompt.HoldDuration = 0.25
		newPrompt.MaxActivationDistance = 8
		newPrompt.RequiresLineOfSight = false
		newPrompt.Parent = pad
		newPrompt.Triggered:Connect(function(player)
			tryGive(player.Character, true)
		end)
		prompt = newPrompt
	end
end

function PickupService.Start(map: Instance)
	local pickups = map:FindFirstChild("WeaponPickups")
	if not pickups then
		return
	end
	for _, pad in pickups:GetChildren() do
		if pad:IsA("BasePart") then
			setupPad(pad)
		end
	end
end

return PickupService
