-- Astral BaseWars — test de l'équilibrage en jeu (sv_settings.lua), depuis la console serveur.
-- Étape 1 : lua_openscript astral_tools/test_settings.lua         → validations + écriture « charbon = 11 »
-- Étape 2 : redémarrer, puis relancer ce script                     → vérifie que « charbon = 11 » a survécu, puis rétablit 10
-- Valeur de test choisie minime (prix du charbon 10 → 11 £) et toujours rétablie à la fin.
local ST = Astral.Settings
if not ST then return print("[Astral Test] ECHEC : module absent") end
local function out(ok, msg) print(string.format("[Astral Test] %s %s", ok and "OK   " or "ECHEC", msg)) end
local coal = Astral.Resources.Get("coal")

if coal.value == 11 then
	out(ST.Overrides["Resources.coal.value"] == 11, "après redémarrage : prix du charbon 11 réappliqué depuis la base")
	ST.Set(nil, "Resources.coal.value", tostring(ST.Defaults["Resources.coal.value"]), function(ok, msg)
		out(ok and coal.value == 10, "rétabli au défaut : " .. tostring(msg))
	end)
	return
end

local pending = 0
local function expectFail(path, text, why)
	pending = pending + 1
	ST.Set(nil, path, text, function(ok, msg) out(not ok, why .. " → refusé (" .. tostring(msg) .. ")") end)
end
expectFail("Market.TaxPercent", "abc", "valeur non numérique")
expectFail("Market.TaxPercent", "80", "taxe 80 % (max 50)")
expectFail("Market.MaxOrders", "2.5", "nombre d'offres non entier")
expectFail("Logs.MaxQueue", "5000", "réglage hors liste modifiable")
out(Astral.Cfg("Market.TaxPercent") == 5, "taxe inchangée après les refus (" .. tostring(Astral.Cfg("Market.TaxPercent")) .. ")")

ST.Set(nil, "Resources.coal.value", "11", function(ok, msg)
	out(ok and coal.value == 11 and ST.Overrides["Resources.coal.value"] == 11, "prix du charbon 10 → 11 appliqué : " .. tostring(msg))
	Astral.DB.Conn():FetchOne("SELECT value FROM astral_settings WHERE path = 'Resources.coal.value'", { callback = function(e, r)
		out(r and r.value == "11", "enregistré en base (" .. tostring(r and r.value) .. ") — redémarrer puis relancer le script")
	end })
end)
