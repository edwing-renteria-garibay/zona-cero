-- Hacia dónde apunta cada soldado, arriba o abajo, para que todos lo vean inclinar el torso y
-- los brazos con el arma (ver el cliente: Controllers/AimPose).
--
-- Cada jugador manda su ángulo (RemoteEvent "AimPitch", unas 10 veces por segundo) y aquí se
-- guarda en el atributo "AimPitch" de su personaje, que llega solo a todos los clientes.
-- Los bots lo ponen ellos mismos al apuntar (BotService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local aimPitch = ReplicatedStorage.Remotes.AimPitch :: UnreliableRemoteEvent

local AimPose = {}

AimPose.MAX_PITCH = 80 -- grados, hacia arriba o hacia abajo

function AimPose.Start()
	aimPitch.OnServerEvent:Connect(function(player: Player, pitch: any)
		local character = player.Character
		if not character or type(pitch) ~= "number" or pitch ~= pitch then
			return -- pitch ~= pitch: NaN
		end
		-- Redondeado a grados: así el atributo no cambia por movimientos mínimos
		local degrees = math.round(math.clamp(pitch, -AimPose.MAX_PITCH, AimPose.MAX_PITCH))
		if character:GetAttribute("AimPitch") ~= degrees then
			character:SetAttribute("AimPitch", degrees)
		end
	end)
end

return AimPose
