-- Astral Research — arbre technologique (définitions partagées).
-- Une technologie coûte de l'argent et, pour les plus avancées, des composants pris dans les conteneurs industriels
-- du joueur. Ses effets s'appliquent à toutes ses machines Astral. Déblocage définitif, enregistré en base.
--
-- effects : { cle = valeur }  — multiplicateurs (drill, refine, fabricate, sell, discharge, rare) cumulés par produit,
--                               « capacity » additionnel (unités de stockage par conteneur).

Astral.Research = Astral.Research or {}
local RS = Astral.Research

RS.Techs = {
	{ id = "drill_1",    tier = 1, name = "Forage optimisé",      desc = "Foreuses +25 % plus rapides.",                       money = 50000,  items = {},                    effects = { drill = 1.25 } },
	{ id = "refine_1",   tier = 1, name = "Fonderie avancée",     desc = "Raffineries +30 % plus rapides.",                    money = 80000,  items = {},                    effects = { refine = 1.3 } },
	{ id = "storage_1",  tier = 1, name = "Logistique",           desc = "Conteneurs : +250 unités de capacité.",              money = 60000,  items = {},                    effects = { capacity = 250 } },
	{ id = "drill_2",    tier = 2, name = "Forage profond",       desc = "Foreuses +25 % et minerais rares ×1,5.",             money = 150000, items = { steel_plate = 10 },  effects = { drill = 1.25, rare = 1.5 }, requires = "drill_1" },
	{ id = "fab_1",      tier = 2, name = "Ateliers automatisés", desc = "Fabricateurs +30 % plus rapides.",                   money = 200000, items = { circuit = 10 },      effects = { fabricate = 1.3 }, requires = "refine_1" },
	{ id = "trade_1",    tier = 2, name = "Négoce",               desc = "Ventes industrielles +10 %.",                        money = 120000, items = { alloy_frame = 5 },   effects = { sell = 1.1 }, requires = "storage_1" },
	{ id = "energy_1",   tier = 3, name = "Réseau intelligent",   desc = "Batteries : redistribution ×2.",                     money = 250000, items = { power_cell = 3 },    effects = { discharge = 2 }, requires = "fab_1" },
}
RS.ById = {}
for _, t in ipairs(RS.Techs) do RS.ById[t.id] = t end

-- Côté serveur : ply.AstralResearch = { [tech_id] = true } (chargé depuis la base)
function RS.Has(ply, id)
	return IsValid(ply) and ply.AstralResearch and ply.AstralResearch[id] == true
end

-- Multiplicateur cumulé d'un effet pour un joueur (1 si aucune technologie ne le modifie)
function RS.Mult(ply, key)
	if not IsValid(ply) or not ply.AstralResearch then return 1 end
	local m = 1
	for id in pairs(ply.AstralResearch) do
		local t = RS.ById[id]
		if t and t.effects[key] and key ~= "capacity" then m = m * t.effects[key] end
	end
	return m
end

function RS.Add(ply, key)
	if not IsValid(ply) or not ply.AstralResearch then return 0 end
	local s = 0
	for id in pairs(ply.AstralResearch) do
		local t = RS.ById[id]
		if t and t.effects[key] then s = s + t.effects[key] end
	end
	return s
end
