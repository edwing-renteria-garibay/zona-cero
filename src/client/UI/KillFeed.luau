-- Registro de bajas arriba a la derecha: "Jugador1 [Pistola · cabeza] Jugador2".
-- Cada línea se borra sola a los pocos segundos; se muestran como máximo MAX_LINES.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local killFeed = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("KillFeed") :: RemoteEvent

local player = Players.LocalPlayer

local MAX_LINES = 5
local LINE_TIME = 6 -- segundos que se ve cada línea

-- Nombre en español de cada causa de muerte
local CAUSES = {
	AssaultRifle = "Rifle",
	Pistol = "Pistola",
	RocketLauncher = "Cohete",
	Turret = "Torreta",
	Melee = "Golpe",
	Backstab = "Por la espalda",
	rocket = "Cohete",
	grenade = "Granada",
	jeep = "Explosión del jeep",
}

local KillFeed = {}

-- Convierte un Color3 al formato que entiende RichText: #RRGGBB
local function hex(color: Color3): string
	return "#" .. color:ToHex()
end

-- Quita los caracteres especiales de RichText para que un nombre no rompa el formato
local function escape(text: string): string
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function KillFeed.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "KillFeed"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local list = Instance.new("Frame")
	list.AnchorPoint = Vector2.new(1, 0)
	list.Position = UDim2.new(1, -12, 0, 12)
	list.Size = UDim2.fromOffset(380, 200)
	list.BackgroundTransparency = 1
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = list

	local count = 0
	killFeed.OnClientEvent:Connect(function(entry)
		local cause = CAUSES[entry.cause or ""] or "Caída"
		if entry.headshot then
			cause ..= " · cabeza"
		end
		local victim =
			string.format('<font color="%s">%s</font>', hex(entry.victimColor), escape(entry.victim))
		local text
		if entry.killer then
			local killer =
				string.format('<font color="%s">%s</font>', hex(entry.killerColor), escape(entry.killer))
			text = string.format("%s  [%s]  %s", killer, cause, victim)
		elseif entry.suicide then
			text = string.format("%s  [%s]  se eliminó solo", victim, cause)
		else
			text = string.format("%s  murió", victim)
		end

		count += 1
		local line = Instance.new("TextLabel")
		line.LayoutOrder = -count -- la más nueva arriba
		line.Size = UDim2.fromOffset(380, 22)
		line.BackgroundColor3 = Color3.new(0, 0, 0)
		line.BackgroundTransparency = 0.5
		line.BorderSizePixel = 0
		line.RichText = true
		line.Font = Enum.Font.GothamBold
		line.TextSize = 15
		line.TextColor3 = Color3.new(1, 1, 1)
		line.TextXAlignment = Enum.TextXAlignment.Right
		line.Text = text .. " "
		line.Parent = list

		-- Si hay demasiadas, se borra la más vieja
		local lines = {}
		for _, child in list:GetChildren() do
			if child:IsA("TextLabel") then
				table.insert(lines, child)
			end
		end
		table.sort(lines, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for i = MAX_LINES + 1, #lines do
			lines[i]:Destroy()
		end

		task.delay(LINE_TIME - 0.5, function()
			if line.Parent then
				local fade = TweenInfo.new(0.5)
				TweenService:Create(line, fade, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			end
		end)
		Debris:AddItem(line, LINE_TIME)
	end)
end

return KillFeed
