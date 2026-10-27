-- Golpe cuerpo a cuerpo: tecla F en PC, R3 en control, botón "Golpe" en móvil.
-- El clic también golpea cuando no llevas un arma de fuego en la mano: con las manos vacías,
-- con un arma de golpe (machete, pollo de hule) o siendo zombi en Infección.
-- El cliente solo avisa; el servidor busca a quién golpear y aplica el daño.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Melee = require(ReplicatedStorage.Shared.Config.Melee)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local ViewModel = require(script.Parent.ViewModel)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local meleeRemote = remotes:WaitForChild("Melee") :: RemoteEvent
local knockbackRemote = remotes:WaitForChild("Knockback") :: RemoteEvent

local player = Players.LocalPlayer

local MeleeController = {}

local lastMelee = 0

-- El arma que llevas en la mano (nil si no llevas ninguna)
local function equippedTool(): Tool?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Tool")
end

-- Los valores del golpe: los del arma de golpe en la mano, o los del golpe normal
local function currentStats()
	local tool = equippedTool()
	return tool and Melee.weapons[tool.Name] or Melee
end

local function onAction(_name: string, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local now = os.clock()
	if now - lastMelee >= currentStats().cooldown then
		lastMelee = now
		meleeRemote:FireServer()
		ViewModel.Bash() -- en primera persona, el arma golpea hacia el frente
	end
	return Enum.ContextActionResult.Sink
end

-- ¿El clic debe golpear? Sí, salvo que lleves un arma de fuego en la mano o vayas sentado
-- (en la torreta del jeep el clic dispara la torreta, y en el jeep no se puede golpear)
local function clickMelees(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.SeatPart then
		return false
	end
	if player:GetAttribute("Side") == "Zombie" then
		return true
	end
	local tool = equippedTool()
	return not tool or not Weapons[tool.Name]
end

local clickBound = false

-- ¿El clic (o el botón "Disparar" en celular) golpea ahora mismo?
function MeleeController.ClickMelees(): boolean
	return clickBound
end

local function updateClick()
	local wanted = clickMelees()
	if wanted == clickBound then
		return
	end
	clickBound = wanted
	if wanted then
		ContextActionService:BindAction("ClickMelee", onAction, false, Enum.UserInputType.MouseButton1)
	else
		ContextActionService:UnbindAction("ClickMelee")
	end
end

-- Te pegaron con algo que avienta (el pollo de hule): tu personaje lo mueves tú, así que
-- el servidor te pide que salgas volando. Saltar primero evita que el suelo frene el empujón.
local function onKnockback(push: Vector3)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.SeatPart then
		return
	end
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	root.AssemblyLinearVelocity = push
end

function MeleeController.Start()
	-- En control: R3 (apretar el stick derecho), como en muchos shooters. El botón de móvil
	-- es de UI/TouchButtons (por eso el "false")
	ContextActionService:BindAction("Melee", onAction, false, Enum.KeyCode.F, Enum.KeyCode.ButtonR3)
	ContextActionService:SetTitle("Melee", "Golpe")

	-- Revisa el clic al cambiar de arma, al reaparecer, al sentarse o pararse y al volverse zombi
	local function watchCharacter(character: Model)
		character.ChildAdded:Connect(updateClick)
		character.ChildRemoved:Connect(updateClick)
		updateClick()
		task.spawn(function()
			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			humanoid.Seated:Connect(function()
				task.defer(updateClick)
			end)
		end)
	end
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
	player:GetAttributeChangedSignal("Side"):Connect(updateClick)
	updateClick()

	knockbackRemote.OnClientEvent:Connect(onKnockback)
end

return MeleeController
