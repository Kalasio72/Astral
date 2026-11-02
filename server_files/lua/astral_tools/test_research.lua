-- Astral BaseWars — test des effets de recherche, en mémoire uniquement (rien n'est écrit en base, l'état est restauré).
-- Console serveur : lua_openscript astral_tools/test_research.lua
local p = player.GetAll()[1]
if not IsValid(p) then return print("[Astral Test] ECHEC : aucun joueur connecté") end
local saved = p.AstralResearch
print("[Astral Test] Recherches chargées depuis la base : " .. (saved and table.Count(saved) or "non chargées"))
p.AstralResearch = { drill_1 = true, drill_2 = true, storage_1 = true }
local RS = Astral.Research
local function check(label, got, want) print(string.format("[Astral Test] %s = %s (attendu %s) → %s", label, tostring(got), tostring(want), math.abs(got - want) < 1e-6 and "OK" or "ECHEC")) end
check("Bonus foreuse", RS.Mult(p, "drill"), 1.5625)
check("Bonus minerais rares", RS.Mult(p, "rare"), 1.5)
check("Capacité conteneur", RS.Add(p, "capacity"), 250)
check("Bonus vente (non débloqué)", RS.Mult(p, "sell"), 1)
p.AstralResearch = saved
print("[Astral Test] État restauré")
