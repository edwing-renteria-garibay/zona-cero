-- Banderas del modo Captura la bandera.
--
-- Cada mapa pone una base de bandera por equipo (una pieza "FlagStand" con el atributo Team),
-- en una esquina de su base. Las reglas:
--   * Si tocas la bandera enemiga, la tomas y la llevas en la espalda.
--   * Si llegas con ella a TU base mientras tu bandera está en casa, capturas: +1 punto.
--   * Si mueres llevándola, cae al suelo. Si un compañero del dueño la toca, vuelve a su
--     base; si un enemigo la toca, la vuelve a tomar. Sola vuelve a los returnTime segundos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")

local Modes = require(ReplicatedStorage.Shared.Config.Modes)

local killFeed = ReplicatedStorage.Remotes.KillFeed :: RemoteEvent

local rules = Modes.CaptureTheFlag
local POLE_HEIGHT = 9
local CHECK_INTERVAL = 0.1 -- segundos entre revisiones

type Flag = {
	team: Team,
	stand: BasePart,
	model: Model,
	pole: BasePart,
	state: "home" | "carried" | "dropped",
	carrier: Player?,
	weld: WeldConstraint?,
	droppedAt: number,
	lastPosition: Vector3,
}

local FlagService = {}

local flags: { Flag } = {}
local folder: Folder? = nil
local active = false
local onCapture: ((Player, Team) -> ())? = nil

-- Un aviso en el registro de bajas, del color de un equipo
local function announce(text: string, team: Team?)
	killFeed:FireAllClients({
		message = text,
		color = if team then team.TeamColor.Color else Color3.new(1, 1, 1),
	})
end

-- El modelo: un asta de metal, una tela del color del equipo y una bola arriba.
-- El asta es la pieza principal; las demás van soldadas a ella.
local function buildModel(team: Team): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "Flag" .. team.Name

	local function part(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = offset
		p.Color = color
		p.Material = material
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true -- no pesa: quien la lleva corre igual
		p.Parent = model
		return p
	end
	local metal = Color3.fromRGB(70, 70, 75)
	local pole = part("Pole", Vector3.new(0.35, POLE_HEIGHT, 0.35), CFrame.new(), metal, Enum.Material.Metal)
	local top = POLE_HEIGHT / 2
	local cloth = part(
		"Cloth",
		Vector3.new(0.15, 2.6, 4),
		CFrame.new(0, top - 1.6, 2.1),
		team.TeamColor.Color,
		Enum.Material.Fabric
	)
	local knob =
		part("Knob", Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, top + 0.3, 0), metal, Enum.Material.Metal)
	knob.Shape = Enum.PartType.Ball
	for _, piece in { cloth, knob } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = pole
		weld.Part1 = piece
		weld.Parent = piece
	end
	model.PrimaryPart = pole
	return model, pole
end

local function dropWeld(flag: Flag)
	if flag.weld then
		flag.weld:Destroy()
		flag.weld = nil
	end
end

-- Para la bandera fija y derecha, con la punta del asta en position (a ras de suelo)
local function standAt(flag: Flag, position: Vector3)
	dropWeld(flag)
	flag.pole.Anchored = true
	-- La tela ondea hacia el centro del mapa, así no se mete en las paredes de la esquina
	local center = position + Vector3.new(0, POLE_HEIGHT / 2, 0)
	local toCenter = Vector3.new(-position.X, 0, -position.Z)
	if toCenter.Magnitude > 0.1 then
		flag.model:PivotTo(CFrame.lookAt(center, center - toCenter))
	else
		flag.model:PivotTo(CFrame.new(center))
	end
	flag.lastPosition = position
end

local function returnHome(flag: Flag)
	flag.state = "home"
	flag.carrier = nil
	standAt(flag, flag.stand.Position + Vector3.new(0, flag.stand.Size.Y / 2, 0))
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function isCarrying(player: Player): boolean
	for _, flag in flags do
		if flag.carrier == player then
			return true
		end
	end
	return false
end

local function flagOf(team: Team?): Flag?
	for _, flag in flags do
		if flag.team == team then
			return flag
		end
	end
	return nil
end

