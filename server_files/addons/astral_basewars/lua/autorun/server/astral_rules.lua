-- Astral BaseWars — règles de jeu qui modifient le comportement BaseWars d'origine.
-- Branché sur les hooks et entités de SpaceVX : aucun fichier du gamemode n'est modifié ici.
-- G3 (délai de l'attaquant) est dans le moteur de raid lui-même : voir PATCHES.md (P11).

-- PNJ d'aide : la config SpaceVX indexe « Basewars_Evocity_v2 » alors que le fichier de map est en minuscules
-- (game.GetMap() renvoie « basewars_evocity_v2 » sur Linux). On ajoute des alias en minuscules.
hook.Add("PostGamemodeLoaded", "Astral.MapAliases", function()
	local npcs = BaseWars and BaseWars.NPCTable
	if not npcs then return end
	for name, data in pairs(table.Copy(npcs)) do
		local lower = string.lower(name)
		if not npcs[lower] then npcs[lower] = data end
	end
end)

-- Zones anti-construction des maps (trigger_remove) : tout objet acheté dedans est supprimé par la map,
-- sans remboursement. On refuse l'achat avant qu'il ait lieu, avec un message clair.
local removeZones = {}
local function cacheRemoveZones()
	removeZones = {}
	for _, t in ipairs(ents.FindByClass("trigger_remove")) do
		local mins, maxs = t:WorldSpaceAABB()
		removeZones[#removeZones + 1] = { mins, maxs }
	end
end
hook.Add("InitPostEntity", "Astral.RemoveZones", cacheRemoveZones)
hook.Add("PostCleanupMap", "Astral.RemoveZones", cacheRemoveZones)

-- Même calcul de position que la boutique SpaceVX (spawnmenu.lua : trace de 85 unités devant les yeux)
local function purchaseInRemoveZone(ply)
	if #removeZones == 0 then return false end
	local tr = util.TraceLine({ start = ply:EyePos(), endpos = ply:EyePos() + ply:GetAimVector() * 85, filter = ply })
	local pos = tr.HitPos + BaseWars.Config.SpawnOffset
	for _, z in ipairs(removeZones) do
		if pos:WithinAABox(z[1], z[2]) or ply:GetPos():WithinAABox(z[1], z[2]) then return true end
	end
	return false
end
local function blockInZone(ply)
	if purchaseInRemoveZone(ply) then
		return false, "Achat impossible ici : zone d'apparition protégée (les objets y sont supprimés). Éloigne-toi du spawn."
	end
end
hook.Add("BaseWars_PlayerCanBuyEntity", "Astral.RemoveZones", blockInZone)
hook.Add("BaseWars_PlayerCanBuyGun", "Astral.RemoveZones", blockInZone)
hook.Add("BaseWars_PlayerCanBuyDrug", "Astral.RemoveZones", blockInZone)
hook.Add("BaseWars_PlayerCanBuyProp", "Astral.RemoveZones", blockInZone)

local function ownerOf(ent)
	return BaseWars.CPPI.GetOwner(ent)
end

-- G1 : collecte des imprimantes et des coffres (bw_base_moneyprinter, bw_vault)
--   Hors raid : seul le propriétaire peut récupérer l'argent.
--   Pendant un raid : un participant du camp adverse au propriétaire peut aussi le récupérer.
local function sameSide(a, b)
	if a == b then return true end
	return a:InFaction() and b:InFaction() and a:GetFaction() == b:GetFaction()
end

hook.Add("BaseWars_PlayerCanEmptyPrinter", "Astral.G1.OwnerOnly", function(ply, ent)
	local owner = ownerOf(ent)
	if not IsValid(owner) or owner == ply then return end

	local raidOn = BaseWars.Raid and BaseWars.Raid:IsOnGoing()
	if raidOn and ply:InRaid() and owner:InRaid() and not sameSide(ply, owner) then return end

	return false, "Seul le propriétaire peut récupérer cet argent (sauf pendant un raid contre lui)."
end)

-- G2 : un générateur n'alimente que les machines de son propriétaire.
-- On enveloppe TransmitPower de bw_base_generator (hérité par tous les bw_gen_*) pour filtrer la liste
-- des machines à portée. Les entités créées après ce hook utilisent la version filtrée.
hook.Add("InitPostEntity", "Astral.G2.OwnerOnlyPower", function()
	local stored = scripted_ents.GetStored("bw_base_generator")
	if not stored or stored.t.AstralG2 then return end
	local base = stored.t
	local transmit = base.TransmitPower
	base.AstralG2 = true
	function base:TransmitPower(tbl, count, periods)
		local owner = ownerOf(self)
		local list, n = {}, 0
		for i = 1, count do
			local v = tbl[i]
			if IsValid(v) and ownerOf(v) == owner then
				n = n + 1
				list[n] = v
			end
		end
		return transmit(self, list, n, periods)
	end
end)
