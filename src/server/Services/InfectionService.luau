-- Modo Infección. Al empezar se eligen en secreto de 1 a 3 zombis (nadie sabe antes quién
-- va a ser). Los zombis no tienen armas: golpean (F o clic) y un golpe mata; corren más y
-- ven a los sobrevivientes a través de las paredes. Un sobreviviente que muere se vuelve
-- zombi. Ganan los zombis si infectan a todos; ganan los sobrevivientes si queda al menos
-- uno cuando se acaba el tiempo.
--
-- Cada jugador tiene el atributo "Side": "Zombie" o "Survivor" (solo durante la partida).
-- Los del mismo lado no se pueden hacer daño (ver CombatService y ExplosionService).
-- En ReplicatedStorage, "Survivors" y "Zombies" dicen cuántos hay de cada lado.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HealthService = require(script.Parent.HealthService)

local killFeed = ReplicatedStorage.Remotes.KillFeed :: RemoteEvent

local ZOMBIE_SKIN = Color3.fromRGB(110, 150, 80)
local ZOMBIE_TEXT = Color3.fromRGB(120, 220, 90)

local InfectionService = {}

local active = false
local rules: any = nil

function InfectionService.IsZombie(player: Player): boolean
	return player:GetAttribute("Side") == "Zombie"
end

-- Cuenta a cada lado y lo publica para el marcador
local function updateCounts(): (number, number)
	local survivors, zombies = 0, 0
	for _, player in Players:GetPlayers() do
		if InfectionService.IsZombie(player) then
			zombies += 1
		elseif player:GetAttribute("Side") == "Survivor" then
			survivors += 1
		end
	end
	ReplicatedStorage:SetAttribute("Survivors", survivors)
	ReplicatedStorage:SetAttribute("Zombies", zombies)
	return survivors, zombies
end

-- Convierte un personaje en zombi: sin armas, granadas ni escudo, piel verde, más vida
-- y más rápido
local function applyZombie(character: Model)
	local player = Players:GetPlayerFromCharacter(character)
	local backpack = player and player:FindFirstChildOfClass("Backpack")
	for _, container in { character, backpack } do
		for _, item in (container :: Instance):GetChildren() do
			if item:IsA("Tool") then
				item:Destroy()
			end
		end
	end
	character:SetAttribute("Grenades", 0)
	character:SetAttribute("MaxShield", 0)
	character:SetAttribute("Shield", 0)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = rules.zombieSpeed
		humanoid.MaxHealth = rules.zombieHealth
		humanoid.Health = rules.zombieHealth
	end
	-- Sin ropa y con la piel verde, para que se reconozcan de lejos
	for _, item in character:GetChildren() do
		if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
			item:Destroy()
		end
	end
	local bodyColors = character:FindFirstChildOfClass("BodyColors") or Instance.new("BodyColors")
	bodyColors.HeadColor3 = ZOMBIE_SKIN
	bodyColors.TorsoColor3 = ZOMBIE_SKIN
	bodyColors.LeftArmColor3 = ZOMBIE_SKIN
	bodyColors.RightArmColor3 = ZOMBIE_SKIN
	bodyColors.LeftLegColor3 = ZOMBIE_SKIN
	bodyColors.RightLegColor3 = ZOMBIE_SKIN
	bodyColors.Parent = character
end

local function infect(player: Player, announce: boolean)
	player:SetAttribute("Side", "Zombie")
	if announce then
		killFeed:FireAllClients({
			message = string.format("%s fue infectado", player.Name),
			color = ZOMBIE_TEXT,
		})
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character and humanoid and humanoid.Health > 0 then
		applyZombie(character)
	end
	updateCounts()
end

-- Si ya no queda ningún zombi (se salieron del juego), se elige otro al azar
local function ensureZombie()
	local _, zombies = updateCounts()
	if zombies > 0 then
		return
	end
	local survivors = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Side") == "Survivor" then
			table.insert(survivors, player)
		end
	end
	if #survivors > 1 then
		infect(survivors[math.random(#survivors)], true)
	end
end

-- Elige a los primeros zombis. Se llama antes de que aparezcan los personajes.
function InfectionService.Begin(modeRules)
	rules = modeRules
	active = true
	local players = Players:GetPlayers()
	for _, player in players do
		player:SetAttribute("Side", "Survivor")
	end
	local count = math.clamp(#players // rules.playersPerZombie, 1, rules.maxZombies)
	-- Revolver la lista y tomar los primeros
	for i = #players, 2, -1 do
		local j = math.random(i)
		players[i], players[j] = players[j], players[i]
	end
	for i = 1, math.min(count, #players - 1) do
		players[i]:SetAttribute("Side", "Zombie")
	end
	local _, zombies = updateCounts()
	killFeed:FireAllClients({
		message = string.format(
			"¡Empieza la infección! %d %s",
			zombies,
			if zombies == 1 then "zombi" else "zombis"
		),
		color = ZOMBIE_TEXT,
	})
end

function InfectionService.Stop()
	active = false
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Side", nil)
	end
end

-- Cuántos sobrevivientes quedan (0 = ganaron los zombis)
function InfectionService.Survivors(): number
	return (updateCounts())
end

-- Lo llama init.server cada vez que aparece un personaje
function InfectionService.SetupCharacter(player: Player, character: Model)
	if active and InfectionService.IsZombie(player) then
		applyZombie(character)
	end
end

function InfectionService.Start()
	HealthService.Killed:Connect(function(victim: Player)
		if active and victim:GetAttribute("Side") == "Survivor" then
			infect(victim, true)
		end
	end)
	-- Quien entra a mitad de partida empieza como zombi
	Players.PlayerAdded:Connect(function(player)
		if active then
			player:SetAttribute("Side", "Zombie")
			updateCounts()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if active then
			task.defer(ensureZombie)
		end
	end)
end

return InfectionService
