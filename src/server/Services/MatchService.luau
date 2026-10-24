-- Ciclo de partida: esperar jugadores, cuenta regresiva, jugar, mostrar ganador.
-- Modos: Team Slayer (puntos por bajas), Asesino en solitario (todos contra todos, gana el
-- primer jugador en llegar a las bajas), Captura la bandera (puntos por capturas), Rey de la
-- colina (puntos por segundo en la colina), Infección (zombis contra sobrevivientes) y Asalto
-- (puntos por bomba detonada).
-- Si no hay suficientes jugadores, la partida se rellena con bots (BotService, Config/Bots).
--
-- El estado de la partida se guarda en atributos de ReplicatedStorage para que la pantalla
-- de cada jugador lo lea (también quien entra a mitad de partida):
--   MatchPhase      "Waiting" | "Countdown" | "Playing" | "Ended"
--   MatchCountdown  segundos que faltan para empezar
--   MatchEndsAt     cuándo se acaba el tiempo (en el reloj de workspace:GetServerTimeNow())
--   MatchMode       el modo que se juega ("TeamSlayer", "FreeForAll", "CaptureTheFlag" o
--                   "KingOfTheHill")
--   MatchScoreToWin puntos para ganar (bajas, capturas o segundos en la colina)
-- El marcador de cada equipo es el atributo "Score" del Team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Maps = require(ReplicatedStorage.Shared.Config.Maps)
local Modes = require(ReplicatedStorage.Shared.Config.Modes)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local AssaultService = require(script.Parent.AssaultService)
local BotService = require(script.Parent.BotService)
local Combatants = require(script.Parent.Combatants)
local FlagService = require(script.Parent.FlagService)
local HealthService = require(script.Parent.HealthService)
local HillService = require(script.Parent.HillService)
local InfectionService = require(script.Parent.InfectionService)
local MatchSettings = require(script.Parent.MatchSettings)
local Rules = require(script.Parent.Rules)
local VehicleService = require(script.Parent.VehicleService)

local matchState = ReplicatedStorage.Remotes.MatchState :: RemoteEvent
local killFeed = ReplicatedStorage.Remotes.KillFeed :: RemoteEvent

local MatchService = {}

-- Se dispara al terminar cada partida con (reglas, ganador o nil); lo usa la tienda para
-- repartir créditos
local endedEvent = Instance.new("BindableEvent")
MatchService.Ended = endedEvent.Event

-- En solitario se reaparece en un punto al azar sin enemigos a menos de esta distancia
local SAFE_SPAWN_DISTANCE = 40

-- Bajas seguidas (muerte doble, triple...): cuentan si entre una y otra pasan menos de esto
local MULTIKILL_WINDOW = 4
local MULTIKILL_NAMES = { [2] = "¡Muerte doble!", [3] = "¡Muerte triple!", [4] = "¡Masacre!" }
local MULTIKILL_COLOR = Color3.fromRGB(255, 200, 60)
local streaks: { [Instance]: { count: number, last: number } } = {}

local scores: { [Team]: number } = {}
local running = false
local currentRules = Modes.TeamSlayer

local function broadcast(state: string, data: any?)
	matchState:FireAllClients(state, data)
end

local function setPhase(phase: string)
	ReplicatedStorage:SetAttribute("MatchPhase", phase)
end

-- Los contadores "Bajas" y "Muertes" que se ven en la lista de jugadores (los bots tienen
-- los suyos en su carnet, ver Combatants)
local function getStat(player: Instance, name: string): IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild(name) :: IntValue?
end

local function setScore(team: Team, score: number)
	scores[team] = score
	team:SetAttribute("Score", score)
end

local function resetScores()
	for _, team in Teams:GetTeams() do
		setScore(team, 0)
	end
	for _, player in Combatants.All() do
		for _, name in { "Bajas", "Muertes" } do
			local stat = getStat(player, name)
			if stat then
				stat.Value = 0
			end
		end
	end
end

-- Los puntos de aparición del mapa (de los dos equipos)
local function mapSpawns(): { SpawnLocation }
	local spawns = {}
	local map = workspace:FindFirstChild("Map")
	if map then
		for _, spawn in map:GetDescendants() do
			if spawn:IsA("SpawnLocation") and spawn.Enabled then
				table.insert(spawns, spawn)
			end
		end
	end
	return spawns
end

-- El equipo con menos jugadores (contando bots)
local function smallestTeam(): Team?
	local smallest, count = nil, math.huge
	for _, team in Teams:GetTeams() do
		local players = Combatants.CountInTeam(team)
		if players < count then
			smallest, count = team, players
		end
	end
	return smallest
