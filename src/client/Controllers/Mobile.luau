-- Lo que cambia en celular y tablet (pantalla táctil sin mouse): la mira va en el centro de la
-- pantalla, hay botones propios para disparar, apuntar, etc. (UI/TouchButtons) y los menús se
-- acomodan a una pantalla más pequeña.

local UserInputService = game:GetService("UserInputService")

local Mobile = {}

-- ¿Se juega con el dedo? (celular o tablet; una laptop con pantalla táctil tiene mouse)
function Mobile.IsTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

-- Encoge un panel (con un UIScale) si no cabe en la pantalla. width y height son su tamaño
-- normal; deja un margen de 12 alrededor. Se vuelve a calcular si la pantalla gira.
function Mobile.FitToScreen(panel: GuiObject, width: number, height: number)
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local function update()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		-- La barra de arriba de Roblox ocupa unos 58 de alto
		local screen = camera.ViewportSize - Vector2.new(24, 24 + 58)
		scale.Scale = math.min(1, screen.X / width, screen.Y / height)
	end
	update()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
end

return Mobile
