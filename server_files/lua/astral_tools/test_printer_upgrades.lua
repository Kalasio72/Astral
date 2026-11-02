-- Test des améliorations Astral des imprimantes et de la Banque Astral (sh_printers.lua, sv_printers.lua) avec
-- deux bots : imprimantes, banque et argent des bots uniquement. Le compte du propriétaire n'est pas touché.
-- Tout est supprimé à la fin. Console serveur : lua_openscript astral_tools/test_printer_upgrades.lua
local function out(ok, msg) print(string.format("[Astral Test] %s %s", ok and "OK   " or "ECHEC", msg)) end
local P = Astral and Astral.Printers
if not (P and P.Buy and P.BankAction) then return out(false, "module Astral.Printers absent") end
RunConsoleCommand("sv_hibernate_think", "1")
local bot = player.CreateNextBot("ImprimanteTest")
local rival = player.CreateNextBot("RivalTest")
local created = {}
local function finish()
	for _, e in ipairs(created) do if IsValid(e) then e:Remove() end end
	if IsValid(bot) then bot:Kick("Fin du test imprimantes") end
	if IsValid(rival) then rival:Kick("Fin du test imprimantes") end
end
local function near(a, b) return math.abs(a - b) < 0.001 end

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
	rival:SetPos(base + Vector(-80, 60, 5))
	local function make(class, off, owner)
		local e = ents.Create(class) e:SetPos(base + off) e:Spawn() e:Activate()
		BaseWars.CPPI.SetOwner(e, owner or bot)
		local ph = e:GetPhysicsObject() if IsValid(ph) then ph:EnableMotion(false) end
		created[#created + 1] = e
		return e
	end
	local p1 = make("bw_printer_gold", Vector(0, 0, 10))
	local p2 = make("bw_printer_copper", Vector(0, 50, 10))
	local bank = make("bw_astral_bank", Vector(0, -80, 25))

	timer.Simple(1, function()
		if not (IsValid(p1) and IsValid(p2) and IsValid(bank)) then finish() return out(false, "entités retirées après leur apparition") end
		-- Modèle
		local stored = scripted_ents.GetStored("bw_printer_gold")
		out(stored.t.Model == P.Model and p1:GetModel() == P.Model, "modèle unifié : " .. p1:GetModel())

		local uc = p1:GetNWInt("UpgradeCost")
		local i0, a0, w0, c0, h0 = p1.PrintInterval, p1.PrintAmount, p1.PowerRequired, p1:GetCapacity(), p1:GetMaxHealth()
		bot:SetMoney(1e9)

		-- Vitesse
		local m = bot:GetMoney()
		local cost = P.Buy(bot, p1, "speed")
		out(cost == uc * 4 and bot:GetMoney() == m - cost and P.Rank(p1, "speed") == 1, "vitesse rang 1 : coût " .. tostring(cost) .. " (attendu " .. uc * 4 .. ")")
		out(near(p1.PrintInterval, i0 * 0.9), string.format("intervalle %.3f → %.3f (−10 %%)", i0, p1.PrintInterval))
		local cost2 = P.Buy(bot, p1, "speed")
		out(cost2 == uc * 4 * 2 and near(p1.PrintInterval, i0 * 0.8), "vitesse rang 2 : coût ×2, intervalle −20 %")

		-- Overclock
		P.Buy(bot, p1, "overclock")
		out(near(p1.PrintAmount, a0 * 1.25) and p1.PowerRequired == math.ceil(w0 * 1.5), string.format("overclock : production %g → %g, énergie %g → %g", a0, p1.PrintAmount, w0, p1.PowerRequired))
		out(near(p1.PrintInterval, i0 * 0.8), "overclock sans effet sur l'intervalle")

		-- Capacité
		P.Buy(bot, p1, "capacity")
		out(p1:GetCapacity() == math.floor(c0 * 1.5), string.format("capacité %d → %d (+50 %%)", c0, p1:GetCapacity()))

		-- Blindage
		P.Buy(bot, p1, "armor")
		out(p1:GetMaxHealth() == math.floor(h0 * 1.5) and p1:Health() == p1:GetMaxHealth(), string.format("blindage : PV max %d → %d", h0, p1:GetMaxHealth()))
		P.Buy(bot, p1, "armor") P.Buy(bot, p1, "armor")
		m = bot:GetMoney()
		out(P.Rank(p1, "armor") == 3 and P.Buy(bot, p1, "armor") == nil and bot:GetMoney() == m, "blindage au rang max (3) : achat suivant refusé, argent intact")

		-- Production par minute cohérente avec la formule SpaceVX
		local expect = math.Round(stored.t.PrintAmount * 1.25 * (p1:GetLevel() ^ 1.3)) * 60 / (stored.t.PrintInterval * 0.8)
		out(near(P.PerMinute(p1), expect), "production / min : " .. P.Money(P.PerMinute(p1)))

		-- Argent insuffisant
		bot:SetMoney(5)
		out(P.Buy(bot, p1, "capacity") == nil and bot:GetMoney() == 5 and P.Rank(p1, "capacity") == 1, "argent insuffisant : refusé, argent intact")

		-- Machine d'un autre joueur
		rival:SetMoney(1e9)
		out(P.Buy(rival, p1, "speed") == nil and rival:GetMoney() == 1e9 and P.Rank(p1, "speed") == 2, "imprimante d'un autre joueur : refusé, argent du rival intact")

		-- Banque
		local list = P.Connected(bank, bot)
		out(#list == 2, "banque : " .. #list .. " imprimante(s) connectée(s) (attendu 2)")
		bot:SetMoney(1e9)
		local l1, l2 = p1:GetLevel(), p2:GetLevel()
		local done = P.BankAction(bot, bank, P.BankActions.level, 0)
		out(done == 2 and p1:GetLevel() == l1 + 1 and p2:GetLevel() == l2 + 1, "banque, niveau +1 : " .. tostring(done) .. " imprimante(s)")
		local r1, r2 = P.Rank(p1, "capacity"), P.Rank(p2, "capacity")
		done = P.BankAction(bot, bank, P.BankActions.upgrade, P.ById.capacity.index)
		out(done == 2 and P.Rank(p1, "capacity") == r1 + 1 and P.Rank(p2, "capacity") == r2 + 1, "banque, capacité pour toutes : " .. tostring(done))
		out(P.BankAction(rival, bank, P.BankActions.level, 0) == nil, "banque d'un autre joueur : refusée")
		bank:SetPower(bank:GetMaxPower())
		bank.money = 12345
		m = bot:GetMoney()
		P.BankAction(bot, bank, P.BankActions.collect, 0)
		out(bot:GetMoney() == m + 12345 and bank.money == 0, "banque, récolte : +12 345, banque vidée")

		-- Récolte depuis le menu
		p2:SetMoney(777)
		m = bot:GetMoney()
		p2:PlayerTakeMoney(bot)
		out(bot:GetMoney() == m + 777, "récolte d'une imprimante : +777")
		finish()
		print("[Astral Test] Fin du test imprimantes")
	end)
end)
