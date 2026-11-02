-- Vérifie le chargement du premier lot (sièges SIMPSit, tableau des joueurs et menu Échap Astral) côté serveur.
-- Console serveur : lua_openscript astral_tools/test_lot1.lua
local function out(ok, msg) print(string.format("[Astral Test] %s %s", ok and "OK   " or "ECHEC", msg)) end
out(SIMPSit ~= nil and SIMPSit.Core.Sit ~= nil, "SIMPSit chargé")
out(concommand.GetTable()["sit"] ~= nil, "commande « sit » enregistrée")
out(hook.GetTable().ShouldAllowSit and hook.GetTable().ShouldAllowSit["Astral.SitRules"] ~= nil, "règle anti-abus des sièges active")
out(Astral and Astral.Version ~= nil, "socle Astral chargé (" .. tostring(Astral and Astral.Version) .. ")")
out(AstralShield ~= nil, "Astral Shield actif (" .. tostring(AstralShield and AstralShield.Blocked) .. " blocage(s))")
