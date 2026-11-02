-- Astral UI — lignes de chat colorées envoyées par le serveur (astral/social/sv_commands.lua : !roll, !me, !donner…).

net.Receive("Astral.ChatLine", function()
	local parts = net.ReadTable()
	for i, v in ipairs(parts) do
		if istable(v) and v.r then parts[i] = Color(v.r, v.g, v.b, v.a or 255) end
	end
	chat.AddText(unpack(parts))
end)
