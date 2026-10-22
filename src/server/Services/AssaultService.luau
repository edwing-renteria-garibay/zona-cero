-- Modo Asalto: una sola bomba. En cada ronda un equipo ataca y el otro defiende.
--
--   * La bomba aparece en la base de bandera (FlagStand) de los atacantes. Cualquiera de
--     ellos la toma al tocarla y la lleva en la espalda.
--   * Para anotar hay que llevarla a la base de bandera enemiga (marcada con una zona
--     naranja y el letrero "OBJETIVO") y quedarse ahí armTime segundos: la bomba explota,
--     mueren todos los defensores y los atacantes ganan 1 punto.
--   * Si matan al que la lleva, la bomba cae y se queda ahí hasta que otro atacante la tome.
--     Los defensores no la pueden mover: tienen que cuidar que nadie la recoja.
--   * La ronda termina al explotar la bomba o al acabarse roundTime. Entonces todos
--     reaparecen y los equipos se cambian los papeles.
--
-- En ReplicatedStorage, para el marcador:
--   AssaultAttackers  nombre del equipo que ataca
--   AssaultRound      número de ronda
--   AssaultRoundEndsAt cuándo se acaba la ronda (reloj de workspace:GetServerTimeNow())

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local ExplosionService = require(script.Parent.ExplosionService)
local HealthService = require(script.Parent.HealthService)

local killFeed = ReplicatedStorage.Remotes.KillFeed :: RemoteEvent

local CHECK_INTERVAL = 0.1 -- segundos entre revisiones
local ZONE_COLOR = Color3.fromRGB(255, 160, 30)
local ZONE_HEIGHT = 12

local AssaultService = {}

local stands: { [Team]: BasePart } = {}
local rules: any = nil
local generation = 0 -- cambia en cada Begin/Stop: así una ronda vieja sabe que debe parar

-- La bomba
local bomb: Model? = nil
local body: BasePart? = nil
local label: TextLabel? = nil
local state: "home" | "carried" | "dropped" = "home"
local carrier: Player? = nil
local carryWeld: WeldConstraint? = nil
local lastPosition = Vector3.zero
local armProgress = 0
local zone: Part? = nil -- dónde se arma la bomba (en la base de los defensores)

local function announce(text: string, team: Team?)
	killFeed:FireAllClients({
		message = text,
		color = if team then team.TeamColor.Color else Color3.new(1, 1, 1),
	})
end

local function otherTeam(team: Team): Team
	for other in stands do
		if other ~= team then
			return other
		end
	end
	return team
end

local function standTop(stand: BasePart): Vector3
	return stand.Position + Vector3.new(0, stand.Size.Y / 2, 0)
end

-- Una caja negra con una luz roja y un letrero arriba
local function buildBomb(): (Model, BasePart, TextLabel)
	local model = Instance.new("Model")
	model.Name = "Bomb"
	local box = Instance.new("Part")
	box.Name = "Body"
	box.Size = Vector3.new(2.4, 1.6, 1.6)
	box.Color = Color3.fromRGB(35, 35, 35)
	box.Material = Enum.Material.Metal
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.Massless = true
	box.Parent = model
	local light = Instance.new("Part")
	light.Name = "Light"
	light.Size = Vector3.new(0.5, 0.3, 0.5)
	light.CFrame = CFrame.new(0, 0.95, 0)
	light.Color = Color3.fromRGB(255, 40, 40)
	light.Material = Enum.Material.Neon
	light.CanCollide = false
	light.CanQuery = false
	light.CanTouch = false
	light.Massless = true
	light.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = box
	weld.Part1 = light
	weld.Parent = light
	model.PrimaryPart = box

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 26)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true -- se ve a través de las paredes: todos saben dónde está
	billboard.Parent = box
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextSize = 16
	text.TextColor3 = Color3.fromRGB(255, 80, 80)
	text.TextStrokeTransparency = 0.3
	text.Text = "BOMBA"
	text.Parent = billboard
	return model, box, text
end

