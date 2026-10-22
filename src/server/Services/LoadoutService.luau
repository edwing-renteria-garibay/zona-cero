-- Las armas con las que aparece cada jugador. Salen de ServerStorage.Weapons según el modo:
-- la lista loadout del modo, o Modes.Common.loadout si el modo no dice otra cosa.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPack = game:GetService("StarterPack")

local Modes = require(ReplicatedStorage.Shared.Config.Modes)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Rules = require(script.Parent.Rules)

local LoadoutService = {}

-- Las armas ya no van en StarterPack. Si un lugar de Studio guardado con una versión vieja
-- todavía las tiene ahí, se quitan para que nadie aparezca con armas repetidas.
function LoadoutService.Start()
	for _, tool in StarterPack:GetChildren() do
		if tool:IsA("Tool") then
			tool:Destroy()
		end
	end
end

function LoadoutService.SetupCharacter(player: Player)
	local rules = Rules.current
	-- La mochila se crea de nuevo en cada aparición: se espera un momento a que esté lista
	task.wait()
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	-- Los zombis de Infección no llevan armas
	local loadout = if player:GetAttribute("Side") == "Zombie"
		then {}
		else rules.loadout or Modes.Common.loadout
	for _, name in loadout do
		local template = ServerStorage.Weapons:FindFirstChild(name)
		if not template then
			warn("[Loadout] No existe el arma", name)
			continue
		end
		local tool = template:Clone()
		local stats = Weapons[name]
		if rules.infiniteAmmo and stats then
			-- Un arma con cargador pero sin "Reserve" tiene repuesto infinito
			tool:SetAttribute("Ammo", stats.magazine)
		end
		tool.Parent = backpack
	end
end

return LoadoutService