end

-- Con equipos, cada jugador va a Rojo o Azul; en solitario nadie tiene equipo
local function assignTeam(player: Player, rules)
	if not rules.teams then
		player.Team = nil :: any -- sin equipo
		player.Neutral = true
	elseif MatchSettings.VsAI() then
		-- Contra la IA todos los jugadores van juntos; los bots, en el otro equipo
		player.Team = MatchSettings.HumanTeam() :: any
		player.Neutral = false
	elseif player.Neutral or not player.Team then
		player.Team = smallestTeam() :: any
		player.Neutral = false
	end
end

local function applyTeams(rules)
	-- Un punto de aparición "Neutral" sirve para cualquiera: en solitario se usan todos
	for _, spawn in mapSpawns() do
		spawn.Neutral = not rules.teams
	end
	for _, team in Teams:GetTeams() do
		team.AutoAssignable = rules.teams
	end
	for _, player in Players:GetPlayers() do
		assignTeam(player, rules)
	end
end

-- En solitario: un punto de aparición al azar, de los que no tienen enemigos cerca.
-- Si todos tienen a alguien cerca, el que esté más lejos de todos.
local function pickSoloSpawn(player: Player): SpawnLocation?
	local enemies = {}
	for _, other in Combatants.All() do -- jugadores y bots
		local character = Combatants.Character(other)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if other ~= player and character and humanoid and humanoid.Health > 0 then
			table.insert(enemies, character:GetPivot().Position)
		end
	end
	local safe = {}
	local farthest, farthestDistance = nil, -1
	for _, spawn in mapSpawns() do
		local nearest = math.huge
		for _, position in enemies do
			nearest = math.min(nearest, (position - spawn.Position).Magnitude)
		end
		if nearest >= SAFE_SPAWN_DISTANCE then
			table.insert(safe, spawn)
		end
		if nearest > farthestDistance then
			farthest, farthestDistance = spawn, nearest
		end
	end
	return if #safe > 0 then safe[math.random(#safe)] else farthest
end

local function teamColor(player: Instance?): Color3
	return Combatants.ColorOf(player)
end

-- victim y killer: un Player o el carnet de un bot
HealthService.Killed:Connect(function(victim: Instance, killer: Instance?, cause: string?, headshot: boolean)
	-- Registro de bajas: todos ven "quién eliminó a quién y con qué"
	killFeed:FireAllClients({
		killer = if killer and killer ~= victim then killer.Name else nil,
		killerColor = teamColor(killer),
		victim = victim.Name,
		victimColor = teamColor(victim),
		cause = cause,
		headshot = headshot,
		suicide = killer == victim,
	})

	if not running then
		return
	end
	local deaths = getStat(victim, "Muertes")
	if deaths then
		deaths.Value += 1
	end
	if not killer or killer == victim then
		return
	end
	local team = Combatants.TeamOf(killer)
	if currentRules.teams and team == Combatants.TeamOf(victim) then
		return
	end
	local kills = getStat(killer, "Bajas")
	if kills then
		kills.Value += 1
	end
	-- Muerte doble, triple o más: el sonido y el aviso solo le llegan a quien las hizo
	local now = os.clock()
	local streak = streaks[killer]
	if streak and now - streak.last <= MULTIKILL_WINDOW then
		streak.count += 1
		streak.last = now
	else
		streak = { count = 1, last = now }
		streaks[killer] = streak
	end
	if streak.count >= 2 and killer:IsA("Player") then
		local level = math.min(streak.count, 4)
		killFeed:FireClient(killer, {
			message = if streak.count > 4
				then `{MULTIKILL_NAMES[4]} ×{streak.count}`
				else MULTIKILL_NAMES[level],
			color = MULTIKILL_COLOR,
			sound = Sounds.multikill[level],
		})
	end
	if team and currentRules.teams and currentRules.scoreBy == "kills" then
		setScore(team, scores[team] + 1)
	end
end)

-- ¿Se puede jugar este modo ahora? Captura la bandera y Asalto necesitan bases de bandera en
-- el mapa, y si faltan jugadores (withBots) solo sirven los modos con bots
local function playable(name: string, withBots: boolean): boolean
	local mode = Modes[name]
	if not mode then
		return false
	end
	if
		(name == "CaptureTheFlag" and not FlagService.HasFlags())
		or (name == "Assault" and not AssaultService.HasBases())
	then
		return false
	end
	return not withBots or mode.bots == true
