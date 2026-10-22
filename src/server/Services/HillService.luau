-- La colina del modo Rey de la colina.
--
-- En lugar de estar siempre en el centro, la colina aparece en un lugar al azar del mapa
-- y se mueve cada moveEvery segundos. Para que sea justa, un lugar solo sirve si:
--   * es piso plano y abierto (cabe la colina completa y no queda pegada a un muro),
--   * no está demasiado cerca de los puntos de aparición de ningún equipo,
--   * se puede llegar caminando desde la base de los dos equipos (lo revisa
--     PathfindingService, el mismo sistema que usan los personajes que caminan solos).
--
-- Cada segundo que un equipo está solo en la colina, gana 1 punto. Si hay jugadores de los
-- dos equipos, la colina está "en disputa" y nadie suma.

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Modes = require(ReplicatedStorage.Shared.Config.Modes)

local killFeed = ReplicatedStorage.Remotes.KillFeed :: RemoteEvent

local rules = Modes.KingOfTheHill
local ZONE_HEIGHT = 10 -- qué tan alto se ve el cilindro de la colina
local MAX_TRIES = 60 -- lugares al azar que se prueban antes de rendirse
local NEUTRAL = Color3.fromRGB(235, 235, 235)
local CONTESTED = Color3.fromRGB(255, 170, 0)

local HillService = {}

local map: Instance? = nil
local zone: Part? = nil
local label: TextLabel? = nil
local running = 0 -- cambia en cada Begin/Stop: así el ciclo viejo sabe que debe terminar

local function announce(text: string, color: Color3?)
	killFeed:FireAllClients({ message = text, color = color or NEUTRAL })
end

-- El cilindro transparente que marca la colina, con un letrero que se ve a través de muros
local function buildZone(): (Part, TextLabel)
	local part = Instance.new("Part")
	part.Name = "Hill"
	part.Shape = Enum.PartType.Cylinder
	-- El eje de un cilindro es X: se gira para que quede de pie
	part.Size = Vector3.new(ZONE_HEIGHT, rules.hillRadius * 2, rules.hillRadius * 2)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.ForceField
	part.Color = NEUTRAL
	part.Transparency = 0.3

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 40)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, ZONE_HEIGHT / 2 + 3, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = part
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextSize = 22
	text.TextColor3 = NEUTRAL
	text.TextStrokeTransparency = 0.3
	text.Text = "COLINA"
	text.Parent = billboard
	return part, text
end

local function rayDown(origin: Vector3, ignore: { Instance }): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return workspace:Raycast(origin, Vector3.new(0, -200, 0), params)
end

-- ¿Este lugar sirve para la colina? Devuelve el punto sobre el piso, o nil
local function tryPlace(x: number, z: number, ignore: { Instance }, spawns: { SpawnLocation }): Vector3?
	local hit = rayDown(Vector3.new(x, 150, z), ignore)
	if not hit then
		return nil
	end
	local center = hit.Position
	-- Piso plano y abierto: alrededor de la orilla el piso debe estar a la misma altura
	for i = 0, 7 do
		local angle = i * math.pi / 4
		local edge = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rules.hillRadius
		local edgeHit = rayDown(Vector3.new(edge.X, center.Y + ZONE_HEIGHT, edge.Z), ignore)
		if not edgeHit or math.abs(edgeHit.Position.Y - center.Y) > 1.5 then
			return nil
		end
	end
	-- Lejos de los puntos de aparición
	for _, spawn in spawns do
		if (spawn.Position - center).Magnitude < rules.minSpawnDistance then
			return nil
		end
	end
	return center
end

-- ¿Se puede llegar caminando desde cada base?
local function reachable(goal: Vector3, spawns: { SpawnLocation }): boolean
	for _, team in Teams:GetTeams() do
		local from: SpawnLocation? = nil
		for _, spawn in spawns do
			if spawn.TeamColor == team.TeamColor then
				from = spawn
				break
			end
		end
		if from then
			local path =
				PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
			local ok = pcall(function()
				path:ComputeAsync(from.Position + Vector3.new(0, 3, 0), goal)
			end)
			if not ok or path.Status ~= Enum.PathStatus.Success then
				return false
			end
		end
	end
	return true
end

