-- Astral BaseWars — test automatique de la chaîne industrielle (fabricateur + batterie).
-- Console serveur : lua_openscript astral_tools/test_industry.lua   (un joueur doit être connecté : il sert de propriétaire)
-- Crée des machines de test SANS débiter d'argent, leur donne des ingrédients, attend, vérifie, puis les supprime.

local ply = player.GetAll()[1]
if not IsValid(ply) then return print("[Astral Test] ECHEC : aucun joueur connecté") end

-- Point de test : on s'éloigne du joueur jusqu'à sortir des zones trigger_remove et trouver le sol
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
if not base then return print("[Astral Test] ECHEC : aucun emplacement libre trouvé") end

local created = {}
local function make(class, offset)
	local e = ents.Create(class)
	e:SetPos(base + offset + Vector(0, 0, 30))
	e:Spawn() e:Activate()
	BaseWars.CPPI.SetOwner(e, ply)
	local ph = e:GetPhysicsObject() if IsValid(ph) then ph:EnableMotion(false) end
	created[#created + 1] = e
	return e
end

make("bw_gen_gas", Vector(0, 0, 0)) make("bw_gen_gas", Vector(80, 0, 0)) make("bw_gen_gas", Vector(160, 0, 0))
local battery = make("astral_battery", Vector(0, 100, 0))
local fab = make("astral_fabricator", Vector(120, 120, 0))
local box = make("astral_container", Vector(-120, 100, 0))

timer.Simple(1, function()
	box.AstralStore = { iron_ingot = 6, coal = 2 }
	box:AstralSync()
	fab:SetRecipe("steel_plate")
	print("[Astral Test] Machines créées à " .. tostring(base) .. ", recette « Plaque d'acier », ingrédients dans le conteneur")
end)

timer.Simple(40, function()
	local plates = (box.AstralStore and box.AstralStore.steel_plate or 0) + (fab.AstralOut and fab.AstralOut.steel_plate or 0)
	local ok1 = plates >= 1
	local ok2 = IsValid(battery) and battery:GetPower() > 0
	print(string.format("[Astral Test] Fabricateur : %d plaque(s) d'acier produite(s) → %s", plates, ok1 and "OK" or "ECHEC"))
	print(string.format("[Astral Test] Batterie : %d / %d → %s", IsValid(battery) and battery:GetPower() or -1, IsValid(battery) and battery:GetMaxPower() or -1, ok2 and "OK" or "ECHEC"))
	print("[Astral Test] Statut fabricateur : " .. (IsValid(fab) and fab:GetNW2String("AstralStatus") or "?"))
	for _, e in ipairs(created) do if IsValid(e) then e.CurrentValue = nil e:Remove() end end
	print("[Astral Test] Machines de test supprimées")
end)
