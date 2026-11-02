-- Test du système d'amélioration (sv_upgrade.lua) avec un bot : imprimante de test et argent du bot uniquement.
-- Le compte du propriétaire n'est pas touché. Le bot et l'imprimante sont supprimés à la fin.
-- Console serveur : lua_openscript astral_tools/test_upgrade.lua
local function out(ok, msg) print(string.format("[Astral Test] %s %s", ok and "OK   " or "ECHEC", msg)) end
if not (Astral.Upgrade and Astral.Upgrade.Do) then return out(false, "module absent") end
RunConsoleCommand("sv_hibernate_think", "1")
local bot = player.CreateNextBot("AmeliorationTest")
timer.Simple(3, function()
	if not IsValid(bot) then return out(false, "bot absent") end
	-- Emplacement hors des zones « trigger_remove » de la carte (le point d'apparition supprime les objets)
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
	if not base then bot:Kick("Fin du test") return out(false, "aucun emplacement libre") end
	bot:SetPos(base + Vector(-60, 0, 5))
	local pr = ents.Create("bw_printer_obsidian")
	if not IsValid(pr) then bot:Kick("Fin du test") return out(false, "imprimante non créée") end
	pr:SetPos(base + Vector(0, 0, 10)) pr:Spawn() pr:Activate()
	BaseWars.CPPI.SetOwner(pr, bot)
	local ph = pr:GetPhysicsObject() if IsValid(ph) then ph:EnableMotion(false) end
	timer.Simple(1, function()
		if not IsValid(pr) then bot:Kick("Fin du test") return out(false, "imprimante retirée juste après son apparition") end
		local base = pr:GetNWInt("UpgradeCost", 0)
		bot:SetMoney(base * 3 + 1)   -- de quoi payer les niveaux 1→2 (coût base×1) et 2→3 (base×2), pas 3→4
		out(pr:GetLevel() == 1, "imprimante au niveau 1 (coût de base " .. base .. ")")
		local g1 = Astral.Upgrade.Do(bot, pr, 1)
		out(g1 == 1 and pr:GetLevel() == 2 and bot:GetMoney() == base * 2 + 1, "+1 niveau : niveau 2, argent débité de " .. base)
		local g5 = Astral.Upgrade.Do(bot, pr, 5)
		out(g5 == 1 and pr:GetLevel() == 3 and bot:GetMoney() == 1, "+5 niveaux avec un budget limité : s'arrête au niveau 3, reste 1")
		out(Astral.Upgrade.Do(bot, pr, 7) == 0, "quantité invalide (7) refusée")
		local other = player.GetHumans()[1]
		if IsValid(other) then
			local m = other:GetMoney()
			out(Astral.Upgrade.Do(other, pr, 1) == 0 and other:GetMoney() == m and pr:GetLevel() == 3, "machine d'un autre joueur refusée, son argent intact")
		end
		pr:Remove()
		bot:Kick("Fin du test amélioration")
	end)
end)
