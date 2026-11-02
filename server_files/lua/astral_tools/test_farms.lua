-- Test des fermes Astral, du sac, du receleur, de l'événement « Frénésie d'impression » et de !donner, avec deux
-- bots. Aucun compte de vrai joueur n'est modifié ; tout est supprimé à la fin.
-- Console serveur : lua_openscript astral_tools/test_farms.lua
local function out(ok, msg) print(string.format("[Astral Test] %s %s", ok and "OK   " or "ECHEC", msg)) end
local F, E = Astral.Farms, Astral.Events
if not (F and F.Collect and E) then return out(false, "modules absents") end
if E.Current() then return out(false, "un événement est en cours : test annulé") end
RunConsoleCommand("sv_hibernate_think", "1")
local bot = player.CreateNextBot("FermeTest")
local rival = player.CreateNextBot("RivalFerme")
local created = {}
local function finish()
	for _, e in ipairs(created) do if IsValid(e) then e:Remove() end end
	for _, e in ipairs(ents.FindByClass("astral_bag")) do e:Remove() end
	if IsValid(bot) then bot:Kick("Fin du test fermes") end
	if IsValid(rival) then rival:Kick("Fin du test fermes") end
	print("[Astral Test] Fin du test fermes")
end

timer.Simple(3, function()
	if not IsValid(bot) or not IsValid(rival) then finish() return out(false, "bots absents") end
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
	if not base then finish() return out(false, "aucun emplacement libre") end
	bot:SetPos(base + Vector(-80, 0, 5))
	rival:SetPos(base + Vector(-80, 80, 5))
	local function make(class, off, owner)
		local e = ents.Create(class) e:SetPos(base + off) e:Spawn() e:Activate()
		BaseWars.CPPI.SetOwner(e, owner or bot)
		local ph = e:GetPhysicsObject() if IsValid(ph) then ph:EnableMotion(false) end
		created[#created + 1] = e
		return e
	end
	local weed = make("astral_farm_weed", Vector(0, 0, 20))
	local meth = make("astral_farm_meth", Vector(0, 300, 20))
	local printer = make("bw_printer_gold", Vector(0, -80, 20))

	timer.Simple(1, function()
		if not (IsValid(weed) and IsValid(meth) and IsValid(printer)) then finish() return out(false, "entités retirées après apparition") end
		out(weed.Farm and weed:GetModel() == "models/hunter/blocks/cube05x1x05.mdl", "ferme créée : " .. weed:GetClass() .. " (" .. weed:GetModel() .. ")")

		-- Production : un lot quand la progression dépasse 1
		weed.progress, weed.elapsed = 0.999, 1
		weed:ThinkFunc()
		out(weed:GetNW2Int("AstralFarmStock") == 1, "production d'un lot (stock 1)")

		-- Récolte : 1 lot = 6 unités de cannabis dans le sac
		bot.AstralBag = {}
		local got = F.Collect(bot, weed)
		out(got == 6 and (bot.AstralBag.weed or 0) == 6 and weed:GetNW2Int("AstralFarmStock") == 0, "récolte : +6 cannabis dans le sac, stock vidé")
		out(bot:GetNW2String("AstralBag") == "weed=6", "sac diffusé : " .. bot:GetNW2String("AstralBag"))

		-- Ferme d'un autre joueur : refusée
		weed:SetNW2Int("AstralFarmStock", 2)
		out(F.Collect(rival, weed) == 0 and weed:GetNW2Int("AstralFarmStock") == 2, "récolte de la ferme d'un autre joueur refusée")

		-- Sac plein : lot entier uniquement
		bot.AstralBag = { weed = 58 }
		out(F.Collect(bot, weed) == 0 and weed:GetNW2Int("AstralFarmStock") == 2, "sac presque plein (58/60) : lot de 6 refusé")

		-- Labo de méthamphétamine : purge puis explosion à 100 °C
		meth.heat, meth.elapsed = 95, 0
		meth:Vent()
		out(meth.heat == 20 and meth:GetNW2Float("AstralFarmHeat") == 20, "purge : cuve à 20 °C")
		meth.heat, meth.elapsed = 99.9, 1
		meth:ThinkFunc()
		timer.Simple(0.2, function()
			out(not IsValid(meth), "surchauffe : le labo explose au-delà de 100 °C")

			-- Receleur
			local dealer
			for _, n in ipairs(ents.FindByClass("astral_npc")) do if n:GetRole() == "dealer" then dealer = n end end
			if IsValid(dealer) then
				local oldPos = bot:GetPos()
				bot:SetPos(dealer:GetPos() + dealer:GetForward() * 60)
				bot.AstralBag = { weed = 6, meth = 1 }
				local m = bot:GetMoney()
				local paid = F.Sell(bot, dealer)
				out(paid == 6 * 600 + 12000 and bot:GetMoney() == m + paid and F.BagCount(bot.AstralBag) == 0, "receleur : " .. Astral.Printers.Money(paid) .. " payés, sac vidé")
				bot:SetPos(oldPos)
				out(F.Sell(bot, dealer) == 0, "receleur hors de portée : vente refusée")
			else
				out(false, "receleur introuvable (astral_npc rôle dealer)")
			end

			-- Mort : le sac tombe, un autre joueur le ramasse
			bot.AstralBag = { tobacco = 8 }
			F.SyncBag(bot)
			bot:Kill()
			timer.Simple(0.3, function()
				local bag = ents.FindByClass("astral_bag")[1]
				out(IsValid(bag) and bag.Contents.tobacco == 8 and F.BagCount(bot.AstralBag) == 0, "mort : sac lâché au sol (8 tabac), sac du joueur vidé")
				if IsValid(bag) then
					rival.AstralBag = {}
					bag:Use(rival, rival)
					out((rival.AstralBag.tobacco or 0) == 8, "sac ramassé par un autre joueur")
				end

				-- Événement « Frénésie d'impression » : production ×2 puis retour à la normale
				local before = printer.PrintAmount
				E.Start("print_frenzy", nil, 60)
				local during = printer.PrintAmount
				E.Stop()
				local after = printer.PrintAmount
				out(during == before * 2 and after == before, string.format("événement imprimantes : %g → %g → %g", before, during, after))

				-- !donner
				rival:SetMoney(0)
				bot:SetMoney(1000)
				hook.GetTable().PlayerSay["Astral.Commands"](bot, "!donner RivalFerme 250")
				out(bot:GetMoney() == 750 and rival:GetMoney() == 250, "!donner : 250 transférés")
				hook.GetTable().PlayerSay["Astral.Commands"](bot, "!donner RivalFerme 99999")
				out(bot:GetMoney() == 750, "!donner au-delà de son argent : refusé")
				finish()
			end)
		end)
	end)
end)
