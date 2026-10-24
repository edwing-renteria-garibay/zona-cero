-- Bots: soldados que controla el servidor para que se pueda jugar sin más gente.
-- MatchService los pide al empezar una partida de un modo con bots = true (Config/Modes)
-- y los quita al terminar. Cuántos hay y qué tan buenos son: Config/Bots.
--
-- Cada bot tiene un carnet (ver Combatants) y un cuerpo que reaparece al morir. Su "cerebro"
-- se repite 10 veces por segundo:
--   1. Busca al enemigo más cercano (jugador o bot). Si lo ve, lo encara y le dispara.
--   2. Si no ve a nadie, camina hacia el enemigo más cercano con PathfindingService
--      (Roblox calcula un camino que esquiva muros y sube rampas).
--   3. Con un arma de fuego intenta quedarse a media distancia moviéndose de lado; sin armas
--      de fuego (A puño limpio, Pollos y machetes...) corre hacia ti para golpearte.
-- Las balas de los bots las calcula el servidor igual que las de los jugadores: respetan
-- escudos, equipos y bajas, y todos ven la trazadora.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Teams = game:GetService("Teams")

local Bots = require(ReplicatedStorage.Shared.Config.Bots)
local Melee = require(ReplicatedStorage.Shared.Config.Melee)
local Modes = require(ReplicatedStorage.Shared.Config.Modes)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Combatants = require(script.Parent.Combatants)
local ExplosionService = require(script.Parent.ExplosionService)
local HealthService = require(script.Parent.HealthService)
local VehicleService = require(script.Parent.VehicleService)

local remotes = ReplicatedStorage.Remotes
local shotFired = remotes.ShotFired :: RemoteEvent
local knockbackRemote = remotes.Knockback :: RemoteEvent

local THINK_EVERY = 0.1 -- segundos entre cada vez que el bot "piensa"
local REPATH_EVERY = 2 -- segundos entre cada cálculo de camino
local SAFE_SPAWN_DISTANCE = 40 -- aparece donde no haya enemigos a menos de esto
local SKIN = Color3.fromRGB(204, 153, 120)
local NO_TEAM_COLOR = Color3.fromRGB(110, 115, 90) -- verde militar en Asesino en solitario
local PANTS = Color3.fromRGB(45, 45, 40)

-- Animaciones R15 de Roblox (se usan si el cuerpo no trae las suyas)
local DEFAULT_ANIMATIONS = {
	idle = "rbxassetid://507766388",
	walk = "rbxassetid://507777826",
	run = "rbxassetid://507767714",
}

local BotService = {}

local active = false
local rules: any = Modes.TeamSlayer

-- Un punto de aparición de cada equipo (o todos en solitario)
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

-- El cuerpo vivo de alguien (y su Humanoid y su HumanoidRootPart)
local function aliveBody(who: Instance): (Model?, Humanoid?, BasePart?)
	local character = Combatants.Character(who)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if character and character.Parent and humanoid and humanoid.Health > 0 and root then
		return character, humanoid, root
	end
	return nil, nil, nil
end

-- Dónde aparece el bot: un punto de su equipo sin enemigos cerca (o el más alejado de ellos)
local function pickSpawn(card: Instance): SpawnLocation?
	local team = Combatants.TeamOf(card)
	local enemies = {}
	for _, who in Combatants.All() do
		local _, _, root = aliveBody(who)
		if root and Combatants.IsEnemy(card, who) then
			table.insert(enemies, root.Position)
		end
	end
	local safe, farthest, farthestDistance = {}, nil, -1
	for _, spawn in mapSpawns() do
		if team and spawn.TeamColor ~= team.TeamColor then
			continue
		end
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

-- Con qué pelea el bot en este modo: el primer arma de fuego normal de su loadout
-- (rifle, pistola...). Si no hay ninguna, va a golpes, con el arma de golpe que haya.
local function chooseWeapon(): (string?, any, boolean)
	local loadout = rules.loadout or Modes.Common.loadout
	for _, name in loadout do
		local stats = Weapons[name]
		if stats and not stats.kind and not stats.projectile then
			return name, stats, false
		end
	end
	for _, name in loadout do
		if Melee.weapons[name] then
			return name, Melee.weapons[name], true
		end
	end
	return nil, Melee, true
end

-- Una dirección un poco desviada al azar, hasta degrees grados
local function spreadDirection(direction: Vector3, degrees: number): Vector3
	local angle = math.rad(degrees) * math.sqrt(math.random())
	local around = math.random() * 2 * math.pi
	return (CFrame.lookAt(Vector3.zero, direction) * CFrame.Angles(0, 0, around) * CFrame.Angles(angle, 0, 0)).LookVector
