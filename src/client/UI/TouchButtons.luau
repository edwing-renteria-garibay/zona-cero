-- Los botones de la pantalla en celular y tablet, alrededor del botón de saltar de Roblox:
--
--              Cámara
--     Correr          Recargar
--          Apuntar
--   Granada
--            DISPARAR   (Saltar)
--   Golpe
--
-- Disparar hace lo mismo que el clic izquierdo: dispara el arma, la torreta del jeep, lanza
-- SimiOs o golpea (con el machete, el pollo o siendo zombi). Es un stick, como el de caminar:
-- al tocarlo dispara, y si empujas la bolita hacia un lado la mira gira hacia allá mientras
-- la sostengas, más rápido entre más la empujes (como el stick derecho de un control). Al
-- soltarlo la bolita regresa al centro. Apuntar solo sale con armas que tienen zoom
-- (francotirador). Correr se toca una vez para correr y otra para parar, así el pulgar
-- derecho queda libre para mirar.
--
-- Antes usábamos los botones automáticos de Roblox (el "true" de BindAction), pero salían
-- pequeños, con el texto cortado y uno encima de otro. Estos llaman a las mismas funciones
-- que las teclas (Controllers/Actions), así que hacen exactamente lo mismo.
-- (ContextActionService:CallFunction no funcionaba en el celular: los botones no hacían nada.)

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Movement = require(ReplicatedStorage.Shared.Config.Movement)
local Actions = require(script.Parent.Parent.Controllers.Actions)
local CameraController = require(script.Parent.Parent.Controllers.CameraController)
local GrenadeController = require(script.Parent.Parent.Controllers.GrenadeController)
local MeleeController = require(script.Parent.Parent.Controllers.MeleeController)
local Mobile = require(script.Parent.Parent.Controllers.Mobile)
local SpecialWeapons = require(script.Parent.Parent.Controllers.SpecialWeapons)
local VehicleController = require(script.Parent.Parent.Controllers.VehicleController)
local WeaponController = require(script.Parent.Parent.Controllers.WeaponController)

local player = Players.LocalPlayer

local BUTTON = Color3.fromRGB(20, 20, 20)
local FIRE = Color3.fromRGB(170, 40, 40)
local STICK_BASE = Color3.fromRGB(40, 40, 40) -- como el fondo del stick de caminar
local ACTIVE = Color3.fromRGB(230, 170, 50) -- Correr prendido / zoom puesto
local TEXT = Color3.new(1, 1, 1)
-- Stick de Disparar: grados por segundo que gira la mira con la bolita empujada hasta el borde
-- (a medio camino gira a la cuarta parte, para apuntar fino)
local LOOK_SPEED = 220
local DEAD_ZONE = 0.15 -- empujes menores que esto (de 0 a 1) no giran: así puedes disparar quieto
local KNOB_SIZE = 44

-- Dónde va cada botón: el centro, medido desde el centro del botón de saltar (que mide 70 en
-- celular), y su tamaño
local LAYOUT = {
	Fire = { x = -105, y = -15, size = 84 },
	Reload = { x = -15, y = -90, size = 56 },
	Aim = { x = -95, y = -100, size = 56 },
	Grenade = { x = -185, y = -65, size = 56 },
	Melee = { x = -190, y = 15, size = 56 },
	Sprint = { x = -165, y = -140, size = 52 },
	Camera = { x = -15, y = -165, size = 46 },
}

local TouchButtons = {}

local function makeButton(parent: Instance, key: string, text: string, color: Color3): TextButton
	local spot = LAYOUT[key]
	local button = Instance.new("TextButton")
	button.Name = key
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromOffset(spot.x, spot.y)
	button.Size = UDim2.fromOffset(spot.size, spot.size)
	button.BackgroundColor3 = color
	button.BackgroundTransparency = 0.35
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = TEXT
	button.TextScaled = true
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = TEXT
	stroke.Thickness = 2
	stroke.Transparency = 0.4
	stroke.Parent = button
	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(padding :: any)[side] = UDim.new(0, 7)
	end
	padding.Parent = button
	local textSize = Instance.new("UITextSizeConstraint")
	textSize.MaxTextSize = if key == "Fire" then 16 else 13
	textSize.Parent = button
	return button
