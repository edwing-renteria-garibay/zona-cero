-- Cámara: primera persona por defecto y tercera persona "sobre el hombro" con la tecla V
-- (Y en mando, botón "Cámara" en móvil).
--
-- En las dos vistas el mouse queda fijo en el centro de la pantalla: la mira está ahí
-- y Aim.GetTarget() apunta a donde mira la cámara. En tercera persona el personaje
-- gira para mirar hacia donde mira la cámara, como en Halo.
--
-- La bandera que llevas en la espalda (Captura la bandera) no está dentro de tu personaje,
-- así que Roblox no la esconde en primera persona y te tapa la vista: aquí se esconde solo
-- para ti (LocalTransparencyModifier) en primera persona, y en tercera se ve a medias.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Actions = require(script.Parent.Actions)

local player = Players.LocalPlayer

local THIRD_PERSON_DISTANCE = 10 -- studs de la cámara al personaje
local SHOULDER_OFFSET = Vector3.new(2, 0.5, 0) -- la cámara un poco a la derecha y arriba

local CameraController = {}

local firstPerson = true
local recoil = 0 -- grados que la mira debe estar levantada por el retroceso; baja sola
local recoilApplied = 0 -- grados que ya se le sumaron a la cámara

local lookYaw = 0 -- grados que falta girar la cámara a los lados (botón Disparar en celular)
local lookPitch = 0 -- y hacia arriba o abajo
local MAX_PITCH = 80 -- no se puede mirar más arriba ni más abajo que esto

-- Gira la cámara unos grados, como al arrastrar el dedo por la pantalla. Lo usa el botón
-- "Disparar" en celular (UI/TouchButtons), para apuntar mientras disparas.
-- yaw > 0 gira a la derecha; pitch > 0 mira hacia arriba
function CameraController.Look(yaw: number, pitch: number)
	lookYaw += yaw
	lookPitch += pitch
end

-- Retroceso: levanta la mira unos grados (WeaponController lo llama al disparar)
function CameraController.Kick(degrees: number)
	recoil += degrees
end

function CameraController.IsFirstPerson(): boolean
	return firstPerson
end

local function getHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- ¿Esta bandera va soldada a tu personaje? (FlagService la suelda a tu torso al tomarla)
local function isMine(flag: Instance, character: Model): boolean
	local pole = flag:FindFirstChild("Pole")
	for _, weld in if pole then pole:GetChildren() else {} do
		if weld:IsA("WeldConstraint") and weld.Part0 and weld.Part0:IsDescendantOf(character) then
			return true
		end
	end
	return false
end

local function hideCarriedFlag()
	local flags = workspace:FindFirstChild("Flags")
	local character = player.Character
	if not flags or not character then
		return
	end
	for _, flag in flags:GetChildren() do
		-- En tercera persona se ve a medias, para que no estorbe a la cámara de atrás
		local hidden = if not isMine(flag, character) then 0 elseif firstPerson then 1 else 0.6
		for _, part in flag:GetDescendants() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = hidden
			end
		end
	end
end

local function apply()
	local humanoid = getHumanoid()
	if firstPerson then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 0.5
		if humanoid then
			humanoid.CameraOffset = Vector3.zero
			humanoid.AutoRotate = true
		end
	else
		player.CameraMode = Enum.CameraMode.Classic
		-- Mínimo y máximo iguales: la distancia queda fija (la rueda del mouse no la cambia).
		-- Primero el máximo, para que el mínimo nunca quede por encima de él
		player.CameraMaxZoomDistance = THIRD_PERSON_DISTANCE
		player.CameraMinZoomDistance = THIRD_PERSON_DISTANCE
		if humanoid then
			humanoid.CameraOffset = SHOULDER_OFFSET
		end
	end
end

local function onToggle(_name: string, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	firstPerson = not firstPerson
	apply()
	return Enum.ContextActionResult.Sink
end

function CameraController.Start()
	Actions.Bind("ToggleCamera", onToggle, false, Enum.KeyCode.V, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("ToggleCamera", "Cámara")

	-- Al reaparecer, el personaje es nuevo: se vuelve a aplicar la vista elegida
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		apply()
	end)
	apply()

	-- Después de la cámara de Roblox, en cada fotograma
	RunService:BindToRenderStep("ZonaCeroCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		-- Retroceso: la cámara de Roblox sigue desde donde quedó, así que solo se le suma la
		-- diferencia de cada fotograma. Primero sube de golpe y luego baja poco a poco.
		recoil = if recoil > 0.01 then recoil * math.exp(-8 * dt) else 0
		local delta = recoil - recoilApplied
		if math.abs(delta) > 0.0001 then
			local camera = workspace.CurrentCamera
			camera.CFrame *= CFrame.Angles(math.rad(delta), 0, 0)
			recoilApplied = recoil
		end
		-- Giro pedido con CameraController.Look: a los lados alrededor del eje vertical, y
		-- arriba o abajo sin pasarse de MAX_PITCH
		if lookYaw ~= 0 or lookPitch ~= 0 then
			local camera = workspace.CurrentCamera
			local current = math.deg(math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1)))
			local pitch = math.clamp(current + lookPitch, -MAX_PITCH, MAX_PITCH) - current
			local position = camera.CFrame.Position
			local rotation = camera.CFrame - position
			camera.CFrame = CFrame.new(position)
				* CFrame.Angles(0, math.rad(-lookYaw), 0)
				* rotation
				* CFrame.Angles(math.rad(pitch), 0, 0)
			lookYaw = 0
			lookPitch = 0
		end
		hideCarriedFlag()
		if firstPerson then
			return -- en primera persona Roblox ya fija el mouse y gira al personaje
		end
		-- Mouse fijo en el centro (en móvil no hay mouse y no hace falta), menos con un menú
		-- abierto como la tienda
		if UserInputService.MouseEnabled then
			UserInputService.MouseBehavior = if player:GetAttribute("MenuOpen")
				then Enum.MouseBehavior.Default
				else Enum.MouseBehavior.LockCenter
		end
		local humanoid = getHumanoid()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoid or not root or humanoid.Health <= 0 then
			return
		end
		-- Sentado en el jeep el asiento manda; a pie, el personaje mira hacia donde mira la cámara
		if humanoid.SeatPart then
			humanoid.AutoRotate = true
			return
		end
		humanoid.AutoRotate = false
		local look = workspace.CurrentCamera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
	end)
end

return CameraController