end

-- Los modos que faltan por jugar en esta vuelta. Con "Aleatorio" sale cada modo una vez, en
-- desorden, antes de repetir alguno (como barajar cartas); el mapa sí es al azar
local modeBag: { string } = {}
local lastMode: string? = nil

local function refillBag()
	modeBag = table.clone(Modes.randomPool)
	for i = #modeBag, 2, -1 do
		local j = math.random(i)
		modeBag[i], modeBag[j] = modeBag[j], modeBag[i]
	end
	-- Que la vuelta nueva no empiece con el modo que se acaba de jugar
	if #modeBag > 1 and modeBag[1] == lastMode then
		modeBag[1], modeBag[#modeBag] = modeBag[#modeBag], modeBag[1]
	end
end

-- Saca de la baraja el siguiente modo que se pueda jugar; los que no se pueden (por el mapa o
-- porque faltan jugadores) se quedan para después
local function drawMode(withBots: boolean): string?
	for _ = 1, 2 do
		for i, name in modeBag do
			if playable(name, withBots) then
				table.remove(modeBag, i)
				return name
			end
		end
		refillBag() -- ninguno de los que quedan sirve: vuelta nueva
	end
	return nil
end

-- El modo de esta partida: el elegido en Config/Modes o el siguiente de la baraja.
-- withBots: no hay jugadores suficientes, así que solo sirve un modo que los bots sepan jugar
local nextTestMode = 0 -- modo de prueba: cuál de randomPool sigue
local function chooseMode(withBots: boolean): string
	-- Partida privada o contra la IA: siempre el modo que se eligió
	local name = MatchSettings.mode or Modes.selected
	if name == "Aleatorio" then
		local testing = Modes.Testing
		if testing.enabled and testing.inOrder then
			-- En prueba van en orden, para que salgan todos sin depender de la suerte
			nextTestMode = nextTestMode % #Modes.randomPool + 1
			name = Modes.randomPool[nextTestMode]
		else
			name = drawMode(withBots) or "TeamSlayer"
		end
	end
	if not Modes[name] then
		warn("[Match] No existe el modo", name, "- juego TeamSlayer")
		name = "TeamSlayer"
	end
	if not playable(name, false) then
		warn("[Match] El mapa no tiene bases de bandera - juego TeamSlayer")
		name = "TeamSlayer"
	end
	if withBots and not Modes[name].bots and not MatchSettings.mode then
		name = drawMode(true) or "TeamSlayer"
	end
	lastMode = name
	return name
end

-- Quién ganó: un equipo, un jugador (en solitario) o un lado (en Infección)
type Winner = { name: string, color: Color3, title: string? }

local GOLD = Color3.fromRGB(255, 200, 60) -- color del ganador en solitario
local ZOMBIE_GREEN = Color3.fromRGB(120, 220, 90)
local SURVIVOR_BLUE = Color3.fromRGB(120, 180, 255)

-- Los nombres de quienes ganaron (para que cada pantalla sepa si oír victoria o derrota).
-- Se calcula antes de InfectionService.Stop, que borra quién era zombi
local function winnerNames(rules, winner: Winner?): { string }
	local names = {}
	if not winner then
		return names
	end
	for _, who in Combatants.All() do
		local won
		if rules.scoreBy == "infection" then
			local side = if winner.name == "Zombis" then "Zombie" else "Survivor"
			won = who:GetAttribute("Side") == side
		elseif rules.teams then
			local team = Combatants.TeamOf(who)
			won = team ~= nil and team.Name == winner.name
		else
			won = who.Name == winner.name
		end
		if won then
			table.insert(names, who.Name)
		end
	end
	return names
end

-- Tabla de resultados: jugadores ordenados por bajas (y con menos muertes en empate).
-- Los tres primeros salen en el podio de la pantalla de resultados
local function buildResults(rules, winner: Winner?, winners: { string })
	local players = {}
	for _, player in Combatants.All() do -- jugadores y bots
		local kills = getStat(player, "Bajas")
		local deaths = getStat(player, "Muertes")
		table.insert(players, {
			name = player.Name,
			color = teamColor(player),
			kills = kills and kills.Value or 0,
			deaths = deaths and deaths.Value or 0,
		})
	end
	table.sort(players, function(a, b)
		if a.kills ~= b.kills then
			return a.kills > b.kills
		end
		return a.deaths < b.deaths
	end)
	local teamScores = {}
	for _, team in if rules.teams then Teams:GetTeams() else {} do
		table.insert(
			teamScores,
			{ name = team.Name, color = team.TeamColor.Color, score = scores[team] or 0 }
		)
	end
	return {
		winner = if winner then winner.name else nil,
		winnerColor = if winner then winner.color else nil,
		title = if winner then winner.title else nil,
		teams = teamScores,
		players = players,
		winners = winners,
	}
end

-- Meta de la partida según cuántos jugadores hay (ver scaleScore en Config/Modes)
local function scoreGoal(rules, playerCount: number): number
	local low = rules.minScoreToWin
	if not low then
		return rules.scoreToWin
	end
	local scale = Modes.Common.scaleScore
	-- 0 con pocos jugadores, 1 con muchos, y en medio una fracción
	local t = math.clamp((playerCount - scale.lowPlayers) / (scale.highPlayers - scale.lowPlayers), 0, 1)
	local goal = low + (rules.scoreToWin - low) * t
	return math.floor(goal / 5 + 0.5) * 5
end

-- Modo de prueba (Modes.Testing): partidas cortas para probar todos los mapas y modos
local function applyTesting(rules)
	local testing = Modes.Testing
	if not testing.enabled then
		return
	end
	rules.timeLimit = testing.timeLimit
	if rules.scoreBy == "hill" then
		rules.scoreToWin = testing.hillSeconds
	elseif rules.scoreBy ~= "infection" then
		rules.scoreToWin = testing.scoreToWin
	end
	if rules.roundTime then
		rules.roundTime = math.min(rules.roundTime, testing.roundTime)
	end
end

-- timeUp: true cuando ya se acabó el tiempo
local function winner(rules, timeUp: boolean): Winner?
	if rules.scoreBy == "infection" then
		if InfectionService.Survivors() == 0 then
			return { name = "Zombis", color = ZOMBIE_GREEN, title = "¡Ganan los zombis!" }
		elseif timeUp then
			return { name = "Sobrevivientes", color = SURVIVOR_BLUE, title = "¡Ganan los sobrevivientes!" }
		end
		return nil
	end
	-- Al acabarse el tiempo gana quien vaya adelante (si hay empate, nadie)
	local goal = if timeUp then 1 else rules.scoreToWin
	if not rules.teams then
		local best, bestKills, tied = nil, -1, false
		for _, player in Combatants.All() do -- jugadores y bots
			local stat = getStat(player, "Bajas")
			local kills = if stat then stat.Value else 0
			if kills > bestKills then
				best, bestKills, tied = player, kills, false
			elseif kills == bestKills then
				tied = true
			end
		end
		if best and not tied and bestKills >= goal then
			return { name = best.Name, color = GOLD }
		end
		return nil
	end
	local best, bestScore, tied = nil, -1, false
	for team, score in scores do
		if score > bestScore then
			best, bestScore, tied = team, score, false
		elseif score == bestScore then
			tied = true
		end
	end
	if best and not tied and bestScore >= goal then
		return { name = best.Name, color = best.TeamColor.Color }
	end
	return nil
end

-- Lo llama init.server cada vez que aparece un personaje: en solitario lo lleva a un punto
-- de aparición al azar (no tiene base propia)
function MatchService.SetupCharacter(player: Player, character: Model)
	if currentRules.teams then
		return
	end
	local spawn = pickSoloSpawn(player)
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not spawn or not root then
		return
	end
	task.wait() -- deja que Roblox termine de colocarlo antes de moverlo
	character:PivotTo(spawn.CFrame * CFrame.new(0, 4, 0))
end

-- changeMap: cambia al siguiente mapa (lo prepara init.server); se llama antes de cada
-- partida menos la primera, que usa el mapa con el que arrancó el servidor
function MatchService.Run(changeMap: () -> ())
	local common = Modes.Common
	local firstMatch = true

	-- Quien entra a mitad de partida va a un equipo, o a ninguno en solitario, y un bot le
	-- deja su lugar. Si alguien se va, un bot lo reemplaza.
	Players.PlayerAdded:Connect(function(player)
		assignTeam(player, currentRules)
		BotService.Fill()
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(BotService.Fill) -- cuando ya se fue de la lista
	end)

	-- Cuántos jugadores hacen falta para empezar: con bots basta uno. En una partida privada de
	-- un modo sin bots (Captura la bandera...) hacen falta minPlayers
	local function playersNeeded(): number
		if MatchSettings.VsAI() then
			return 1
		end
		local fixed = MatchSettings.mode and Modes[MatchSettings.mode]
		if not BotService.Enabled() or (fixed and not fixed.bots) then
			return common.minPlayers
		end
		return 1
	end

	while true do
		setPhase("Waiting")
		broadcast("Waiting")
		ReplicatedStorage:SetAttribute("MatchPlayersNeeded", playersNeeded())
		while #Players:GetPlayers() < playersNeeded() do
			-- Lo que hace falta puede cambiar cuando llega el primero a una partida privada
			ReplicatedStorage:SetAttribute("MatchPlayersNeeded", playersNeeded())
			task.wait(1)
		end

		setPhase("Countdown")
		for i = common.countdown, 1, -1 do
			ReplicatedStorage:SetAttribute("MatchCountdown", i)
			broadcast("Countdown", i)
			task.wait(1)
		end

		-- La primera partida usa el mapa con el que arrancó el servidor, salvo en una partida
		-- privada con otro mapa elegido (MapService.Next no hace nada si ya es ese)
		if not firstMatch or MatchSettings.map then
			changeMap()
		end
		firstMatch = false

		local humans = #Players:GetPlayers()
		local modeName = chooseMode(BotService.Enabled() and humans < common.minPlayers)
		-- Copia de las reglas para poder ajustar la meta sin cambiar Config/Modes
		local rules = table.clone(Modes[modeName])
		rules.scoreToWin = scoreGoal(rules, humans + BotService.CountFor(rules))
		applyTesting(rules)
		currentRules = rules
		Rules.current = rules
		applyTeams(rules)
		-- Algunos mapas (La Barranca) tienen jeeps en cualquier modo: Config/Maps, alwaysVehicles
		local currentMap = workspace:FindFirstChild("Map")
		local mapKey = currentMap and currentMap:GetAttribute("MapKey")
		VehicleService.SetEnabled(
			rules.vehicles ~= false or (mapKey ~= nil and Maps.alwaysVehicles[mapKey] == true)
		)
		resetScores()
		table.clear(streaks)
		running = true
		ReplicatedStorage:SetAttribute("MatchMode", modeName)
		ReplicatedStorage:SetAttribute("MatchScoreToWin", rules.scoreToWin)
		ReplicatedStorage:SetAttribute("MatchEndsAt", workspace:GetServerTimeNow() + rules.timeLimit)
		setPhase("Playing")
		broadcast("Started", { mode = modeName, scoreToWin = rules.scoreToWin })
		-- Aviso en el registro: qué mapa y qué modo tocaron
		local map = workspace:FindFirstChild("Map")
		killFeed:FireAllClients({
			message = `{map and map:GetAttribute("MapName") or "Mapa"} · {rules.name}`,
			color = Color3.new(1, 1, 1),
		})
		if rules.scoreBy == "infection" then
			-- Los zombis se eligen antes de aparecer; contra la IA, los zombis son los bots
			InfectionService.Begin(rules, MatchSettings.VsAI())
		end
		-- Bots si faltan jugadores (y el modo los admite), o los rivales en una partida contra la IA
		BotService.Begin(rules)
		for _, player in Players:GetPlayers() do
			player:LoadCharacter()
		end
		if rules.scoreBy == "hill" then
			HillService.Begin(function(team, points)
				if running then
					setScore(team, scores[team] + points)
				end
			end)
		end
		if rules.scoreBy == "bombs" then
			AssaultService.Begin(rules, function(team)
				if running then
					setScore(team, scores[team] + 1)
				end
			end)
		end
		if rules.scoreBy == "captures" then
			FlagService.Begin(function(_player, team)
				if running then
					setScore(team, scores[team] + 1)
				end
			end)
		end

		local startTime = os.clock()
		local winningSide = nil
		while os.clock() - startTime < rules.timeLimit do
			winningSide = winner(rules, false)
			if winningSide then
				break
			end
			task.wait(0.5)
		end
		if not winningSide then
			winningSide = winner(rules, true)
		end
		running = false
		endedEvent:Fire(rules, winningSide) -- antes de Stop: Infección aún sabe quién es zombi
		local winners = winnerNames(rules, winningSide)
		FlagService.Stop()
		HillService.Stop()
		InfectionService.Stop()
		AssaultService.Stop()
		setPhase("Ended")
		broadcast("Ended", buildResults(rules, winningSide, winners))
		BotService.Stop() -- después de los resultados: ahí salen sus bajas
		task.wait(common.resultsTime)
	end
end

return MatchService
