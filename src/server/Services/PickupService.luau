-- Objetos del mapa que se recogen al tocar su plataforma y reaparecen después de un tiempo.
-- Las plataformas están dentro de Map.WeaponPickups y dicen qué dan con un atributo:
--   Weapon = "RocketLauncher"  → da esa arma (se copia de ServerStorage.Weapons);
--                                si ya la tienes, te rellena la munición
--   Pickup = "Grenades"        → da granadas (Config/Grenades)
-- En los modos con pickups = false (SWAT) las plataformas se apagan.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Grenades = require(ReplicatedStorage.Shared.Config.Grenades)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Rules = require(script.Parent.Rules)

local DEFAULT_RESPAWN = 60 -- segundos, si el objeto no indica otro tiempo

local PickupService = {}

-- Lo que hace falta saber de cada tipo de objeto
type PickupKind = {
	label: string, -- texto que flota encima
	model: BasePart, -- lo que gira sobre la plataforma
	respawnTime: number,
	-- Intenta dárselo al jugador; devuelve false si no lo necesita (y no se gasta)
	give: (player: Player, character: Model) -> boolean,
}

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
		give = function(player, character)
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
			template:Clone().Parent = backpack
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
		give = function(_player, character)
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
	end)
	-- Al cambiar de mapa la plataforma se borra: deja de girar
	pad.Destroying:Connect(function()
		connection:Disconnect()
	end)

	pad.Touched:Connect(function(hit: BasePart)
		if not available or Rules.current.pickups == false then
			return
		end
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not player or not humanoid or humanoid.Health <= 0 then
			return
		end
		if kind.give(player, character :: Model) then
			available = false
			task.delay(kind.respawnTime, function()
				available = true
			end)
		end
	end)
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
