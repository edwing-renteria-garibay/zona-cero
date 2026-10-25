-- Modo Infección. Al empezar se eligen en secreto de 1 a 3 zombis (nadie sabe antes quién
-- va a ser). Los zombis no tienen armas, solo un machete: golpean (F o clic) y un golpe mata; corren más y
-- ven a los sobrevivientes a través de las paredes. Un sobreviviente que muere se vuelve
-- zombi. Ganan los zombis si infectan a todos; ganan los sobrevivientes si queda al menos
-- uno cuando se acaba el tiempo.
--
-- Contra la IA (MatchSettings) todos los jugadores empiezan como sobrevivientes y los zombis
-- son bots (BotService); un jugador que muere se vuelve zombi igual que siempre.
--
-- Ventaja al empezar: los zombis del principio se quedan quietos (y no pueden golpear)
-- rules.zombieHeadStart segundos, para que los sobrevivientes se alejen y se escondan. Además
-- aparecen en el punto más lejano de los sobrevivientes (MatchService y BotService).
--
-- Pócima de supervelocidad: un zombi (jugador con G o Círculo/B, o bot al perseguir) corre
-- rules.zombieBoost.multiplier veces más rápido por unos segundos y luego espera a que se
-- recargue. El personaje lleva "BoostReadyAt" (hora del servidor en que se puede volver a
-- tomar) y "Boosted" mientras dura, para el aviso y el brillo en el cliente.
--
-- Cada jugador (y cada bot) tiene el atributo "Side": "Zombie" o "Survivor" (solo durante la partida).
-- Los del mismo lado no se pueden hacer daño (ver CombatService y ExplosionService).
-- En ReplicatedStorage, "Survivors" y "Zombies" dicen cuántos hay de cada lado.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ArmorService = require(script.Parent.ArmorService)
local Combatants = require(script.Parent.Combatants)
local HealthService = require(script.Parent.HealthService)

local killFeed = ReplicatedStorage.Remotes.KillFeed :: RemoteEvent
local zombieBoost = ReplicatedStorage.Remotes.ZombieBoost :: RemoteEvent

local ZOMBIE_SKIN = Color3.fromRGB(110, 150, 80)
local ZOMBIE_TEXT = Color3.fromRGB(120, 220, 90)

local InfectionService = {}

-- El machete de los zombis es el mismo de Config/Melee (su forma está en Shared/WeaponModels).
-- Su golpe lo hace CombatService; a un zombi le sube el daño a rules.zombieMeleeDamage.
local function makeMachete(): Tool
	return ServerStorage.Weapons.Machete:Clone()
end

local active = false
local rules: any = nil
local releaseAt = 0 -- os.clock() en que los zombis del principio pueden moverse

function InfectionService.IsZombie(player: Player): boolean
	return player:GetAttribute("Side") == "Zombie"
end

-- Toma la pócima si se puede (es zombi, no está en su pausa, vivo y ya se recargó).
-- Devuelve si la tomó
function InfectionService.Boost(character: Model): boolean
	local boost = rules and rules.zombieBoost
	local who = Combatants.FromCharacter(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not active or not boost or not who or who:GetAttribute("Side") ~= "Zombie" then
		return false
	end
	if not humanoid or humanoid.Health <= 0 or character:GetAttribute("Held") then
		return false
	end
	local now = workspace:GetServerTimeNow()
	if now < (character:GetAttribute("BoostReadyAt") or 0) then
		return false
	end
	character:SetAttribute("BoostReadyAt", now + boost.duration + boost.cooldown)
	character:SetAttribute("Boosted", true)
	local normal = humanoid.WalkSpeed
	local fast = normal * boost.multiplier
	humanoid.WalkSpeed = fast
	task.delay(boost.duration, function()
		character:SetAttribute("Boosted", nil)
		-- Si algo más le cambió la velocidad mientras tanto (el hielo), no se toca
		if humanoid.Parent and humanoid.WalkSpeed == fast then
			humanoid.WalkSpeed = normal
		end
	end)
	return true
end

-- Cuenta a cada lado y lo publica para el marcador
local function updateCounts(): (number, number)
	local survivors, zombies = 0, 0
	for _, player in Combatants.All() do -- los bots zombis también cuentan
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

-- Convierte un personaje en zombi: sin armas (solo el machete), granadas ni escudo, piel
-- verde, más vida y más rápido. BotService también lo usa para los bots zombis.
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
	makeMachete().Parent = character -- un Tool dentro del personaje = en la mano
	ArmorService.Remove(character) -- sin armadura de la tienda
	character:SetAttribute("Grenades", 0)
	character:SetAttribute("MaxShield", 0)
	character:SetAttribute("Shield", 0)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = rules.zombieSpeed
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = rules.zombieJumpHeight or humanoid.JumpHeight
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

	-- Si todavía no se acaba la ventaja de los sobrevivientes, se queda quieto hasta entonces.
	-- Se ancla el cuerpo (no camina ni salta) y "Held" le impide golpear
	local holdFor = releaseAt - os.clock()
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if holdFor > 0 and root then
		character:SetAttribute("Held", true)
		character:SetAttribute("HeldUntil", workspace:GetServerTimeNow() + holdFor) -- para la cuenta del cliente
		root.Anchored = true
		task.delay(holdFor, function()
			if character.Parent then
				root.Anchored = false
				character:SetAttribute("Held", nil)
				character:SetAttribute("HeldUntil", nil)
			end
		end)
	end
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
-- botZombies: contra la IA; ningún jugador empieza como zombi (los zombis son bots)
function InfectionService.Begin(modeRules, botZombies: boolean?)
	rules = modeRules
	active = true
	local headStart = rules.zombieHeadStart or 0
	releaseAt = os.clock() + headStart
	local players = Players:GetPlayers()
	for _, player in players do
		player:SetAttribute("Side", "Survivor")
	end
	if botZombies then
		updateCounts()
		killFeed:FireAllClients({
			message = `¡Empieza la infección! Los zombis salen en {headStart} s: ¡corre!`,
			color = ZOMBIE_TEXT,
		})
		return
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
			"¡Empieza la infección! %d %s · salen en %d s: ¡corre!",
			zombies,
			if zombies == 1 then "zombi" else "zombis",
			headStart
		),
		color = ZOMBIE_TEXT,
	})
end

function InfectionService.Stop()
	active = false
	releaseAt = 0
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Side", nil)
	end
end

function InfectionService.ApplyZombie(character: Model)
	if rules then
		applyZombie(character)
		updateCounts()
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
	zombieBoost.OnServerEvent:Connect(function(player)
		if player.Character then
			InfectionService.Boost(player.Character)
		end
	end)
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
