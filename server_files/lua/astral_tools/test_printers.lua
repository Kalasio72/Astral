-- Astral BaseWars — vitrine de test des écrans d'imprimantes (machines appartenant à un bot, supprimées après 120 s).
-- Console serveur : lua_openscript astral_tools/test_printers.lua
-- Place un générateur et trois imprimantes sur un emplacement libre, rend la zone visible aux joueurs connectés
-- (SetupPlayerVisibility, temporaire) et affiche la position à regarder. Aucun compte de vrai joueur n'est touché.
RunConsoleCommand("sv_hibernate_think", "1")
local bot = player.CreateNextBot("AstralVitrine")
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
	local function make(class, off, ang)
		local e = ents.Create(class) e:SetPos(base + off) e:SetAngles(ang or Angle(0, 0, 0)) e:Spawn() e:Activate()
		BaseWars.CPPI.SetOwner(e, bot)
		local ph = e:GetPhysicsObject() if IsValid(ph) then ph:EnableMotion(false) end
		created[#created + 1] = e
		return e
	end
	make("bw_gen_gas", Vector(0, -90, 20))
	local p1 = make("bw_printer_copper", Vector(0, 0, 40))
	local p2 = make("bw_printer_gold", Vector(0, 40, 40))
	local p3 = make("bw_printer_vip0", Vector(0, 80, 40))
	local vault = make("bw_vault", Vector(-60, 0, 30), Angle(0, 0, 0))
	make("bw_vault_vip", Vector(-60, 70, 30), Angle(0, 0, 0))
	make("bw_turret_healer", Vector(-60, -60, 10))
	timer.Simple(3, function()
		if IsValid(vault) then vault.money = 123456 vault:SetNW2String("money", "123456") end
		if IsValid(p1) then p1:SetMoney(math.floor(p1:GetCapacity() * 0.42)) end
		if IsValid(p2) then p2:SetMoney(p2:GetCapacity()) end
		print(string.format("[Astral Test] Vitrine : %.0f %.0f %.0f (alimentées : %s %s %s)", base.x, base.y, base.z,
			tostring(p1:IsPowered()), tostring(p2:IsPowered()), tostring(p3:IsPowered())))
	end)
	hook.Add("SetupPlayerVisibility", "Astral.TestPrinters", function() AddOriginToPVS(base + Vector(0, 40, 60)) end)
end)
timer.Simple(125, function()
	hook.Remove("SetupPlayerVisibility", "Astral.TestPrinters")
	for _, e in ipairs(created) do if IsValid(e) then e:Remove() end end
	if IsValid(bot) then bot:Kick("Fin du test Astral") end
	print("[Astral Test] Vitrine retirée")
end)