end

local function isHeadPart(part: Instance): boolean
	if part.Name == "Head" then
		return true
	end
	local accessory = part.Parent
	if accessory and accessory:IsA("Accessory") then
		local weld = part:FindFirstChild("AccessoryWeld") :: Weld?
		return weld ~= nil and weld.Part1 ~= nil and weld.Part1.Name == "Head"
	end
	return false
end

-- Arma el cuerpo de un bot: un soldado con el torso y los brazos del color de su equipo
local function buildBody(card: Instance): Model
	local color = Combatants.TeamOf(card)
	local shirt = if color then color.TeamColor.Color else NO_TEAM_COLOR
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = SKIN
	description.TorsoColor = shirt
	description.LeftArmColor = shirt
	description.RightArmColor = shirt
	description.LeftLegColor = PANTS
	description.RightLegColor = PANTS
	local character = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	character.Name = card.Name
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayName = card.Name
	-- Los bots no se sientan en los jeeps (si tocan un asiento, Roblox los sentaría)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
	return character
end

-- Las animaciones de caminar y estar parado. Un NPC no tiene el script "Animate" de los
-- jugadores funcionando, así que el servidor las reproduce según qué tan rápido se mueve.
local function animate(character: Model, humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local animateScript = character:FindFirstChild("Animate")
	local function load(name: string): AnimationTrack?
		local folder = animateScript and animateScript:FindFirstChild(name)
		local existing = folder and folder:FindFirstChildOfClass("Animation")
		local animation = Instance.new("Animation")
		animation.AnimationId = if existing then existing.AnimationId else DEFAULT_ANIMATIONS[name]
		local ok, track = pcall(animator.LoadAnimation, animator, animation)
		return if ok then track else nil
	end
	local idle, run = load("idle"), load("run") or load("walk")
	if animateScript then
		animateScript:Destroy() -- sin jugador no hace nada
	end
	if idle then
		idle.Looped = true
		idle:Play()
	end
	humanoid.Running:Connect(function(speed)
		if not run then
			return
		end
		if speed > 1 then
			if not run.IsPlaying then
				run.Looped = true
				run:Play(0.15)
			end
			run:AdjustSpeed(speed / 16)
		elseif run.IsPlaying then
			run:Stop(0.15)
		end
	end)
end

local spawnBot: (card: Instance) -> ()

-- El cerebro: lo que hace un bot mientras está vivo (ver arriba)
local function think(card: Instance, character: Model, humanoid: Humanoid, root: BasePart)
	local head = character:FindFirstChild("Head") :: BasePart
	local weaponName, stats, melee = chooseWeapon()
	local tool = character:FindFirstChildOfClass("Tool")

	-- Mira a donde apunta sin depender de hacia dónde camina
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.Responsiveness = 25
	align.MaxTorque = math.huge
	align.Enabled = false
	align.Parent = root

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local path = PathfindingService:CreatePath({
		AgentRadius = 2.5,
		AgentHeight = 5.5,
		AgentCanJump = true,
		WaypointSpacing = 6,
	})
	local waypoints: { PathWaypoint } = {}
	local waypointIndex = 0
	local lastPath = 0
	local pathGoal: Vector3? = nil

	local ammo = if melee then 0 else stats.magazine
	local lastShot, lastMelee = 0, 0
	local burstLeft = 0
	local target: Instance? = nil
	local seenAt = 0
	local strafeSide, strafeUntil = 1, 0
	local lastPosition, stuckSince = root.Position, os.clock()
	local wanderGoal: Vector3? = nil

	-- ¿Lo ve? Un raycast de su cabeza a la del otro que no choque con nada antes
	local function canSee(otherCharacter: Model, otherRoot: BasePart): boolean
		local otherHead = otherCharacter:FindFirstChild("Head") :: BasePart?
		local point = if otherHead then otherHead.Position else otherRoot.Position
		local offset = point - head.Position
		if offset.Magnitude > Bots.sightRange then
			return false
		end
		local result = workspace:Raycast(head.Position, offset, params)
		return result == nil or result.Instance:IsDescendantOf(otherCharacter)
	end

	-- El enemigo más cercano que ve, o si no ve a nadie, el más cercano de todos
	local function findTarget(): (Instance?, boolean)
		local bestSeen, bestSeenDistance = nil, math.huge
		local bestAny, bestAnyDistance = nil, math.huge
		for _, who in Combatants.All() do
			if who == card or not Combatants.IsEnemy(card, who) then
				continue
			end
			local otherCharacter, _, otherRoot = aliveBody(who)
			if not otherCharacter or not otherRoot then
				continue
			end
			local distance = (otherRoot.Position - root.Position).Magnitude
			if distance < bestAnyDistance then
				bestAny, bestAnyDistance = who, distance
			end
			if distance < bestSeenDistance and canSee(otherCharacter, otherRoot) then
				bestSeen, bestSeenDistance = who, distance
			end
		end
		if bestSeen then
			return bestSeen, true
		end
		return bestAny, false
	end

	-- Camina hacia goal siguiendo un camino de PathfindingService
	local function walkTo(goal: Vector3)
		local now = os.clock()
		if not pathGoal or (goal - pathGoal).Magnitude > 12 or now - lastPath > REPATH_EVERY then
			lastPath = now
			pathGoal = goal
			local ok = pcall(path.ComputeAsync, path, root.Position, goal)
			if ok and path.Status == Enum.PathStatus.Success then
				waypoints = path:GetWaypoints()
				waypointIndex = math.min(2, #waypoints)
			else
				waypoints = {}
				waypointIndex = 0
			end
		end
		local waypoint = waypoints[waypointIndex]
		if not waypoint then
			humanoid:MoveTo(goal) -- sin camino: derecho hacia allá
			return
		end
		local flat = waypoint.Position - root.Position
		if Vector3.new(flat.X, 0, flat.Z).Magnitude < 3 then
			waypointIndex += 1
			waypoint = waypoints[waypointIndex]
			if not waypoint then
				return
			end
		end
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end
		humanoid:MoveTo(waypoint.Position)
	end

	local function face(position: Vector3)
		local flat = Vector3.new(position.X, root.Position.Y, position.Z)
		if (flat - root.Position).Magnitude > 0.1 then
			align.CFrame = CFrame.lookAt(root.Position, flat)
			align.Enabled = true
			humanoid.AutoRotate = false
		end
	end

	local function stopFacing()
		align.Enabled = false
		humanoid.AutoRotate = true
	end

	-- Un disparo: un raycast desviado al azar (Bots.spread) hacia el pecho del enemigo
	local function shoot(targetRoot: BasePart)
		local muzzle = tool and tool:FindFirstChild("Muzzle", true) :: Attachment?
		local from = if muzzle then muzzle.WorldPosition else head.Position
		local aimPoint = targetRoot.Position + Vector3.new(0, 1, 0)
		local direction = spreadDirection(aimPoint - head.Position, Bots.spread) * stats.range
		local result = workspace:Raycast(head.Position, direction, params)
		local surface: string? = nil
		if result then
			surface = "concrete"
			local vehicle = VehicleService.GetVehicle(result.Instance)
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			local victimHumanoid = model and model:FindFirstChildOfClass("Humanoid")
			if vehicle then
				VehicleService.Damage(
					vehicle,
					stats.damage * Bots.damageMultiplier,
					nil,
					result.Instance :: BasePart
				)
				surface = "metal"
			elseif model and victimHumanoid and Combatants.IsEnemy(card, Combatants.FromCharacter(model)) then
				local headshot = stats.headshotMultiplier ~= nil and isHeadPart(result.Instance)
				local damage = stats.damage * Bots.damageMultiplier
				if headshot then
					damage *= stats.headshotMultiplier
					if rules.headshotKills then
						damage = math.max(damage, 1000) -- SWAT: un tiro a la cabeza mata
					end
				end
				local toShield, toHealth =
					HealthService.Damage(victimHumanoid, damage, card, weaponName, headshot)
				surface = if toHealth > 0 then "flesh" else "shield"
				if toShield + toHealth <= 0 then
					surface = "shield"
				end
			end
		end
		local hitPosition = if result then result.Position else head.Position + direction
		shotFired:FireAllClients(from, hitPosition, result ~= nil, surface, weaponName)
	end

	-- Un golpe cuerpo a cuerpo al enemigo que tiene enfrente (por la espalda mata)
	local function hit(who: Instance, targetHumanoid: Humanoid, targetRoot: BasePart)
		local meleeStats = if melee then stats else Melee
		local toTarget = (targetRoot.Position - root.Position).Unit
		local backstab = targetRoot.CFrame.LookVector:Dot(toTarget) > 0.5
		local damage = if backstab
			then meleeStats.backstabDamage
			else meleeStats.damage * Bots.damageMultiplier
		local cause = if backstab then "Backstab" elseif melee and weaponName then weaponName else "Machete"
		local toShield, toHealth = HealthService.Damage(targetHumanoid, damage, card, cause)
		if toShield + toHealth <= 0 then
			return
		end
		ExplosionService.PlaySoundAt(meleeStats.sound and Sounds.melee[meleeStats.sound], targetRoot.Position)
		if
			meleeStats.knockback
			and meleeStats.knockback > 0
			and who:IsA("Player")
			and targetHumanoid.Health > 0
		then
			local push = Vector3.new(toTarget.X, 0, toTarget.Z).Unit * meleeStats.knockback
			knockbackRemote:FireClient(who, push + Vector3.yAxis * meleeStats.knockback * 0.5)
		end
	end

	local function alive(): boolean
		return active
			and card.Parent == Combatants.Cards
			and character.Parent ~= nil
			and root.Parent ~= nil
			and humanoid.Health > 0
	end

	while alive() do
		local now = os.clock()
		if humanoid.Sit then
			humanoid.Sit = false
			humanoid.Jump = true
		end

		-- Atorado (contra un muro o una esquina): salta y busca otro camino
		if (root.Position - lastPosition).Magnitude > 2 then
			lastPosition, stuckSince = root.Position, now
		elseif now - stuckSince > 1.5 and humanoid.MoveDirection.Magnitude > 0 then
			humanoid.Jump = true
			lastPath = 0
			stuckSince = now
		end

		local who, visible = findTarget()
		if who ~= target then
			target = who
			seenAt = if visible then now else math.huge
		elseif visible and seenAt == math.huge then
			seenAt = now
		elseif not visible then
			seenAt = math.huge
		end

		local targetCharacter, targetHumanoid, targetRoot
		if who then
			targetCharacter, targetHumanoid, targetRoot = aliveBody(who)
		end
		if who and targetCharacter and targetHumanoid and targetRoot then
			wanderGoal = nil
			local offset = targetRoot.Position - root.Position
			local distance = offset.Magnitude
			local meleeStats = if melee then stats else Melee
			if visible then
				face(targetRoot.Position)
				-- Muy cerca, cualquiera saca el machete
				if distance <= meleeStats.range and now - lastMelee >= meleeStats.cooldown then
					lastMelee = now
					hit(who, targetHumanoid, targetRoot)
				end
				if melee then
					humanoid:MoveTo(targetRoot.Position) -- a golpes: directo hacia ti
				else
					-- Con arma de fuego: se acerca, se aleja o se mueve de lado
					local preferred = Bots.preferredDistance
					local flat = Vector3.new(offset.X, 0, offset.Z).Unit
					if distance > preferred + 15 then
						walkTo(targetRoot.Position)
					elseif distance < preferred - 15 then
						humanoid:MoveTo(root.Position - flat * 8)
					else
						if now > strafeUntil then
							strafeSide = if math.random() < 0.5 then -1 else 1
							strafeUntil = now + 0.8 + math.random() * 1.2
						end
						local side = Vector3.new(-flat.Z, 0, flat.X) * strafeSide
						humanoid:MoveTo(root.Position + side * 8)
					end

					-- Dispara en ráfagas cortas, con una pausa al ver a alguien (reactionTime)
					local reloading = ammo <= 0
					if reloading and now - lastShot >= stats.reloadTime then
						ammo = stats.magazine
						reloading = false
					end
					if
						not reloading
						and now - seenAt >= Bots.reactionTime
						and now - lastShot >= 1 / stats.fireRate
					then
						if burstLeft <= 0 then
							if now - lastShot >= 0.5 then
								burstLeft = if stats.automatic then math.random(3, 6) else 1
							end
						end
						if burstLeft > 0 then
							burstLeft -= 1
							ammo -= 1
							lastShot = now
							shoot(targetRoot)
						end
					end
				end
			else
				stopFacing()
				walkTo(targetRoot.Position)
			end
		else
			-- Nadie a quien buscar: pasea entre los puntos de aparición
			stopFacing()
			if not wanderGoal or (wanderGoal - root.Position).Magnitude < 8 then
				local spawns = mapSpawns()
				wanderGoal = if #spawns > 0 then spawns[math.random(#spawns)].Position else nil
			end
			if wanderGoal then
				walkTo(wanderGoal)
			end
		end
		task.wait(THINK_EVERY)
	end
end

-- Hace aparecer a un bot (al empezar y cada vez que reaparece)
function spawnBot(card: Instance)
	if not active or card.Parent ~= Combatants.Cards then
		return
	end
	local character = buildBody(card)
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local spawn = pickSpawn(card)
	local at = if spawn then spawn.CFrame * CFrame.new(0, 4, 0) else CFrame.new(0, 20, 0)
	character:PivotTo(at)
	character.Parent = Combatants.Bodies
	pcall(root.SetNetworkOwner, root, nil) -- lo mueve el servidor, no un jugador
	Combatants.SetBotCharacter(card, character)
	HealthService.SetupCharacter(card, character)
	animate(character, humanoid)

	local weaponName = chooseWeapon()
	local template = weaponName and ServerStorage.Weapons:FindFirstChild(weaponName)
	if template then
		humanoid:EquipTool(template:Clone()) -- el arma en la mano
	end

	-- Protección breve al aparecer, como los jugadores
	character:SetAttribute("SpawnProtected", true)
	task.delay(Modes.Common.spawnProtection, function()
		character:SetAttribute("SpawnProtected", nil)
	end)

	task.spawn(function()
		think(card, character, humanoid, root)
		-- Murió (o se cayó del mapa): el cuerpo se queda un momento y reaparece
		task.wait(Players.RespawnTime)
		if character.Parent then
			character:Destroy()
		end
		if card.Parent == Combatants.Cards then
			Combatants.SetBotCharacter(card, nil)
			spawnBot(card)
		end
	end)
end

-- El equipo con menos gente (contando bots)
local function smallestTeam(): Team?
	local smallest, count = nil, math.huge
	for _, team in Teams:GetTeams() do
		local size = Combatants.CountInTeam(team)
		if size < count then
			smallest, count = team, size
		end
	end
	return smallest
end

local function addBot()
	-- Un nombre que no esté en uso
	local name
	for _, candidate in Bots.names do
		if not Combatants.Cards:FindFirstChild("[BOT] " .. candidate) then
			name = "[BOT] " .. candidate
			break
		end
	end
	name = name or `[BOT] {#Combatants.Bots() + 1}`
	local card = Instance.new("Folder")
	card.Name = name
	card:SetAttribute("Bot", true)
	if rules.teams then
		local team = smallestTeam()
		card:SetAttribute("Team", team and team.Name)
	end
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, stat in { "Bajas", "Muertes" } do
		local value = Instance.new("IntValue")
		value.Name = stat
		value.Parent = leaderstats
	end
	leaderstats.Parent = card
	card.Parent = Combatants.Cards
	task.spawn(spawnBot, card)
end

local function removeBot(card: Instance)
	local character = Combatants.Character(card)
	Combatants.SetBotCharacter(card, nil)
	card:Destroy()
	if character then
		character:Destroy()
	end
end

-- Quita un bot: del equipo con más gente, para que queden parejos
local function removeOneBot()
	local bots = Combatants.Bots()
	local best, bestSize = bots[1], -1
	for _, card in bots do
		local team = Combatants.TeamOf(card)
		local size = if team then Combatants.CountInTeam(team) else 0
		if size > bestSize then
			best, bestSize = card, size
		end
	end
	if best then
		removeBot(best)
	end
end

-- Cuántos bots hacen falta ahora: los que falten para llegar a Bots.fillTo
local function wanted(): number
	local humans = #Players:GetPlayers()
	if not active or not Bots.enabled or not rules.bots or humans == 0 then
		return 0
	end
	return math.max(0, Bots.fillTo - humans)
end

-- Pone o quita bots hasta tener los que hacen falta. MatchService la llama al empezar y
-- cuando alguien entra o sale a mitad de partida.
function BotService.Fill()
	local count = wanted()
	while #Combatants.Bots() > count do
		removeOneBot()
	end
	while #Combatants.Bots() < count do
		addBot()
	end
end

-- ¿Se pueden usar bots? (para decidir si una partida puede empezar con un solo jugador)
function BotService.Enabled(): boolean
	return Bots.enabled == true
end

-- Cuántos bots habría en una partida de un modo con bots
function BotService.CountFor(modeRules): number
	if not Bots.enabled or not modeRules.bots then
		return 0
	end
	return math.max(0, Bots.fillTo - #Players:GetPlayers())
end

function BotService.Begin(matchRules)
	rules = matchRules
	active = true
	BotService.Fill()
end

-- Al terminar la partida se van todos los bots
function BotService.Stop()
	active = false
	for _, card in Combatants.Bots() do
		removeBot(card)
	end
end

return BotService
