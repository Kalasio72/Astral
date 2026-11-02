-- Astral BaseWars — test des classements (lecture seule : aucune écriture en base, aucun compte modifié).
-- Console serveur : lua_openscript astral_tools/test_leaders.lua
local ST = Astral.Stats
if not ST or not ST.GetLeaders then return print("[Astral Test] ECHEC : module Astral.Stats absent") end
local t0 = SysTime()
ST.GetLeaders(function(data)
	print(string.format("[Astral Test] Classements construits en %.0f ms", (SysTime() - t0) * 1000))
	for _, b in ipairs(ST.Boards) do
		local rows = data[b.id]
		if not rows then
			print("[Astral Test] ECHEC : classement " .. b.id .. " manquant")
		else
			local first = rows[1]
			print(string.format("[Astral Test] %-8s : %d ligne(s)%s", b.id, #rows, first and string.format(" ; 1er = %s (%s)%s", first.name, tostring(first.v), first.online and " en ligne" or "") or ""))
		end
	end
	-- Second appel : doit venir du cache (instantané)
	local t1 = SysTime()
	ST.GetLeaders(function() print(string.format("[Astral Test] Cache : %.2f ms → %s", (SysTime() - t1) * 1000, SysTime() - t1 < 0.005 and "OK" or "LENT")) end)
end)
