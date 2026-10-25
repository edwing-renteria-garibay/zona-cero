-- Qué clase de servidor es este y qué se juega en él. Hay tres:
--   "public"  Partida rápida: un servidor normal de Roblox. Modo y mapa al azar (Config/Modes y
--             Config/Maps) y, si falta gente, bots (Config/Bots).
--   "ai"      Contra la IA: un servidor reservado solo para ti (y los amigos que invites).
--             Siempre se juega el modo que elegiste; todos los jugadores van en el mismo
--             equipo contra bots, con bots aliados si faltan para 5 contra 5 (Config/Bots,
--             vsAI.teamSize). Se puede elegir "sin aliados": tú (y tus amigos) solos contra
--             todos los bots rivales. En Infección, los bots son los zombis.
--   "private" Partida privada: un servidor reservado con el modo y el mapa que elegiste, para
--             jugar con tus amigos. Si faltan jugadores y el modo lo permite, entran bots.
--
-- Un servidor reservado se crea con TeleportService:ReserveServer: es un servidor del mismo
-- juego al que solo se entra con su código. Los datos de la partida viajan con el jugador
-- en el teletransporte (TeleportData) y este servidor los lee cuando llega el primero.
-- Los amigos se invitan con la ventana de invitaciones de Roblox: la invitación lleva el
-- código, y el servidor público donde caen los manda a la partida (ver onPlayerAdded).
--
-- En una sala reservada (contra la IA o privada) la primera partida no empieza sola: espera a
-- que el anfitrión (el primero que llegó) apriete "Iniciar partida", así los amigos invitados
-- alcanzan a entrar. Las siguientes empiezan solas, como siempre.
-- El anfitrión también puede cambiar el modo (y el mapa o la dificultad) sin salir de la
-- sala: la partida en curso termina y la sala vuelve a esperar a que apriete "Iniciar".
--
-- Nota: en Studio no existen los servidores reservados ni el teletransporte; solo se pueden
-- probar en el juego publicado.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local TeleportService = game:GetService("TeleportService")

local Bots = require(ReplicatedStorage.Shared.Config.Bots)
local Maps = require(ReplicatedStorage.Shared.Config.Maps)
local Modes = require(ReplicatedStorage.Shared.Config.Modes)
local MapService = require(script.Parent.MapService)

local requestMatch = ReplicatedStorage.Remotes.RequestMatch :: RemoteEvent

local REQUEST_COOLDOWN = 8 -- segundos entre pedidos de un mismo jugador

local MatchSettings = {
	kind = "public", -- "public", "ai" o "private"
	mode = nil :: string?, -- el modo elegido (nil = al azar, como siempre)
	map = nil :: string?, -- el mapa elegido (nil = al azar)
	difficulty = nil :: string?, -- contra la IA: la dificultad elegida (nil = Bots.defaultDifficulty)
	allies = true, -- contra la IA por equipos: ¿se rellena tu equipo con bots aliados?
}

local host: Player? = nil -- en una sala reservada: quien puede iniciar la partida
local started = false -- ¿el anfitrión ya inició la primera partida?
local changed = false -- el anfitrión cambió el modo: la partida en curso debe terminar

local lastRequest: { [Player]: number } = {}

