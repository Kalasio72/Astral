-- Astral Industries — ajout des machines à la boutique BaseWars (menu A, onglet Entités).
-- Passer par la boutique SpaceVX garantit les contrôles serveur existants : argent, niveau, limite par joueur,
-- propriété CPPI, remboursement à la destruction, journal des achats.

local cat = BaseWars.SpawnList and BaseWars.SpawnList.Entities
if not cat then return end

cat["Astral Industries"] = {
	["Foreuse"] = BaseWars.GSL{ Model = "models/props_c17/TrapPropeller_Engine.mdl", Price = 25000, ClassName = "astral_drill", Level = 5, Limit = 4 },
	["Raffinerie"] = BaseWars.GSL{ Model = "models/props_c17/FurnitureBoiler001a.mdl", Price = 40000, ClassName = "astral_refinery", Level = 8, Limit = 2 },
	["Conteneur industriel"] = BaseWars.GSL{ Model = "models/props_wasteland/controlroom_storagecloset001a.mdl", Price = 10000, ClassName = "astral_container", Level = 5, Limit = 2 },
	["Fabricateur"] = BaseWars.GSL{ Model = "models/props_lab/hev_machine.mdl", Price = 60000, ClassName = "astral_fabricator", Level = 12, Limit = 2 },
	["Serre hydroponique"] = BaseWars.GSL{ Model = "models/props_c17/display_cooler01a.mdl", Price = 20000, ClassName = "astral_greenhouse", Level = 4, Limit = 4 },
	["Batterie Astral"] = BaseWars.GSL{ Model = "models/props_lab/powerbox01a.mdl", Price = 15000, ClassName = "astral_battery", Level = 6, Limit = 4 },
	["Banque Astral"] = BaseWars.GSL{ Model = "models/hunter/blocks/cube075x1x075.mdl", Price = 250000, ClassName = "bw_astral_bank", Level = 10, Limit = 1 },
}