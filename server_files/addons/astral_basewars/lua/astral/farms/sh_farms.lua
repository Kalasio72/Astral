-- Astral Fermes (partagé) : définitions des produits et des machines de production illicite, sac du joueur.
-- Écrit pour Astral (aucun code repris d'addons tiers). Boucle de jeu :
--   1. la ferme (alimentée en énergie) produit des lots tant que son stock n'est pas plein ;
--   2. le propriétaire les met dans son sac (E → menu, ou Maj + E) ;
--   3. il les revend au receleur (PNJ Silas, astral_npc rôle « dealer »), payé comptant ;
--   4. à sa mort, le sac tombe au sol (astral_bag) et n'importe qui peut le ramasser.
-- Labo de méthamphétamine : la température monte pendant la cuisson ; au-delà de 100 °C, explosion.
-- Le propriétaire doit purger la cuve (menu) pour la refroidir.
-- Atelier pyrotechnique : les feux d'artifice se revendent ou se tirent (effet visible par tous).

Astral.Farms = Astral.Farms or {}
local F = Astral.Farms

F.BagMax = 60   -- unités transportables

F.Products = {
	weed      = { name = "Cannabis",          value = 600,   color = Color(110, 220, 90) },
	tobacco   = { name = "Tabac séché",       value = 450,   color = Color(210, 160, 80) },
	coke      = { name = "Cocaïne",           value = 3000,  color = Color(235, 240, 255) },
	meth      = { name = "Méthamphétamine",   value = 12000, color = Color(110, 200, 255) },
	firework  = { name = "Feu d'artifice",    value = 4000,  color = Color(255, 90, 200) },
}
F.ProductOrder = { "weed", "tobacco", "coke", "meth", "firework" }

-- seconds : durée d'un lot ; yield : unités par lot ; stock : lots maximum en attente dans la machine
F.Machines = {
	astral_farm_weed = { name = "Culture de cannabis", product = "weed", seconds = 120, yield = 6, stock = 4,
		price = 15000, level = 3, limit = 4, power = 6, hp = 300, color = Color(110, 220, 90), anim = "plant" },
	astral_farm_tobacco = { name = "Séchoir à tabac", product = "tobacco", seconds = 150, yield = 8, stock = 4,
		price = 25000, level = 5, limit = 4, power = 6, hp = 350, color = Color(220, 160, 70), anim = "dryer" },
	astral_farm_coke = { name = "Labo de cocaïne", product = "coke", seconds = 180, yield = 5, stock = 3,
		price = 120000, level = 15, limit = 2, power = 14, hp = 500, color = Color(220, 235, 255), anim = "lab" },
	astral_farm_meth = { name = "Labo de méthamphétamine", product = "meth", seconds = 240, yield = 4, stock = 3,
		price = 400000, level = 25, limit = 2, power = 25, hp = 600, color = Color(90, 180, 255), anim = "cook", heat = true },
	astral_farm_fireworks = { name = "Atelier pyrotechnique", product = "firework", seconds = 90, yield = 1, stock = 5,
		price = 60000, level = 8, limit = 2, power = 8, hp = 300, color = Color(255, 90, 200), anim = "rockets" },
}
F.MachineOrder = { "astral_farm_weed", "astral_farm_tobacco", "astral_farm_fireworks", "astral_farm_coke", "astral_farm_meth" }

-- Sac : { [produit] = quantité }, diffusé en NW2String « AstralBag » (« weed=3;meth=1 »)
function F.Bag(ply)
	if SERVER then return ply.AstralBag or {} end
	local bag = {}
	for id, q in string.gmatch(ply:GetNW2String("AstralBag", ""), "([%w_]+)=(%d+)") do bag[id] = tonumber(q) end
	return bag
end
function F.BagCount(bag) local n = 0 for _, q in pairs(bag) do n = n + q end return n end
function F.BagValue(bag)
	local v = 0
	for id, q in pairs(bag) do if F.Products[id] then v = v + F.Products[id].value * q end end
	return v
end

---------------------------------------------------------------------------
-- Entités : une classe par machine, toutes dérivées de astral_farm_base
---------------------------------------------------------------------------
for class, def in pairs(F.Machines) do
	scripted_ents.Register({
		Base = "astral_farm_base", Type = "anim", PrintName = def.name, Spawnable = false,
		Model = "models/hunter/blocks/cube05x1x05.mdl", FarmClass = class, Farm = def,
		PowerRequired = def.power, PresetMaxHealth = def.hp,
	}, class)
end

-- Boutique : catégorie « Astral Fermes »
local cat = BaseWars.SpawnList and BaseWars.SpawnList.Entities
if cat then
	cat["Astral Fermes"] = {}
	for _, class in ipairs(F.MachineOrder) do
		local def = F.Machines[class]
		cat["Astral Fermes"][def.name] = BaseWars.GSL{ Model = "models/hunter/blocks/cube05x1x05.mdl", Price = def.price, ClassName = class, Level = def.level, Limit = def.limit }
	end
end

-- Habillage (sh_looks.lua / cl_looks.lua)
if Astral.Looks and Astral.Looks.Classes then
	for class, def in pairs(F.Machines) do
		Astral.Looks.Classes[class] = { label = def.name, model = "models/hunter/blocks/cube05x1x05.mdl", color = def.color, style = "farm", brand = "ASTRAL FERMES" }
	end
end