-- ¿Es un servidor reservado? (los privados de pago tienen dueño; los reservados no)
local function isReserved(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

-- ¿Se puede jugar este modo contra la IA? Los que tienen bots y la Infección (zombis bot)
function MatchSettings.CanPlayVsAI(modeName: string): boolean
	local mode = Modes[modeName]
	return type(mode) == "table" and mode.name ~= nil and (mode.bots == true or mode.botZombies == true)
end

local function validMode(modeName: any): boolean
	return type(modeName) == "string" and table.find(Modes.randomPool, modeName) ~= nil
end

local function validMap(mapName: any): boolean
	return type(mapName) == "string" and Maps.list[mapName] ~= nil
end

-- El equipo de los jugadores contra la IA (los bots van al otro)
function MatchSettings.HumanTeam(): Team?
	return Teams:FindFirstChild("Azul") :: Team?
end

function MatchSettings.VsAI(): boolean
	return MatchSettings.kind == "ai"
end

-- Contra la IA: ¿van bots en el equipo de los jugadores? (false = solos contra todos)
function MatchSettings.Allies(): boolean
	return MatchSettings.kind == "ai" and MatchSettings.allies
end

-- ¿Hay que esperar a que el anfitrión inicie? (MatchService no empieza mientras sea true)
function MatchSettings.WaitingForHost(): boolean
	return MatchSettings.kind ~= "public" and not started
end

-- El anfitrión apretó "Iniciar partida": esta empieza y las siguientes ya no esperan
function MatchSettings.MarkStarted()
	if MatchSettings.kind ~= "public" then
		started = true
		ReplicatedStorage:SetAttribute("WaitingForHost", nil)
	end
end

-- ¿El anfitrión cambió el modo? (MatchService termina la partida en curso). Lo "consume"
function MatchSettings.TakeChange(): boolean
	local was = changed
	changed = false
	return was
end

local function setHost(player: Player?)
	host = player
	ReplicatedStorage:SetAttribute("HostUserId", if player then player.UserId else nil)
end

-- Lo publica en ReplicatedStorage para que el menú del cliente sepa dónde está.
-- "loading": servidor reservado que todavía no recibe los datos de la partida
local function publish(inviteCode: string?, loading: boolean?)
	ReplicatedStorage:SetAttribute("ServerKind", if loading then "loading" else MatchSettings.kind)
	ReplicatedStorage:SetAttribute("ServerMode", MatchSettings.mode)
	ReplicatedStorage:SetAttribute("ServerMap", MatchSettings.map)
	ReplicatedStorage:SetAttribute("ServerDifficulty", MatchSettings.difficulty)
	ReplicatedStorage:SetAttribute(
		"ServerAllies",
		if MatchSettings.kind == "ai" then MatchSettings.allies else nil
	)
	ReplicatedStorage:SetAttribute("InviteCode", inviteCode)
end

-- El primero en llegar a un servidor reservado trae los datos de la partida
local function configure(data: any)
	if type(data) ~= "table" or (data.kind ~= "ai" and data.kind ~= "private") then
		return
	end
	if not validMode(data.mode) or (data.kind == "ai" and not MatchSettings.CanPlayVsAI(data.mode)) then
		return
	end
	MatchSettings.kind = data.kind
	MatchSettings.mode = data.mode
	if data.kind == "ai" and type(data.difficulty) == "string" and Bots.difficulties[data.difficulty] then
		MatchSettings.difficulty = data.difficulty
	end
	MatchSettings.allies = data.allies ~= false
	if data.kind == "private" and validMap(data.map) then
		MatchSettings.map = data.map
		MapService.SetForced(data.map)
	end
	publish(if type(data.code) == "string" then data.code else nil)
	ReplicatedStorage:SetAttribute("WaitingForHost", true)
	print("[Partida]", data.kind, data.mode, data.map or "mapa al azar")
end

-- Manda a unos jugadores a un servidor reservado
local function teleportTo(players: { Player }, code: string, data: any): (boolean, string?)
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	if data then
		options:SetTeleportData(data)
	end
	local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, players, options)
	return ok, if ok then nil else tostring(err)
end

-- El menú pide una partida: ("ai", modo, nil, dificultad, aliados) o ("private", modo, mapa)
local function onRequest(player: Player, kind: any, modeName: any, mapName: any, difficulty: any, allies: any)
	local now = os.clock()
	if now - (lastRequest[player] or 0) < REQUEST_COOLDOWN then
		return
	end
	lastRequest[player] = now
	if kind ~= "ai" and kind ~= "private" then
		return
	end
	if not validMode(modeName) or (kind == "ai" and not MatchSettings.CanPlayVsAI(modeName)) then
		requestMatch:FireClient(player, "error", "Ese modo no se puede elegir.")
		return
	end
	if not validMap(mapName) then
		mapName = nil -- "Aleatorio"
	end
	if kind ~= "ai" or type(difficulty) ~= "string" or not Bots.difficulties[difficulty] then
		difficulty = nil
	end
	local ok, code = pcall(TeleportService.ReserveServer, TeleportService, game.PlaceId)
	if not ok then
		warn("[Partida] No se pudo reservar un servidor:", code)
		requestMatch:FireClient(
			player,
			"error",
			"No se pudo crear la partida. En Studio no funciona: pruébalo en el juego publicado."
		)
		return
	end
	requestMatch:FireClient(player, "teleporting")
	local sent, err = teleportTo({ player }, code, {
		kind = kind,
		mode = modeName,
		map = mapName,
		difficulty = difficulty,
		allies = allies ~= false,
		code = code,
	})
	if not sent then
		warn("[Partida] Falló el teletransporte:", err)
		requestMatch:FireClient(player, "error", "No se pudo entrar a la partida. Intenta otra vez.")
	end
