-- Punto de entrada del cliente. Por ahora muestra en la salida (Output) el estado de la partida.
-- Aquí irán el HUD, la cámara y los controles.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local matchState = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MatchState") :: RemoteEvent

matchState.OnClientEvent:Connect(function(state, data)
	print("[Partida]", state, data)
end)
