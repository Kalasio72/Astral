-- Astral — habillage unifié des machines (partagé serveur/client), sur le modèle des imprimantes (sh_printers.lua).
-- Chaque machine listée reçoit un bloc PHX fourni avec Garry's Mod (rien à télécharger, existence vérifiée sur le
-- serveur le 2026-11-02), une couleur d'identité et un style d'écran ; le dessin est fait par astral/ui/cl_looks.lua.
-- Les machines au modèle fonctionnel (tourelles, radar, tesla, distributeur, explosifs, soins) ne sont pas touchées.

Astral.Looks = Astral.Looks or {}
local L = Astral.Looks

local B = "models/hunter/blocks/"
local SMALL, MID, BIG = B .. "cube05x05x05.mdl", B .. "cube075x075x075.mdl", B .. "cube1x1x1.mdl"
local LONG, WIDE, FLAT = B .. "cube05x1x05.mdl", B .. "cube075x1x075.mdl", B .. "cube05x05x025.mdl"

-- style : gen (cœur de réacteur), vault (écran SpaceVX), drill, refinery, greenhouse, battery, container, fabricator,
--         dispenser, spawn. brand : texte des flancs.
L.Classes = {
	bw_gen_gas      = { label = "Générateur à gaz", model = MID, color = Color(255, 150, 60),  style = "gen", brand = "ASTRAL ÉNERGIE" },
	bw_gen_solar    = { label = "Panneau solaire", model = MID, color = Color(255, 220, 80),  style = "gen", brand = "ASTRAL ÉNERGIE" },
	bw_gen_coalfired = { label = "Générateur à charbon", model = MID, color = Color(255, 95, 70),  style = "gen", brand = "ASTRAL ÉNERGIE" },
	bw_gen_fission  = { label = "Réacteur à fission", model = BIG, color = Color(120, 255, 120), style = "gen", brand = "ASTRAL ÉNERGIE" },
	bw_gen_hydro    = { label = "Centrale hydroélectrique", model = BIG, color = Color(80, 170, 255),  style = "gen", brand = "ASTRAL ÉNERGIE" },
	bw_gen_fusion   = { label = "Réacteur à fusion", model = BIG, color = Color(90, 240, 255),  style = "gen", brand = "ASTRAL ÉNERGIE" },
	bw_gen_dark     = { label = "Réacteur à matière noire", model = BIG, color = Color(190, 110, 255), style = "gen", brand = "ASTRAL ÉNERGIE" },
	bw_vault        = { label = "Coffre-fort", model = MID, color = Color(110, 225, 150), style = "vault", brand = "ASTRAL COFFRE" },
	bw_vault_vip    = { label = "Coffre-fort VIP", model = MID, color = Color(255, 200, 90),  style = "vault", brand = "ASTRAL COFFRE" },
	bw_dispenser_ammo   = { label = "Distributeur de munitions", model = SMALL, color = Color(255, 190, 90),  style = "dispenser", brand = "MUNITIONS", icon = "▮▮▮" },
	bw_dispenser_ammo2  = { label = "Distributeur de munitions v2", model = SMALL, color = Color(255, 140, 60),  style = "dispenser", brand = "MUNITIONS", icon = "▮▮▮" },
	bw_dispenser_armor  = { label = "Distributeur d'armure", model = SMALL, color = Color(90, 150, 255),  style = "dispenser", brand = "ARMURE", icon = "◆" },
	bw_dispenser_armor2 = { label = "Distributeur d'armure v2", model = SMALL, color = Color(60, 110, 255),  style = "dispenser", brand = "ARMURE", icon = "◆" },
	bw_dispenser_paper  = { label = "Recharge de papier", model = FLAT,  color = Color(230, 236, 248), style = "dispenser", brand = "PAPIER", icon = "▤" },
	bw_spawnpoint   = { label = "Point de réapparition", model = FLAT, color = Color(110, 205, 255), style = "spawn", brand = "RÉAPPARITION" },
	astral_drill      = { model = LONG, color = Color(255, 170, 80),  style = "drill", brand = "ASTRAL INDUSTRIE" },
	astral_refinery   = { model = MID,  color = Color(255, 110, 60),  style = "refinery", brand = "ASTRAL INDUSTRIE" },
	astral_container  = { model = WIDE, color = Color(150, 170, 200), style = "container", brand = "ASTRAL INDUSTRIE" },
	astral_fabricator = { model = MID,  color = Color(170, 130, 255), style = "fabricator", brand = "ASTRAL INDUSTRIE" },
	astral_greenhouse = { model = LONG, color = Color(110, 230, 120), style = "greenhouse", brand = "ASTRAL AGRO" },
	astral_battery    = { model = SMALL, color = Color(255, 215, 90), style = "battery", brand = "ASTRAL ÉNERGIE" },
}

function L.Get(ent) return IsValid(ent) and L.Classes[ent:GetClass()] or nil end

-- Remplacement des modèles (classes et icônes de la boutique), comme pour les imprimantes
local function swap()
	for class, look in pairs(L.Classes) do
		local stored = scripted_ents.GetStored(class)
		if stored and stored.t then
			stored.t.AstralOriginalModel = stored.t.AstralOriginalModel or stored.t.Model
			stored.t.Model = look.model
		end
	end
	for _, items in pairs(BaseWars.SpawnList and BaseWars.SpawnList.Entities or {}) do
		for _, item in pairs(items) do
			if istable(item) and isstring(item.ClassName) and L.Classes[item.ClassName] then item.Model = L.Classes[item.ClassName].model end
		end
	end
end
swap()
hook.Add("Initialize", "Astral.Looks.Models", swap)
hook.Add("InitPostEntity", "Astral.Looks.Models", swap)
