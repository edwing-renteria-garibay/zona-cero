-- Quién pelea en la partida: los jugadores y los bots (ver BotService).
-- Un bot no es un Player de Roblox, así que cada bot tiene un "carnet": una carpeta en
-- ReplicatedStorage.Bots con su nombre, el atributo "Team" (nombre de su equipo) y su
-- propio leaderstats (Bajas y Muertes), igual que un jugador. Así el marcador, el registro
-- de bajas y la pantalla de resultados los tratan casi igual.
-- En el código, "quien" (who) puede ser un Player o el carnet de un bot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

export type Combatant = Instance -- un Player o el carnet (Folder) de un bot

local Combatants = {}

-- Carpeta con los carnets de los bots (el cliente la lee para el marcador)
local cards = Instance.new("Folder")
cards.Name = "Bots"
cards.Parent = ReplicatedStorage
Combatants.Cards = cards

-- Carpeta del mundo donde están los cuerpos de los bots
local bodies = Instance.new("Folder")
bodies.Name = "Bots"
bodies.Parent = workspace
Combatants.Bodies = bodies

-- El cuerpo actual de cada bot (cambia cada vez que reaparece)
local botCharacters: { [Instance]: Model? } = {}
-- De qué bot es cada cuerpo
local botOfCharacter: { [Model]: Instance } = {}

function Combatants.IsBot(who: Combatant?): boolean
	return who ~= nil and not who:IsA("Player")
end

-- Lo usa BotService al crear o quitar el cuerpo de un bot
function Combatants.SetBotCharacter(card: Instance, character: Model?)
	local old = botCharacters[card]
	if old then
		botOfCharacter[old] = nil
	end
	botCharacters[card] = character
	if character then
		botOfCharacter[character] = card
	end
end

-- El personaje de un jugador o el cuerpo de un bot
function Combatants.Character(who: Combatant): Model?
	if who:IsA("Player") then
		return who.Character
	end
	return botCharacters[who]
end

-- De quién es este personaje: un Player, el carnet de un bot o nil (un muñeco, un jeep...)
function Combatants.FromCharacter(model: Instance?): Combatant?
	if not model or not model:IsA("Model") then
		return nil
	end
	return Players:GetPlayerFromCharacter(model) or botOfCharacter[model]
end

-- Su equipo (nil si va por su cuenta, como en Asesino en solitario)
function Combatants.TeamOf(who: Combatant?): Team?
	if not who then
		return nil
	end
	if who:IsA("Player") then
		return if who.Neutral then nil else who.Team
	end
	local name = who:GetAttribute("Team")
	local team = name and Teams:FindFirstChild(name)
	return if team and team:IsA("Team") then team else nil
end

-- El color de su equipo (blanco sin equipo)
function Combatants.ColorOf(who: Combatant?): Color3
	local team = Combatants.TeamOf(who)
	return if team then team.TeamColor.Color else Color3.new(1, 1, 1)
end

-- ¿a puede dañar a b? (b nil = un muñeco de práctica: sí)
function Combatants.IsEnemy(a: Combatant, b: Combatant?): boolean
	if b == nil then
		return true
	end
	if a == b then
		return false
	end
	-- En Infección: zombis contra sobrevivientes
	local sideA, sideB = a:GetAttribute("Side"), b:GetAttribute("Side")
	if sideA and sideB then
		return sideA ~= sideB
	end
	local teamA, teamB = Combatants.TeamOf(a), Combatants.TeamOf(b)
	if not teamA or not teamB then
		return true
	end
	return teamA ~= teamB
end

-- Todos los bots que hay ahora (sus carnets)
function Combatants.Bots(): { Instance }
	return cards:GetChildren()
end

-- Todos los que pelean: jugadores y bots
function Combatants.All(): { Combatant }
	local all: { Combatant } = Players:GetPlayers()
	for _, card in cards:GetChildren() do
		table.insert(all, card)
	end
	return all
end

-- Cuántos hay en un equipo, contando bots
function Combatants.CountInTeam(team: Team): number
	local count = 0
	for _, who in Combatants.All() do
		if Combatants.TeamOf(who) == team then
			count += 1
		end
	end
	return count
end

return Combatants
