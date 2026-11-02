-- Astral BaseWars — vitrine des habillages (sh_looks.lua) : une machine de chaque famille, appartenant à un bot,
-- posée en ligne près du premier joueur connecté (hors zones trigger_remove), retirée après 240 s.
-- Aucun compte de vrai joueur n'est modifié. Console serveur : lua_openscript astral_tools/test_looks.lua
RunConsoleCommand("sv_hibernate_think", "1")
local CLASSES = {
	"bw_gen_gas", "bw_gen_fusion", "bw_vault", "bw_dispenser_ammo", "bw_dispenser_armor", "bw_dispenser_paper",
	"bw_spawnpoint", "astral_drill", "astral_refinery", "astral_container", "astral_fabricator", "astral_greenhouse",
	"astral_battery", "bw_printer_gold",
}
local bot = player.CreateNextBot("AstralVitrine")
local created = {}
timer.Simple(4, function()
	local ref = player.GetHumans()[1] or bot
	if not IsValid(bot) then return print("[Astral Test] ECHEC : bot absent") end
	local zones = {}
	for _, t in ipairs(ents.FindByClass("trigger_remove")) do local a, b = t:WorldSpaceAABB() zones[#zones + 1] = { a, b } end
	local function inZone(p) for _, z in ipairs(zones) do if p:WithinAABox(z[1], z[2]) then return true end end return false end
	local fwd = ref:GetForward() fwd.z = 0 fwd:Normalize()
	local right = fwd:Cross(Vector(0, 0, 1))
	local base
	for dist = 150, 1500, 50 do
		local p = ref:GetPos() + fwd * dist + Vector(0, 0, 100)
		local tr = util.TraceLine({ start = p, endpos = p - Vector(0, 0, 500) })
		if tr.Hit and not tr.StartSolid and not inZone(tr.HitPos) then base = tr.HitPos break end
	end
	if not base then bot:Kick("Fin") return print("[Astral Test] ECHEC : aucun emplacement libre") end
	for i, class in ipairs(CLASSES) do
		local col, row = (i - 1) % 7, math.floor((i - 1) / 7)
		local e = ents.Create(class)
		if IsValid(e) then
			e:SetPos(base + right * ((col - 3) * 70) + fwd * (row * 90) + Vector(0, 0, 40))
			e:SetAngles(Angle(0, fwd:Angle().y + 180, 0))
			e:Spawn() e:Activate()
			BaseWars.CPPI.SetOwner(e, bot)
			local ph = e:GetPhysicsObject() if IsValid(ph) then ph:EnableMotion(false) end
			created[#created + 1] = e
			print(string.format("[Astral Test] %s : %s", class, e:GetModel()))
		else
			print("[Astral Test] ECHEC : " .. class .. " non créé")
		end
	end
	print(string.format("[Astral Test] Vitrine : %.0f %.0f %.0f", base.x, base.y, base.z))
	hook.Add("SetupPlayerVisibility", "Astral.TestLooks", function() AddOriginToPVS(base + Vector(0, 0, 60)) end)
end)
timer.Simple(244, function()
	hook.Remove("SetupPlayerVisibility", "Astral.TestLooks")
	for _, e in ipairs(created) do if IsValid(e) then e:Remove() end end
	if IsValid(bot) then bot:Kick("Fin de la vitrine Astral") end
	print("[Astral Test] Vitrine retirée")
end)
