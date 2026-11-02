-- Astral BaseWars — test des tours de défense corrigées (patch T1) avec un bot ; machines retirées à la fin.
-- Console serveur : lua_openscript astral_tools/test_towers.lua
RunConsoleCommand("sv_hibernate_think", "1")
local function out(ok, msg) print(string.format("[Astral Test] %s %s", ok and "OK   " or "ECHEC", msg)) end
local bot = player.CreateNextBot("AstralTours")
local created = {}
timer.Simple(5, function()
	if not IsValid(bot) then return out(false, "bot absent") end
	local zones = {}
	for _, t in ipairs(ents.FindByClass("trigger_remove")) do local a, b = t:WorldSpaceAABB() zones[#zones + 1] = { a, b } end
	local function inZone(p) for _, z in ipairs(zones) do if p:WithinAABox(z[1], z[2]) then return true end end return false end
	local base
	for dist = 600, 3000, 200 do
		for _, dir in ipairs({ Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0) }) do
			local p = bot:GetPos() + dir * dist + Vector(0, 0, 200)
			local tr = util.TraceLine({ start = p, endpos = p - Vector(0, 0, 1000) })
			if tr.Hit and not tr.StartSolid and not inZone(tr.HitPos) then base = tr.HitPos break end
		end
		if base then break end
	end
	if not base then return out(false, "aucun emplacement libre") end
	local function make(class, off, price)
		local e = ents.Create(class) e:SetPos(base + off) e:Spawn() e:Activate()
		BaseWars.CPPI.SetOwner(e, bot)
		if price and e.SetUpgradeCost then e:SetUpgradeCost(price) end   -- comme la boutique (spawnmenu.lua)
		local ph = e:GetPhysicsObject() if IsValid(ph) then ph:EnableMotion(false) end
		created[#created + 1] = e
		return e
	end
	make("bw_gen_gas", Vector(0, -90, 20))
	local towers = {
		make("bw_turret_healer", Vector(0, 0, 10), 30000),
		make("bw_turret_freezer", Vector(0, 60, 10), 60000),
		make("bw_turret_acid", Vector(0, 120, 10), 75000),
	}
	for _, t in ipairs(towers) do
		out(IsValid(t) and t.GetRadius and t:GetRadius() == 300, t:GetClass() .. " : apparition sans erreur, rayon " .. tostring(IsValid(t) and t.GetRadius and t:GetRadius()))
		out(IsValid(t) and t:getUpgradeCost(1) > 0, t:GetClass() .. " : coût d'amélioration niv. 1 = " .. tostring(IsValid(t) and t:getUpgradeCost(1)))
	end
	bot:SetPos(base + Vector(80, 0, 10))
	bot:SetHealth(50)
	timer.Simple(6, function()
		out(IsValid(bot) and bot:Health() > 50, "tour de soin : le propriétaire blessé est soigné (50 → " .. (IsValid(bot) and bot:Health() or "?") .. ")")
		for _, e in ipairs(created) do if IsValid(e) then e:Remove() end end
		if IsValid(bot) then bot:Kick("Fin du test Astral") end
		print("[Astral Test] Terminé (vérifier l'absence d'erreur Lua ci-dessus)")
	end)
end)
