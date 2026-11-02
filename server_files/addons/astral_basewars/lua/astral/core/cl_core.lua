-- Astral BaseWars — partie client du socle.

Astral.Pongs = Astral.Pongs or 0

-- Astral.Ping() : demande au serveur de répondre (test de santé). Le résultat arrive dans Astral.LastPong.
function Astral.Ping()
	net.Start("Astral.Ping")
	net.SendToServer()
end

net.Receive("Astral.Pong", function()
	Astral.Pongs = Astral.Pongs + 1
	Astral.LastPong = { version = net.ReadString(), accepted = net.ReadUInt(32), time = CurTime() }
end)

-- Réglages d'équilibrage modifiés en jeu (sv_settings.lua) : même application que côté serveur
net.Receive("Astral.Settings.Sync", function()
	for path, value in pairs(net.ReadTable()) do
		local id = isstring(path) and path:match("^Resources%.([%w_]+)%.value$")
		if id then
			local r = Astral.Resources and Astral.Resources.Get(id)
			if r and isnumber(value) then r.value = value end
		elseif isstring(path) and isnumber(value) then
			Astral.SetCfg(path, value)
		end
	end
end)