end

-- Llama a onPress cuando el dedo toca el botón y a onRelease cuando lo suelta (aunque lo
-- suelte fuera del botón). onMove, si se da, recibe dónde está el dedo en la pantalla
local function onTouch(
	button: GuiButton,
	onPress: (InputObject) -> (),
	onRelease: ((InputObject) -> ())?,
	onMove: ((Vector2) -> ())?
)
	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local normal = button.BackgroundTransparency
		button.BackgroundTransparency = normal - 0.25 -- se ve apretado
		onPress(input)
		local moved
		if onMove then
			onMove(Vector2.new(input.Position.X, input.Position.Y))
			moved = input:GetPropertyChangedSignal("Position"):Connect(function()
				onMove(Vector2.new(input.Position.X, input.Position.Y))
			end)
		end
		local connection
		connection = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
			local state = input.UserInputState
			if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				connection:Disconnect()
				if moved then
					moved:Disconnect()
				end
				button.BackgroundTransparency = normal
				if onRelease then
					onRelease(input)
				end
			end
		end)
	end)
end

local function call(action: string, state: Enum.UserInputState, input: InputObject)
	Actions.Call(action, state, input)
end

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

function TouchButtons.Start()
	if not Mobile.IsTouch() then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "TouchButtons"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Todos los botones cuelgan de un punto en el centro del botón de saltar. Roblox lo pone
	-- en un lugar distinto (y más grande) en pantallas grandes, como las tablets
	local cluster = Instance.new("Frame")
	cluster.BackgroundTransparency = 1
	cluster.Size = UDim2.fromOffset(0, 0)
	cluster.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = cluster
	local function place()
		local size = gui.AbsoluteSize
		local small = math.min(size.X, size.Y) <= 500
		cluster.Position = if small then UDim2.new(1, -60, 1, -55) else UDim2.new(1, -110, 1, -150)
		scale.Scale = if small then 1 else 1.3
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()

	-- Disparar: lo mismo que el clic izquierdo, según lo que tengas en la mano. Es un stick:
	-- el círculo de fondo (fire) y la bolita que sigue al dedo (knob), con el mismo diseño que
	-- el stick de caminar de Roblox: fondo oscuro transparente y bolita más oscura
	local fire = makeButton(cluster, "Fire", "", STICK_BASE)
	fire.BackgroundTransparency = 0.5
	local knob = Instance.new("TextLabel")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0.5, 0.5)
	knob.Size = UDim2.fromOffset(KNOB_SIZE, KNOB_SIZE)
	knob.BackgroundColor3 = FIRE
	knob.BackgroundTransparency = 0.25
	knob.Font = Enum.Font.GothamBold
	knob.Text = "Disparar"
	knob.TextColor3 = TEXT
	knob.TextScaled = true
	knob.Parent = fire
	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(0.5, 0)
	knobCorner.Parent = knob
	local knobPadding = Instance.new("UIPadding")
	knobPadding.PaddingLeft = UDim.new(0, 4)
	knobPadding.PaddingRight = UDim.new(0, 4)
	knobPadding.Parent = knob
	local knobText = Instance.new("UITextSizeConstraint")
	knobText.MaxTextSize = 11
	knobText.Parent = knob
	-- Qué tanto está empujada la bolita: de (0, 0) en el centro a largo 1 en el borde
	local stick = Vector2.zero
	-- Donde pusiste el dedo: el empujón se mide desde ahí, así tocar cerca del borde no gira
	-- la mira de golpe
	local origin: Vector2? = nil
	local firing: string? = nil
	onTouch(fire, function(input)
		if VehicleController.IsInTurret() then
			firing = "turret"
			VehicleController.SetTrigger(true)
		elseif GrenadeController.FireThrows() then
			firing = "grenade"
			call("GrenadeFire", Enum.UserInputState.Begin, input)
		elseif MeleeController.ClickMelees() then
			firing = "melee"
			call("ClickMelee", Enum.UserInputState.Begin, input)
		else
			firing = "weapon"
			WeaponController.SetTrigger(true)
		end
	end, function(input)
		if firing == "turret" then
			VehicleController.SetTrigger(false)
		elseif firing == "grenade" then
			call("GrenadeFire", Enum.UserInputState.End, input)
		elseif firing == "weapon" then
			WeaponController.SetTrigger(false)
		end
		firing = nil
		stick = Vector2.zero
		origin = nil
		knob.Position = UDim2.fromScale(0.5, 0.5) -- la bolita regresa al centro
	end, function(position)
		-- La bolita sigue al dedo sin salirse del círculo
		local radius = fire.AbsoluteSize.X / 2
		origin = origin or position
		local offset = position - (origin :: Vector2)
		if offset.Magnitude > radius then
			offset = offset.Unit * radius
		end
		stick = offset / radius
		-- AbsoluteSize ya trae el UIScale (tablets): la posición de la bolita va sin él
		local knobOffset = offset / scale.Scale
		knob.Position = UDim2.new(0.5, knobOffset.X, 0.5, knobOffset.Y)
	end)

	local reload = makeButton(cluster, "Reload", "Recargar", BUTTON)
	onTouch(reload, function(input)
		call("Reload", Enum.UserInputState.Begin, input)
	end)

	local aim = makeButton(cluster, "Aim", "Apuntar", BUTTON)
	onTouch(aim, function(input)
		call("Scope", Enum.UserInputState.Begin, input)
	end)

	-- Granada: mantén para ver a dónde cae y suelta para lanzarla. Siendo zombi es la pócima
	local grenade = makeButton(cluster, "Grenade", "Granada", BUTTON)
	local grenadeAction = "Grenade"
	onTouch(grenade, function(input)
		grenadeAction = if Actions.IsBound("ZombieBoost") then "ZombieBoost" else "Grenade"
		call(grenadeAction, Enum.UserInputState.Begin, input)
	end, function(input)
		call(grenadeAction, Enum.UserInputState.End, input)
	end)

	local melee = makeButton(cluster, "Melee", "Golpe", BUTTON)
	onTouch(melee, function(input)
		call("Melee", Enum.UserInputState.Begin, input)
	end)

	-- Correr: un toque prende, otro apaga
	local sprint = makeButton(cluster, "Sprint", "Correr", BUTTON)
	local function sprinting(): boolean
		local h = humanoid()
		return h ~= nil and h.WalkSpeed == Movement.sprintSpeed
	end
	onTouch(sprint, function(input)
		call("Sprint", if sprinting() then Enum.UserInputState.End else Enum.UserInputState.Begin, input)
	end)

	local camera = makeButton(cluster, "Camera", "Cámara", BUTTON)
	onTouch(camera, function(input)
		call("ToggleCamera", Enum.UserInputState.Begin, input)
	end)

	RunService.RenderStepped:Connect(function(dt)
		-- Stick de Disparar empujado: la mira gira mientras lo sostengas. Con zoom, más despacio
		local push = stick.Magnitude
		if push > DEAD_ZONE then
			local strength = ((push - DEAD_ZONE) / (1 - DEAD_ZONE)) ^ 2
			local direction = stick.Unit * strength
			local speed = LOOK_SPEED * dt * workspace.CurrentCamera.FieldOfView / 70
			CameraController.Look(direction.X * speed, -direction.Y * speed)
		end

		-- Con un menú abierto (tienda, menú de partidas) o muerto, los botones se esconden
		local h = humanoid()
		cluster.Visible = not player:GetAttribute("MenuOpen") and h ~= nil and h.Health > 0
		if not cluster.Visible then
			if firing then
				-- Se abrió un menú con el dedo en el gatillo: se suelta
				WeaponController.SetTrigger(false)
				VehicleController.SetTrigger(false)
				firing = nil
			end
			stick = Vector2.zero
			origin = nil
			knob.Position = UDim2.fromScale(0.5, 0.5)
			return
		end

		local tool, stats = WeaponController.GetEquipped()
		aim.Visible = tool ~= nil and stats.zoom ~= nil
		aim.TextColor3 = if SpecialWeapons.IsScoped() then ACTIVE else TEXT
		sprint.TextColor3 = if sprinting() then ACTIVE else TEXT

		local info = ContextActionService:GetBoundActionInfo("Grenade")
		grenade.Text = if player:GetAttribute("Side") == "Zombie"
			then "Pócima"
			else (info and info.title) or "Granada"
	end)
end

return TouchButtons