-- El rectángulo que ocupa el mapa visto desde arriba: {xMin, xMax, zMin, zMax}
local function mapBounds(mapRoot: Instance): { number }
	local bounds = { math.huge, -math.huge, math.huge, -math.huge }
	for _, part in mapRoot:GetDescendants() do
		if part:IsA("BasePart") then
			bounds[1] = math.min(bounds[1], part.Position.X)
			bounds[2] = math.max(bounds[2], part.Position.X)
			bounds[3] = math.min(bounds[3], part.Position.Z)
			bounds[4] = math.max(bounds[4], part.Position.Z)
		end
	end
	return bounds
end

-- Busca un lugar al azar que cumpla todo; si no encuentra, regresa el centro del mapa
local function chooseSpot(previous: Vector3?): Vector3
	local mapRoot = map :: Instance
	local spawns: { SpawnLocation } = {}
	for _, item in mapRoot:GetDescendants() do
		if item:IsA("SpawnLocation") then
			table.insert(spawns, item)
		end
	end
	-- Los rayos ignoran a los jugadores, la colina y las plataformas de objetos
	local ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	if zone then
		table.insert(ignore, zone)
	end
	local pickups = mapRoot:FindFirstChild("WeaponPickups")
	if pickups then
		table.insert(ignore, pickups)
	end

	local bounds = mapBounds(mapRoot)
	for _ = 1, MAX_TRIES do
		local x = bounds[1] + math.random() * (bounds[2] - bounds[1])
		local z = bounds[3] + math.random() * (bounds[4] - bounds[3])
		local spot = tryPlace(x, z, ignore, spawns)
		local farFromLast = not previous or (spot and (spot - previous).Magnitude > rules.hillRadius * 4)
		if spot and farFromLast and reachable(spot, spawns) then
			return spot
		end
	end
	warn("[Hill] No encontré un lugar al azar; pongo la colina en el centro")
	local hit = rayDown(Vector3.new((bounds[1] + bounds[2]) / 2, 150, (bounds[3] + bounds[4]) / 2), ignore)
	return if hit then hit.Position else Vector3.zero
end

local function placeZone(spot: Vector3)
	local part = zone :: Part
	part.CFrame = CFrame.new(spot + Vector3.new(0, ZONE_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	part.Parent = workspace
end

-- ¿Quiénes están dentro? Devuelve los equipos que tienen al menos un jugador vivo adentro
local function teamsInside(spot: Vector3): { Team }
	local found: { [Team]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if player.Team and humanoid and humanoid.Health > 0 and root then
			local offset = root.Position - spot
			local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if flat <= rules.hillRadius and offset.Y > -2 and offset.Y < ZONE_HEIGHT then
				found[player.Team] = true
			end
		end
	end
	local list = {}
	for team in found do
		table.insert(list, team)
	end
	return list
end

function HillService.Setup(mapFolder: Instance)
	map = mapFolder
end

-- Pone la colina y empieza a dar puntos. score(team, puntos) se llama cada segundo.
function HillService.Begin(score: (Team, number) -> ())
	if not zone then
		zone, label = buildZone()
	end
	running += 1
	local myRun = running
	task.spawn(function()
		local spot = chooseSpot(nil)
		if myRun ~= running then
			return
		end
		placeZone(spot)
		announce("¡Apareció la colina! Búscala con el letrero COLINA")
		local placedAt = os.clock()
		while myRun == running do
			task.wait(1)
			if myRun ~= running then
				break
			end
			local inside = teamsInside(spot)
			local part, text = zone :: Part, label :: TextLabel
			if #inside == 1 then
				local team = inside[1]
				part.Color = team.TeamColor.Color
				text.Text = "COLINA: " .. string.upper(team.Name)
				text.TextColor3 = team.TeamColor.Color
				score(team, 1)
			elseif #inside > 1 then
				part.Color = CONTESTED
				text.Text = "COLINA EN DISPUTA"
				text.TextColor3 = CONTESTED
			else
				part.Color = NEUTRAL
				text.Text = "COLINA"
				text.TextColor3 = NEUTRAL
			end
			-- La colina se mueve a otro lugar al azar
			if rules.moveEvery > 0 and os.clock() - placedAt >= rules.moveEvery then
				spot = chooseSpot(spot)
				if myRun ~= running then
					break
				end
				placeZone(spot)
				placedAt = os.clock()
				announce("La colina se movió")
			end
		end
	end)
end

-- Quita la colina al terminar la partida
function HillService.Stop()
	running += 1
	if zone then
		zone.Parent = nil
	end
end

return HillService
