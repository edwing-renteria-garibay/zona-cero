-- Ciclo de partida: esperar jugadores, cuenta regresiva, jugar, mostrar ganador.
-- Modos: Team Slayer (puntos por bajas), Asesino en solitario (todos contra todos, gana el
-- primer jugador en llegar a las bajas), Captura la bandera (puntos por capturas), Rey de la
-- colina (puntos por segundo en la colina) e Infección (zombis contra sobrevivientes).
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

local Modes = require(ReplicatedStorage.Shared.Config.Modes)
local FlagService = require(script.Parent.FlagService)
local HealthService = require(script.Parent.HealthService)
local HillService = require(script.Parent.HillService)
local InfectionService = require(script.Parent.InfectionService)
local Rules = require(script.Parent.Rules)
local VehicleService = require(script.Parent.VehicleService)

local matchState = ReplicatedStorage.Remotes.MatchState :: RemoteEvent
local killFeed = ReplicatedStorage.Remotes.KillFeed :: RemoteEvent

local MatchService = {}

-- En solitario se reaparece en un punto al azar sin enemigos a menos de esta distancia
local SAFE_SPAWN_DISTANCE = 40

local scores: { [Team]: number } = {}
local running = false
local currentRules = Modes.TeamSlayer

local function broadcast(state: string, data: any?)
	matchState:FireAllClients(state, data)
end

local function setPhase(phase: string)
	ReplicatedStorage:SetAttribute("MatchPhase", phase)
end

-- Los contadores "Bajas" y "Muertes" que se ven en la lista de jugadores
local function getStat(player: Player, name: string): IntValue?
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
	for _, player in Players:GetPlayers() do
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

-- El equipo con menos jugadores
local function smallestTeam(): Team?
	local smallest, count = nil, math.huge
	for _, team in Teams:GetTeams() do
		local players = #team:GetPlayers()
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
	for _, other in Players:GetPlayers() do
		local character = other.Character
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

local function teamColor(player: Player?): Color3
	return if player and player.Team then player.TeamColor.Color else Color3.new(1, 1, 1)
end

HealthService.Killed:Connect(function(victim: Player, killer: Player?, cause: string?, headshot: boolean)
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
	if currentRules.teams and killer.Team == victim.Team then
		return
	end
	local kills = getStat(killer, "Bajas")
	if kills then
		kills.Value += 1
	end
	local team = killer.Team
	if team and currentRules.teams and currentRules.scoreBy == "kills" then
		setScore(team, scores[team] + 1)
	end
end)

-- El modo de esta partida: el elegido en Config/Modes o uno al azar
local function chooseMode(): string
	local name = Modes.selected
	if name == "Aleatorio" then
		name = Modes.randomPool[math.random(#Modes.randomPool)]
	end
	if not Modes[name] then
		warn("[Match] No existe el modo", name, "- juego TeamSlayer")
		name = "TeamSlayer"
	end
	if name == "CaptureTheFlag" and not FlagService.HasFlags() then
		warn("[Match] El mapa no tiene bases de bandera - juego TeamSlayer")
		name = "TeamSlayer"
	end
	return name
end

-- Quién ganó: un equipo, un jugador (en solitario) o un lado (en Infección)
type Winner = { name: string, color: Color3, title: string? }

local GOLD = Color3.fromRGB(255, 200, 60) -- color del ganador en solitario
local ZOMBIE_GREEN = Color3.fromRGB(120, 220, 90)
local SURVIVOR_BLUE = Color3.fromRGB(120, 180, 255)

-- Tabla de resultados: jugadores ordenados por bajas (y con menos muertes en empate)
local function buildResults(rules, winner: Winner?)
	local players = {}
	for _, player in Players:GetPlayers() do
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
	}
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
	if not rules.teams then
		for _, player in Players:GetPlayers() do
			local kills = getStat(player, "Bajas")
			if kills and kills.Value >= rules.scoreToWin then
				return { name = player.Name, color = GOLD }
			end
		end
		return nil
	end
	for team, score in scores do
		if score >= rules.scoreToWin then
			return { name = team.Name, color = team.TeamColor.Color }
		end
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

function MatchService.Run()
	local common = Modes.Common

	-- Quien entra a mitad de partida va a un equipo, o a ninguno en solitario
	Players.PlayerAdded:Connect(function(player)
		assignTeam(player, currentRules)
	end)

	ReplicatedStorage:SetAttribute("MatchPlayersNeeded", common.minPlayers)
	while true do
		setPhase("Waiting")
		broadcast("Waiting")
		while #Players:GetPlayers() < common.minPlayers do
			task.wait(1)
		end

		setPhase("Countdown")
		for i = common.countdown, 1, -1 do
			ReplicatedStorage:SetAttribute("MatchCountdown", i)
			broadcast("Countdown", i)
			task.wait(1)
		end

		local modeName = chooseMode()
		local rules = Modes[modeName]
		currentRules = rules
		Rules.current = rules
		applyTeams(rules)
		VehicleService.SetEnabled(rules.vehicles ~= false)
		resetScores()
		running = true
		ReplicatedStorage:SetAttribute("MatchMode", modeName)
		ReplicatedStorage:SetAttribute("MatchScoreToWin", rules.scoreToWin)
		ReplicatedStorage:SetAttribute("MatchEndsAt", workspace:GetServerTimeNow() + rules.timeLimit)
		setPhase("Playing")
		broadcast("Started", { mode = modeName, scoreToWin = rules.scoreToWin })
		if rules.scoreBy == "infection" then
			InfectionService.Begin(rules) -- los zombis se eligen antes de aparecer
		end
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
		FlagService.Stop()
		HillService.Stop()
		InfectionService.Stop()
		setPhase("Ended")
		broadcast("Ended", buildResults(rules, winningSide))
		task.wait(common.resultsTime)
	end
end

return MatchService
