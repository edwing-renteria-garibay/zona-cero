-- Ciclo de partida de Team Slayer: esperar jugadores, cuenta regresiva, jugar, mostrar ganador.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Modes = require(ReplicatedStorage.Shared.Config.Modes)
local HealthService = require(script.Parent.HealthService)

local matchState = ReplicatedStorage.Remotes.MatchState :: RemoteEvent

local MatchService = {}

local scores: { [Team]: number } = {}
local running = false

local function broadcast(state: string, data: any?)
	matchState:FireAllClients(state, data)
end

local function resetScores()
	for _, team in Teams:GetTeams() do
		scores[team] = 0
	end
end

HealthService.Killed:Connect(function(victim: Player, killer: Player?)
	if not running or not killer or killer == victim or killer.Team == victim.Team then
		return
	end
	local team = killer.Team
	if team then
		scores[team] += 1
		broadcast("Score", { team = team.Name, score = scores[team] })
	end
end)

local function winner(rules): Team?
	for team, score in scores do
		if score >= rules.scoreToWin then
			return team
		end
	end
	return nil
end

function MatchService.Run(modeName: string)
	local rules = Modes[modeName]
	local common = Modes.Common

	while true do
		broadcast("Waiting")
		while #Players:GetPlayers() < common.minPlayers do
			task.wait(1)
		end

		for i = common.countdown, 1, -1 do
			broadcast("Countdown", i)
			task.wait(1)
		end

		resetScores()
		running = true
		broadcast("Started", { mode = modeName, scoreToWin = rules.scoreToWin })
		for _, player in Players:GetPlayers() do
			player:LoadCharacter()
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
		broadcast("Ended", { winner = winningTeam and winningTeam.Name or "Empate" })
		task.wait(10)
	end
end

return MatchService
