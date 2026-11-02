-- Astral Events — définitions (partagées : le HUD affiche le nom et la description de l'événement en cours).
-- L'événement actif est diffusé par deux variables globales : AstralEvent (identifiant) et AstralEventEnds (CurTime de fin).
-- Multiplicateurs lus par le code via Astral.Events.Mult("cle") (1 si aucun événement ne la modifie) :
--   drill, refine, fabricate, payday, rare_ore, sell (industrie), farm (vitesse des fermes), farm_sell (receleur),
--   print (production des imprimantes).
-- fx : ambiance côté client (astral/ui/cl_events.lua) : color, sound (lancement), ambient (money, fireworks, sparks, leaves).

Astral.Events = Astral.Events or {}
local E = Astral.Events

E.List = {
	mining_rush    = { name = "Ruée minière",        desc = "Les foreuses extraient 2× plus vite.",              mult = { drill = 2 },
		fx = { color = Color(255, 170, 80), ambient = "sparks" } },
	refinery_boost = { name = "Hauts fourneaux",     desc = "Raffineries et fabricateurs 2× plus rapides.",     mult = { refine = 2, fabricate = 2 },
		fx = { color = Color(255, 110, 60), ambient = "sparks" } },
	double_payday  = { name = "Paye doublée",        desc = "La paye automatique est doublée.",                 mult = { payday = 2 },
		fx = { color = Color(110, 225, 150), ambient = "money" } },
	crystal_rain   = { name = "Pluie de cristaux",   desc = "Cristaux énergétiques et minerais rares ×8.",      mult = { rare_ore = 8 },
		fx = { color = Color(120, 230, 255), ambient = "crystals" } },
	market_boom    = { name = "Boom du marché",      desc = "Les ventes industrielles rapportent +50 %.",       mult = { sell = 1.5 },
		fx = { color = Color(255, 210, 90), ambient = "money" } },
	print_frenzy   = { name = "Frénésie d'impression", desc = "Toutes les imprimantes produisent 2× plus.",      mult = { print = 2 },
		fx = { color = Color(110, 205, 255), ambient = "money" } },
	harvest_fest   = { name = "Récolte record",      desc = "Les fermes produisent 2× plus vite.",              mult = { farm = 2 },
		fx = { color = Color(110, 220, 90), ambient = "leaves" } },
	black_market   = { name = "Marché noir",         desc = "Le receleur paie 50 % de plus.",                   mult = { farm_sell = 1.5 },
		fx = { color = Color(255, 150, 80), ambient = "smoke" } },
	gold_rush      = { name = "Ruée vers l'or",      desc = "Paye ×3 et imprimantes +50 %.",                   mult = { payday = 3, print = 1.5 },
		fx = { color = Color(255, 205, 60), ambient = "money" } },
	fireworks_night = { name = "Nuit des feux d'artifice", desc = "Spectacle dans le ciel, paye ×1,5 et fermes +50 %.", mult = { payday = 1.5, farm = 1.5 },
		fx = { color = Color(255, 90, 200), ambient = "fireworks" } },
}
E.Order = { "mining_rush", "refinery_boost", "double_payday", "crystal_rain", "market_boom", "print_frenzy", "harvest_fest", "black_market", "gold_rush", "fireworks_night" }

function E.Current()
	local id = GetGlobal2String("AstralEvent", "")
	if id == "" or GetGlobal2Float("AstralEventEnds", 0) < CurTime() then return nil end
	return id, E.List[id]
end

function E.Mult(key)
	local _, ev = E.Current()
	return ev and ev.mult[key] or 1
end
