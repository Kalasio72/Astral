-- Astral — PNJ de la carte : retire les PNJ d'aide SpaceVX (bw_npc, en tenue de médecin, que les joueurs prenaient
-- pour des PNJ de soin) et place les PNJ Astral (entities/astral_npc.lua) aux mêmes endroits.
-- Positions par carte (nom en minuscules) ; une carte absente de la liste reprend les positions SpaceVX.

Astral.NPCs = Astral.NPCs or {}
local N = Astral.NPCs

N.Maps = {
	basewars_evocity_v2 = {
		{ role = "guide",  pos = Vector(380, 4305, 71),    ang = Angle(0, 180, 0) },
		{ role = "quests", pos = Vector(300, 2932, 71),    ang = Angle(0, 90, 0) },
		{ role = "dealer", pos = Vector(-6297, -5742, 75), ang = Angle(0, 45, 0) },
	},
}
local ROLES = { "guide", "quests", "dealer" }

local function spots()
	local list = N.Maps[game.GetMap():lower()]
	if list then return list end
	-- Repli : positions SpaceVX de la carte (BaseWars.NPCTable, clé sensible à la casse)
	for map, entries in pairs(BaseWars.NPCTable or {}) do
		if map:lower() == game.GetMap():lower() then
			list = {}
			for i, e in ipairs(entries) do list[#list + 1] = { role = ROLES[(i - 1) % #ROLES + 1], pos = e.Pos, ang = e.Ang } end
			return list
		end
	end
	return {}
end

function N.Spawn()
	for _, e in ipairs(ents.FindByClass("bw_npc")) do e:Remove() end
	for _, e in ipairs(ents.FindByClass("astral_npc")) do e:Remove() end
	local n = 0
	for _, s in ipairs(spots()) do
		local e = ents.Create("astral_npc")
		if IsValid(e) then
			e:SetRole(s.role)
			-- Posé au sol (même méthode que bw_npc:FixPosition)
			local tr = util.TraceLine({ start = s.pos + Vector(0, 0, 20), endpos = s.pos - Vector(0, 0, 200), mask = MASK_SOLID_BRUSHONLY })
			e:SetPos(tr.Hit and tr.HitPos or s.pos)
			e:SetAngles(Angle(0, s.ang.y, 0))
			e:Spawn() e:Activate()
			if BaseWars.CPPI and BaseWars.CPPI.SetOwner then BaseWars.CPPI.SetOwner(e, game.GetWorld()) end
			n = n + 1
		end
	end
	Astral.Log("world", n .. " PNJ Astral placé(s)")
end

-- Le module NPCs de SpaceVX crée ses PNJ à InitPostEntity : on retire son hook et on place les nôtres
hook.Remove("InitPostEntity", "BaseWars.NPCs.CreateNPCs")
hook.Add("InitPostEntity", "Astral.NPCs", function() timer.Simple(1, N.Spawn) end)
hook.Add("PostCleanupMap", "Astral.NPCs", function() timer.Simple(1, N.Spawn) end)
if #ents.GetAll() > 0 and player.GetCount() > 0 then timer.Simple(1, N.Spawn) end   -- rechargement à chaud
