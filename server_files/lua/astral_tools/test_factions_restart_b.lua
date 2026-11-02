-- Astral BaseWars — test de persistance des factions À TRAVERS UN REDÉMARRAGE, étape B (voir étape A).
RunConsoleCommand("sv_hibernate_think", "1")
local NAME = "Astral Test Restart"
local FT = BaseWars.Factions.FactionTable
print(string.format("[Astral Test] B : faction rechargée au démarrage → %s", FT[NAME] and Astral.Factions.Active[NAME] and "OK" or "ECHEC"))
print(string.format("[Astral Test] B : équipe recréée → %s", FT[NAME] and team.GetName(FT[NAME].teamid) == NAME and "OK" or "ECHEC"))
local bot = player.CreateNextBot("AstralTestFac")
print("[Astral Test] B : bot " .. tostring(bot:SteamID64()))
timer.Simple(6, function()
	if not IsValid(bot) then return print("[Astral Test] ECHEC : bot disparu") end
	print(string.format("[Astral Test] B : chef reconnecté remis dans sa faction → %s", bot:GetFaction() == NAME and "OK" or "ECHEC (" .. bot:GetFaction() .. ")"))
	print(string.format("[Astral Test] B : rôle de chef restauré → %s", bot:GetNW2Bool("BaseWars.Factions.Leader") and "OK" or "ECHEC"))
	print(string.format("[Astral Test] B : équipe du joueur → %s", bot:Team() == (FT[NAME] and FT[NAME].teamid) and "OK" or "ECHEC"))
	bot:LeaveFaction(true)   -- dissolution par le chef (comme le bouton « Quitter » du menu F3)
	print(string.format("[Astral Test] B : dissolution par le chef → %s", FT[NAME] == nil and Astral.Factions.Active[NAME] == nil and "OK" or "ECHEC"))
	timer.Simple(1, function() if IsValid(bot) then bot:Kick("Fin du test Astral") end print("[Astral Test] B : terminé") end)
end)