end

-- El anfitrión cambia lo que se juega en esta sala: ("change", modo, mapa, dificultad, aliados)
local function onChange(player: Player, modeName: any, mapName: any, difficulty: any, allies: any)
	if player ~= host or MatchSettings.kind == "public" then
		return
	end
	local now = os.clock()
	if now - (lastRequest[player] or 0) < REQUEST_COOLDOWN then
		requestMatch:FireClient(player, "error", "Espera unos segundos e intenta otra vez.")
		return
	end
	lastRequest[player] = now
	local kind = MatchSettings.kind
	if not validMode(modeName) or (kind == "ai" and not MatchSettings.CanPlayVsAI(modeName)) then
		requestMatch:FireClient(player, "error", "Ese modo no se puede elegir.")
		return
	end
	MatchSettings.mode = modeName
	if kind == "ai" and type(difficulty) == "string" and Bots.difficulties[difficulty] then
		MatchSettings.difficulty = difficulty
	end
	if kind == "ai" then
		MatchSettings.allies = allies ~= false
	end
	if kind == "private" then
		MatchSettings.map = if validMap(mapName) then mapName else nil
		MapService.SetForced(MatchSettings.map)
	end
	publish(ReplicatedStorage:GetAttribute("InviteCode") :: string?)
	-- Se acaba la partida en curso (si hay) y se espera otra vez el botón "Iniciar partida"
	changed = true
	started = false
	ReplicatedStorage:SetAttribute("WaitingForHost", true)
	requestMatch:FireClient(player, "changed")
	print("[Partida] El anfitrión cambió a", modeName, MatchSettings.map or "mapa al azar")
end

-- Volver a una partida rápida (un servidor público)
local function onLeave(player: Player)
	local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, { player })
	if not ok then
		warn("[Partida] No se pudo regresar:", err)
		requestMatch:FireClient(player, "error", "No se pudo salir. Intenta otra vez.")
	end
end

local function onPlayerAdded(player: Player)
	local joinData = player:GetJoinData()
	if isReserved() then
		if not host then
			setHost(player) -- el primero que llega es el anfitrión
		end
		if ReplicatedStorage:GetAttribute("ServerKind") == "loading" then
			configure(joinData.TeleportData)
			if MatchSettings.kind == "public" then
				publish(nil) -- sin datos válidos: se juega como una partida rápida
			end
		end
		return
	end
	-- En un servidor público: ¿viene de una invitación a una partida privada? La invitación
	-- trae el código del servidor reservado; se le manda para allá
	local launch = joinData.LaunchData
	if type(launch) == "string" and launch ~= "" then
		local ok, data = pcall(HttpService.JSONDecode, HttpService, launch)
		if ok and type(data) == "table" and type(data.join) == "string" then
			requestMatch:FireClient(player, "teleporting")
			local sent, err = teleportTo({ player }, data.join, nil)
			if not sent then
				warn("[Partida] No se pudo seguir la invitación:", err)
				requestMatch:FireClient(player, "error", "Esa partida ya no existe.")
			end
		end
	end
end

function MatchSettings.Start()
	publish(nil, isReserved())
	requestMatch.OnServerEvent:Connect(function(player, action, ...)
		if action == "leave" then
			onLeave(player)
		elseif action == "change" then
			onChange(player, ...)
		elseif action == "start" then
			-- Solo el anfitrión, y solo mientras se espera
			if player == host and MatchSettings.WaitingForHost() then
				MatchSettings.MarkStarted()
			end
		else
			onRequest(player, action, ...)
		end
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		-- Si se va el anfitrión, el siguiente que quede toma su lugar
		if player == host then
			local others = Players:GetPlayers()
			local index = table.find(others, player)
			if index then
				table.remove(others, index)
			end
			setHost(others[1])
		end
	end)
end

return MatchSettings
