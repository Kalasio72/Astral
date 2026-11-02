-- Astral BaseWars — vitrine des machines Astral (appartenant à un bot, retirées après 120 s) pour vérifier en capture
-- les panneaux 3D2D et les barres d'énergie. Console serveur : lua_openscript astral_tools/test_astral_showcase.lua
RunConsoleCommand("sv_hibernate_think", "1")
local bot = player.CreateNextBot("AstralVitrine2")
local created = {}
timer.Simple(5, function()
	if not IsValid(bot) then return print("[Astral Test] ECHEC : bot absent") end
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
	if not base then return print("[Astral Test] ECHEC : aucun emplacement libre") end
	local function make(class, off)
		local e = ents.Create(class) e:SetPos(base + off) e:Spawn() e:Activate()
		BaseWars.CPPI.SetOwner(e, bot)
		local ph = e:GetPhysicsObject() if IsValid(ph) then ph:EnableMotion(false) end
		created[#created + 1] = e
		return e
	end
	make("bw_gen_gas", Vector(-120, 0, 20))
	make("astral_drill", Vector(0, -150, 30))
	make("astral_refinery", Vector(0, -50, 30))
	local box = make("astral_container", Vector(0, 50, 40))
	make("astral_greenhouse", Vector(0, 150, 40))
	box.AstralStore = { iron_ingot = 42, copper_ore = 17, wheat = 9 } box:AstralSync()
	print(string.format("[Astral Test] Vitrine Astral : %.0f %.0f %.0f", base.x, base.y, base.z))
	hook.Add("SetupPlayerVisibility", "Astral.TestShowcase", function() AddOriginToPVS(base + Vector(0, 0, 80)) end)
end)
timer.Simple(125, function()
	hook.Remove("SetupPlayerVisibility", "Astral.TestShowcase")
	for _, e in ipairs(created) do if IsValid(e) then e:Remove() end end
	if IsValid(bot) then bot:Kick("Fin du test Astral") end
	print("[Astral Test] Vitrine Astral retirée")
end)
