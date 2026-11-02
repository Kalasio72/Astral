-- Astral BaseWars — test automatique de la serre (sans débit d'argent ; machines supprimées à la fin).
-- Console serveur : lua_openscript astral_tools/test_farming.lua   (un joueur connecté sert de propriétaire)
local ply = player.GetAll()[1]
if not IsValid(ply) then return print("[Astral Test] ECHEC : aucun joueur connecté") end

local zones = {}
for _, t in ipairs(ents.FindByClass("trigger_remove")) do local a, b = t:WorldSpaceAABB() zones[#zones + 1] = { a, b } end
local function inZone(p) for _, z in ipairs(zones) do if p:WithinAABox(z[1], z[2]) then return true end end return false end
local base
for dist = 600, 3000, 200 do
	for _, dir in ipairs({ Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0) }) do
		local p = ply:GetPos() + dir * dist + Vector(0, 0, 200)
		local tr = util.TraceLine({ start = p, endpos = p - Vector(0, 0, 1000) })
		if tr.Hit and not tr.StartSolid and not inZone(tr.HitPos) then base = tr.HitPos break end
	end
	if base then break end
end
if not base then return print("[Astral Test] ECHEC : aucun emplacement libre") end

local created = {}
local function make(class, offset)
	local e = ents.Create(class)
	e:SetPos(base + offset + Vector(0, 0, 40)) e:Spawn() e:Activate()
	BaseWars.CPPI.SetOwner(e, ply)
	local ph = e:GetPhysicsObject() if IsValid(ph) then ph:EnableMotion(false) end
	created[#created + 1] = e
	return e
end
make("bw_gen_gas", Vector(0, 0, 0))
local gh = make("astral_greenhouse", Vector(100, 0, 0))
local box = make("astral_container", Vector(0, 120, 0))
timer.Simple(1, function() gh:SetCrop("wheat") print("[Astral Test] Serre plantée en blé (60 s par récolte de 4)") end)
timer.Simple(75, function()
	local wheat = (box.AstralStore and box.AstralStore.wheat or 0) + (gh.AstralOut and gh.AstralOut.wheat or 0)
	print(string.format("[Astral Test] Blé récolté : %d (attendu ≥ 4) → %s", wheat, wheat >= 4 and "OK" or "ECHEC"))
	print("[Astral Test] Statut serre : " .. (IsValid(gh) and gh:GetNW2String("AstralStatus") or "?"))
	for _, e in ipairs(created) do if IsValid(e) then e.CurrentValue = nil e:Remove() end end
	print("[Astral Test] Machines de test supprimées")
end)
