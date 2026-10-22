-- Ciclo de partida: esperar jugadores, cuenta regresiva, jugar, mostrar ganador.
-- Modos: Team Slayer (puntos por bajas) y Captura la bandera (puntos por capturas).
--
-- El estado de la partida se guarda en atributos de ReplicatedStorage para que la pantalla
-- de cada jugador lo lea (también quien entra a mitad de partida):
--   MatchPhase      "Waiting" | "Countdown" | "Playing" | "Ended"
--   MatchCountdown  segundos que faltan para empezar
--   MatchEndsAt     cuándo se acaba el tiempo (en el reloj de workspace:GetServerTimeNow())
--   MatchMode       el modo que se juega ("TeamSlayer" o "CaptureTheFlag")
--   MatchScoreToWin puntos para ganar (bajas o capturas)
-- El marcador de cada equipo es el atributo "Score" del Team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Modes = require(ReplicatedStorage.Shared.Config.Modes)
local FlagService = require(script.Parent.FlagService)
local HealthService = require(script.Parent.HealthService)

local matchState = ReplicatedStorage.Remotes.MatchState :: RemoteEvent
local killFeed = ReplicatedStorage.Remotes.KillFeed :: RemoteEvent

local MatchService = {}

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
	if not killer or killer == victim or killer.Team == victim.Team then
		return
	end
	local kills = getStat(killer, "Bajas")
	if kills then
		kills.Value += 1
	end
	local team = killer.Team
	if team and currentRules.scoreBy == "kills" then
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

-- Tabla de resultados: jugadores ordenados por bajas (y con menos muertes en empate)
local function buildResults(winningTeam: Team?)
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
	for _, team in Teams:GetTeams() do
		table.insert(
			teamScores,
			{ name = team.Name, color = team.TeamColor.Color, score = scores[team] or 0 }
		)
	end
	return {
		winner = if winningTeam then winningTeam.Name else nil,
		winnerColor = if winningTeam then winningTeam.TeamColor.Color else nil,
		teams = teamScores,
		players = players,
	}
end

local function winner(rules): Team?
	for team, score in scores do
		if score >= rules.scoreToWin then
			return team
		end
	end
	return nil
end

function MatchService.Run()
	local common = Modes.Common

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
		resetScores()
		running = true
		ReplicatedStorage:SetAttribute("MatchMode", modeName)
		ReplicatedStorage:SetAttribute("MatchScoreToWin", rules.scoreToWin)
		ReplicatedStorage:SetAttribute("MatchEndsAt", workspace:GetServerTimeNow() + rules.timeLimit)
		setPhase("Playing")
		broadcast("Started", { mode = modeName, scoreToWin = rules.scoreToWin })
		for _, player in Players:GetPlayers() do
			player:LoadCharacter()
		end
		if rules.scoreBy == "captures" then
			FlagService.Begin(function(_player, team)
				if running then
					setScore(team, scores[team] + 1)
				end
			end)
		end

		local startTime = os.clock()
		local winningTeam = nil
		while os.clock() - startTime < rules.timeLimit do
			winningTeam = winner(rules)
			if winningTeam then
				break
			end
			task.wait(0.5)
		end
		running = false
		FlagService.Stop()
		setPhase("Ended")
		broadcast("Ended", buildResults(winningTeam))
		task.wait(common.resultsTime)
	end
end

return MatchService
