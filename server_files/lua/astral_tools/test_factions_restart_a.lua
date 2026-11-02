-- Astral BaseWars — test de persistance des factions À TRAVERS UN REDÉMARRAGE, étape A (avec un bot).
-- 1) lua_openscript astral_tools/test_factions_restart_a.lua  → crée « Astral Test Restart » (chef = 1er bot), puis déconnecte le bot
-- 2) redémarrer le serveur (le 1er bot après redémarrage reçoit le même SteamID64)
-- 3) lua_openscript astral_tools/test_factions_restart_b.lua  → vérifie la restauration, puis dissout la faction
RunConsoleCommand("sv_hibernate_think", "1")   -- sinon les minuteries s'arrêtent quand le serveur est vide
local NAME = "Astral Test Restart"
local bot = player.CreateNextBot("AstralTestFac")
print("[Astral Test] A : bot " .. tostring(bot:SteamID64()))
timer.Simple(5, function()
	if not IsValid(bot) then return print("[Astral Test] ECHEC : bot disparu") end
	BaseWars.Factions:Create(bot, NAME, nil, Color(255, 140, 200))
	print(string.format("[Astral Test] A : faction créée → %s", bot:GetFaction() == NAME and "OK" or "ECHEC"))
	timer.Simple(3, function()
		if IsValid(bot) then bot:Kick("Test Astral : étape A terminée") end
		timer.Simple(1, function()
			print(string.format("[Astral Test] A : faction conservée après déconnexion du chef → %s", BaseWars.Factions.FactionTable[NAME] and "OK" or "ECHEC"))
			print("[Astral Test] A : terminé, redémarrer le serveur puis lancer l'étape B")
		end)
	end)
end)
