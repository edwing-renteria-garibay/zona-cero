-- Las armas largas (rifle, escopeta, francotirador, lanzacohetes, láser...) se agarran con
-- las dos manos. Roblox solo pone la herramienta en la mano derecha, así que la mano
-- izquierda se lleva a la agarradera de enfrente con un IKControl ("cinemática inversa":
-- Roblox dobla el hombro y el codo solo para que la mano llegue a un punto).
--
-- El punto es el Attachment "LeftHandGrip" que WeaponModels.Dress pone en las armas de dos
-- manos (las de una mano, como la pistola, el arma de hielo o el machete, no lo tienen).
-- El IKControl vive en el Humanoid y se replica, así que todos ven al soldado con las dos
-- manos en el arma.
-- En primera persona no se nota: ahí se ven los brazos de ViewModel.

local TwoHands = {}

local IK_NAME = "LeftHandIK"

local function release(humanoid: Humanoid)
	local ik = humanoid:FindFirstChild(IK_NAME)
	if ik then
		ik:Destroy()
	end
end

local function grab(character: Model, humanoid: Humanoid, tool: Tool)
	release(humanoid)
	local handle = tool:FindFirstChild("Handle")
	local grip = handle and handle:FindFirstChild("LeftHandGrip")
	local upperArm = character:FindFirstChild("LeftUpperArm")
	local hand = character:FindFirstChild("LeftHand")
	if not grip or not upperArm or not hand then
		return -- arma de una mano, o un cuerpo R6
	end
	local ik = Instance.new("IKControl")
	ik.Name = IK_NAME
	ik.Type = Enum.IKControlType.Position
	ik.ChainRoot = upperArm
	ik.EndEffector = hand
	ik.Target = grip
	ik.SmoothTime = 0.05
	ik.Parent = humanoid
end

function TwoHands.SetupCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			grab(character, humanoid, child)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and not character:FindFirstChildOfClass("Tool") then
			release(humanoid)
		end
	end)
	-- Al morir, el brazo cae suelto (ver DeathAnimation)
	humanoid.Died:Connect(function()
		release(humanoid)
	end)
	local tool = character:FindFirstChildOfClass("Tool")
	if tool then
		grab(character, humanoid, tool)
	end
end

return TwoHands