-- La zona donde se deja la bomba: un cilindro naranja transparente sobre la base de los
-- defensores, con un letrero que se ve a través de las paredes
local function buildZone(): Part
	local part = Instance.new("Part")
	part.Name = "BombZone"
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Color = ZONE_COLOR
	part.Material = Enum.Material.ForceField
	part.Transparency = 0.3
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 26)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, ZONE_HEIGHT / 2 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextSize = 16
	text.TextColor3 = ZONE_COLOR
	text.TextStrokeTransparency = 0.3
	text.Text = "OBJETIVO"
	text.Parent = billboard
	return part
end

-- Pone la zona sobre la base de bandera de los defensores
local function placeZone(stand: BasePart)
	local part = zone :: Part
	-- Un cilindro de Roblox está acostado sobre el eje X: se gira para pararlo
	part.Size = Vector3.new(ZONE_HEIGHT, rules.plantRadius * 2, rules.plantRadius * 2)
	part.CFrame = CFrame.new(standTop(stand) + Vector3.new(0, ZONE_HEIGHT / 2, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	part.Parent = workspace
end

-- ¿Está dentro de la zona? Se mide de lado (en el piso) y de alto por separado
local function insideZone(position: Vector3, stand: BasePart): boolean
	local top = standTop(stand)
	local flat = Vector3.new(position.X - top.X, 0, position.Z - top.Z).Magnitude
	return flat < rules.plantRadius and position.Y > top.Y - 2 and position.Y < top.Y + ZONE_HEIGHT
end

local function unweld()
	if carryWeld then
		carryWeld:Destroy()
		carryWeld = nil
	end
end

-- Deja la bomba quieta en el piso, en position
local function placeAt(position: Vector3)
	unweld()
	local part = body :: BasePart
	part.Anchored = true
	local model = bomb :: Model
	model:PivotTo(CFrame.new(position + Vector3.new(0, 0.8, 0)))
	lastPosition = position
end

local function attackers(): Team?
	return Teams:FindFirstChild(ReplicatedStorage:GetAttribute("AssaultAttackers") or "") :: Team?
end

local function returnHome()
	state = "home"
	carrier = nil
	armProgress = 0
	local team = attackers()
	if team and stands[team] then
		placeAt(standTop(stands[team]))
	end
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function pickUp(player: Player)
	local character = player.Character :: Model
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	if not torso then
		return
	end
	state = "carried"
	carrier = player
	unweld()
	local model = bomb :: Model
	model:PivotTo(torso.CFrame * CFrame.new(0, 0.2, 1.1)) -- en la espalda
	local part = body :: BasePart
	part.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = part
	weld.Parent = part
	carryWeld = weld
	announce(string.format("%s tomó la bomba", player.Name), player.Team)
end

local function drop()
	local who = carrier
	state = "dropped"
	carrier = nil
	armProgress = 0
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { bomb :: Model }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(lastPosition + Vector3.new(0, 2, 0), Vector3.new(0, -50, 0), params)
	placeAt(if hit then hit.Position else lastPosition)
	if who then
		announce(string.format("%s soltó la bomba", who.Name), who.Team)
	end
end

-- Revisa la bomba. Devuelve true si explotó.
local function update(dt: number): boolean
	local team = attackers()
	if not team then
		return false
	end
	local target = stands[otherTeam(team)]
	local text = label :: TextLabel

	if state == "carried" then
		local player = carrier :: Player
		local root = if player.Parent then getRoot(player) else nil
		if not root then
			drop() -- murió o salió del juego
			return false
		end
		lastPosition = root.Position - Vector3.new(0, 3, 0)
		if insideZone(root.Position, target) then
			if armProgress == 0 then
				announce(string.format("¡%s está armando la bomba!", player.Name), player.Team)
			end
			armProgress += dt
			text.Text = string.format("ARMANDO %.1f", math.max(rules.armTime - armProgress, 0))
			if armProgress >= rules.armTime then
				return true
			end
		else
			armProgress = 0
			text.Text = "BOMBA"
		end
		return false
	end

	text.Text = "BOMBA"
	for _, player in Players:GetPlayers() do
		local root = getRoot(player)
		if not root or not player.Team then
			continue
		end
		if (root.Position - (lastPosition + Vector3.new(0, 3, 0))).Magnitude > rules.pickupRadius then
			continue
		end
		if player.Team == team then
			pickUp(player)
			break
		end
	end
	return false
end

local function detonate()
	local team = attackers()
	local bomber = carrier
	local position = (body :: BasePart).Position
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = 16
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0 -- solo se ve; la ronda se acaba de todos modos
	explosion.Parent = workspace
	ExplosionService.PlaySoundAt(Sounds.explosion.rocket, position)
	unweld()
	carrier = nil
	if bomb then
		bomb.Parent = nil
	end
	if zone then
		zone.Parent = nil
	end
	if not team then
		return
	end
	announce(string.format("¡%s detonó la bomba!", team.Name), team)
	-- Todos los defensores mueren, estén donde estén; las bajas son para quien la armó
	for _, player in Players:GetPlayers() do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if player.Team and player.Team ~= team and humanoid and humanoid.Health > 0 then
			HealthService.Damage(humanoid, 10000, bomber, "bomb")
		end
	end
end

-- Las rondas. onScore(team) se llama cada vez que un equipo detona la bomba.
local function runRounds(myGeneration: number, onScore: (Team) -> ())
	-- Rojo ataca en la ronda 1, Azul en la 2, y así se van turnando
	local team = Teams:FindFirstChild("Rojo") :: Team?
	if not team or not stands[team] then
		team = next(stands)
	end
	local round = 0
	while generation == myGeneration do
		round += 1
		ReplicatedStorage:SetAttribute("AssaultAttackers", team.Name)
		ReplicatedStorage:SetAttribute("AssaultRound", round)
		ReplicatedStorage:SetAttribute("AssaultRoundEndsAt", workspace:GetServerTimeNow() + rules.roundTime)
		returnHome()
		if bomb then
			bomb.Parent = workspace
		end
		placeZone(stands[otherTeam(team)])
		if round > 1 then
			for _, player in Players:GetPlayers() do
				player:LoadCharacter()
			end
		end
		announce(
			string.format("Ronda %d: ataca %s, defiende %s", round, team.Name, otherTeam(team).Name),
			team
		)

		local started = os.clock()
		local exploded = false
		while generation == myGeneration and os.clock() - started < rules.roundTime do
			local dt = task.wait(CHECK_INTERVAL)
			if update(dt) then
				exploded = true
				break
			end
		end
		if generation ~= myGeneration then
			return
		end
		if exploded then
			detonate()
			onScore(team)
		else
			unweld()
			carrier = nil
			if bomb then
				bomb.Parent = nil
			end
			if zone then
				zone.Parent = nil
			end
			announce(
				string.format("Se acabó el tiempo: %s defendió su base", otherTeam(team).Name),
				otherTeam(team)
			)
		end
		task.wait(rules.roundBreak)
		team = otherTeam(team)
	end
end

-- Busca las bases de bandera del mapa: ahí aparece la bomba y ahí se arma
function AssaultService.Setup(map: Instance)
	for _, stand in map:GetDescendants() do
		local team = stand:IsA("BasePart") and Teams:FindFirstChild(stand:GetAttribute("Team") or "")
		if team and stand.Name == "FlagStand" then
			stands[team :: Team] = stand :: BasePart
		end
	end
end

-- ¿El mapa tiene una base para cada equipo?
function AssaultService.HasBases(): boolean
	local count = 0
	for _ in stands do
		count += 1
	end
	return count >= 2
end

function AssaultService.Begin(modeRules, onScore: (Team) -> ())
	rules = modeRules
	if not bomb then
		bomb, body, label = buildBomb()
	end
	if not zone then
		zone = buildZone()
	end
	generation += 1
	task.spawn(runRounds, generation, onScore)
end

function AssaultService.Stop()
	generation += 1
	unweld()
	carrier = nil
	if bomb then
		bomb.Parent = nil
	end
	if zone then
		zone.Parent = nil
	end
	ReplicatedStorage:SetAttribute("AssaultAttackers", nil)
end

return AssaultService