local function pickUp(flag: Flag, player: Player)
	local character = player.Character :: Model
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	if not torso then
		return
	end
	flag.state = "carried"
	flag.carrier = player
	dropWeld(flag)
	-- En la espalda, un poco inclinada hacia atrás
	flag.model:PivotTo(torso.CFrame * CFrame.new(0, 1.5, 0.9) * CFrame.Angles(math.rad(-15), 0, 0))
	flag.pole.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = flag.pole
	weld.Parent = flag.pole
	flag.weld = weld
	announce(string.format("%s tomó la bandera %s", player.Name, flag.team.Name), player.Team)
end

-- Suelta la bandera donde está quien la llevaba, sobre el piso
local function drop(flag: Flag)
	local carrier = flag.carrier
	flag.state = "dropped"
	flag.carrier = nil
	flag.droppedAt = os.clock()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { flag.model }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local from = flag.lastPosition + Vector3.new(0, 2, 0)
	local hit = workspace:Raycast(from, Vector3.new(0, -50, 0), params)
	standAt(flag, if hit then hit.Position else flag.lastPosition)
	if carrier then
		announce(string.format("%s soltó la bandera %s", carrier.Name, flag.team.Name), carrier.Team)
	end
end

local function capture(flag: Flag, player: Player)
	announce(string.format("¡%s capturó la bandera %s!", player.Name, flag.team.Name), player.Team)
	returnHome(flag)
	if onCapture and player.Team then
		onCapture(player, player.Team)
	end
end

local function update()
	for _, flag in flags do
		if flag.state == "carried" then
			local carrier = flag.carrier :: Player
			local root = if carrier.Parent then getRoot(carrier) else nil
			if not root then
				drop(flag) -- murió o salió del juego
				continue
			end
			flag.lastPosition = root.Position - Vector3.new(0, 3, 0)
			-- Captura: llegar a tu propia base con tu bandera en casa
			local own = flagOf(carrier.Team)
			if own and own.state == "home" then
				local standTop = own.stand.Position + Vector3.new(0, own.stand.Size.Y / 2, 0)
				if (root.Position - standTop).Magnitude < rules.captureRadius then
					capture(flag, carrier)
				end
			end
		else
			if flag.state == "dropped" and os.clock() - flag.droppedAt > rules.flagReturnTime then
				returnHome(flag)
				announce(string.format("La bandera %s volvió a su base", flag.team.Name), flag.team)
				continue
			end
			for _, player in Players:GetPlayers() do
				local root = getRoot(player)
				if not root or not player.Team then
					continue
				end
				local reach = (root.Position - (flag.lastPosition + Vector3.new(0, 3, 0))).Magnitude
				if reach > rules.pickupRadius then
					continue
				end
				if player.Team ~= flag.team then
					if not isCarrying(player) then
						pickUp(flag, player)
						break
					end
				elseif flag.state == "dropped" then
					returnHome(flag)
					announce(
						string.format("%s regresó la bandera %s", player.Name, flag.team.Name),
						player.Team
					)
					break
				end
			end
		end
	end
end

-- Busca las bases de bandera del mapa y prepara una bandera por cada una
function FlagService.Setup(map: Instance)
	for _, stand in map:GetDescendants() do
		local team = stand:IsA("BasePart") and Teams:FindFirstChild(stand:GetAttribute("Team") or "")
		if team and stand.Name == "FlagStand" then
			local model, pole = buildModel(team :: Team)
			table.insert(flags, {
				team = team :: Team,
				stand = stand :: BasePart,
				model = model,
				pole = pole,
				state = "home",
				carrier = nil,
				weld = nil,
				droppedAt = 0,
				lastPosition = Vector3.zero,
			})
		end
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if active and elapsed >= CHECK_INTERVAL then
			elapsed = 0
			update()
		end
	end)
end

-- ¿El mapa tiene base de bandera para cada equipo?
function FlagService.HasFlags(): boolean
	return #flags >= 2
end

-- Pone las banderas en su base y empieza a revisar. capture se llama en cada captura.
function FlagService.Begin(capture: (Player, Team) -> ())
	onCapture = capture
	if not folder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = "Flags"
		newFolder.Parent = workspace
		folder = newFolder
	end
	for _, flag in flags do
		returnHome(flag)
		flag.model.Parent = folder
	end
	active = true
end

-- Quita las banderas al terminar la partida
function FlagService.Stop()
	active = false
	for _, flag in flags do
		dropWeld(flag)
		flag.carrier = nil
		flag.model.Parent = nil
	end
end

return FlagService
