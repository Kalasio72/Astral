-- Astral — imprimantes et banque (serveur) : effets des améliorations, achats, récolte depuis le menu,
-- actions groupées de la Banque Astral. Définitions et coûts : sh_printers.lua.

local P = Astral.Printers
local MAX_DIST = 200 ^ 2

---------------------------------------------------------------------------
-- Effets sur l'entité
---------------------------------------------------------------------------
-- Valeurs d'origine de la machine, lues une seule fois (avant toute surcharge sur l'instance)
local function baseOf(ent)
	if not ent.AstralBase then
		ent.AstralBase = { interval = ent.PrintInterval or 1, amount = ent.PrintAmount or 8, power = ent.PowerRequired or 5 }
	end
	return ent.AstralBase
end

function P.Apply(ent)
	local b = baseOf(ent)
	ent.PrintInterval = b.interval * P.IntervalMul(ent)
	ent.PrintAmount = b.amount * P.AmountMul(ent)
	ent.PowerRequired = math.ceil(b.power * P.PowerMul(ent))   -- l'énergie est un entier (NetworkVar Int)
end

-- Début et fin d'événement : le multiplicateur « print » change, on réapplique à toutes les imprimantes
hook.Add("Astral.EventChanged", "Astral.Printers", function()
	for _, e in ipairs(ents.FindByClass("bw_printer_*")) do if P.IsPrinter(e) then P.Apply(e) end end
end)
-- Imprimante achetée pendant un événement : bonus appliqué dès l'apparition
hook.Add("OnEntityCreated", "Astral.Printers.Event", function(ent)
	timer.Simple(0.5, function()
		if P.IsPrinter(ent) and Astral.Events.Mult("print") ~= 1 then P.Apply(ent) end
	end)
end)

local function setRank(ent, id, rank)
	local old = P.Rank(ent, id)
	local u = P.ById[id]
	local oldMul, newMul = 1 + u.step * old, 1 + u.step * rank
	ent:SetNWInt("Astral.Upg." .. id, rank)
	if id == "capacity" then
		local cap = tonumber(ent:GetCapacity()) or 0
		if cap > 0 then ent:SetCapacity(math.floor(cap * newMul / oldMul)) end
	elseif id == "armor" then
		local max = ent:GetMaxHealth() > 0 and ent:GetMaxHealth() or (ent.PresetMaxHealth or 100)
		local newMax = math.floor(max * newMul / oldMul)
		ent:SetMaxHealth(newMax)
		ent.PresetMaxHealth = newMax
		ent:SetHealth(math.min(newMax, ent:Health() + (newMax - max)))
	end
	P.Apply(ent)
end

---------------------------------------------------------------------------
-- Achat d'un rang
---------------------------------------------------------------------------
local function owns(ply, ent) return (ent.CPPIGetOwner and ent:CPPIGetOwner()) == ply end

-- quiet : pas de notification (actions groupées de la banque). Retourne le coût payé, ou nil.
function P.Buy(ply, ent, id, quiet)
	local u = P.ById[id]
	if not u or not P.IsPrinter(ent) or not owns(ply, ent) then return nil end
	local cost = P.Cost(ent, id)
	if not cost then
		if not quiet then ply:Notify(u.name .. " : rang maximum atteint.", BASEWARS_NOTIFICATION_ERROR) end
		return nil
	end
	if ply:GetMoney() < cost then
		if not quiet then ply:Notify("Pas assez d'argent pour " .. u.name .. " (" .. P.Money(cost) .. ").", BASEWARS_NOTIFICATION_ERROR) end
		return nil
	end
	ply:TakeMoney(cost)
	ent.CurrentValue = (ent.CurrentValue or 0) + cost   -- valeur de la machine (remboursement SpaceVX)
	setRank(ent, id, P.Rank(ent, id) + 1)
	ent:EmitSound("replay/rendercomplete.wav", 70, 110)
	if not quiet then
		ply:Notify(string.format("%s : rang %d/%d (%s)", u.name, P.Rank(ent, id), u.max, P.Money(cost)),BASEWARS_NOTIFICATION_MONEY)
	end
	Astral.Logs.Write("upgrade", ply, { class = ent:GetClass(), kind = id, rank = P.Rank(ent, id), cost = cost })
	return cost
end

Astral.Net.Receive("Astral.Printer.Upgrade", { rate = 3, burst = 6, maxBytes = 8, alive = true }, function(ply)
	local ent, idx = net.ReadEntity(), net.ReadUInt(4)
	local u = P.Upgrades[idx]
	if not u or not IsValid(ent) or ply:GetPos():DistToSqr(ent:GetPos()) > MAX_DIST then return end
	P.Buy(ply, ent, u.id)
end)

-- Récolte depuis le menu : mêmes règles que E (hook BaseWars_PlayerCanEmptyPrinter, raids)
Astral.Net.Receive("Astral.Printer.Collect", { rate = 3, burst = 6, maxBytes = 8, alive = true }, function(ply)
	local ent = net.ReadEntity()
	if not IsValid(ent) or not ent.PlayerTakeMoney or ply:GetPos():DistToSqr(ent:GetPos()) > MAX_DIST then return end
	if (tonumber(ent:GetMoney()) or 0) > 0 then ent:PlayerTakeMoney(ply) end
end)

---------------------------------------------------------------------------
-- Banque Astral : actions groupées sur les imprimantes connectées
---------------------------------------------------------------------------
function P.Connected(bank, owner)
	local list = {}
	for _, e in ipairs(ents.FindInSphere(bank:GetPos(), bank.Radius or 1200)) do
		if P.IsPrinter(e) and owns(owner, e) then list[#list + 1] = e end
	end
	return list
end

local BANK_ACTIONS = P.BankActions

-- Améliore toutes les imprimantes connectées, des moins chères aux plus chères, tant que l'argent suffit
function P.BankAction(ply, bank, action, kind)
	if not IsValid(bank) or bank:GetClass() ~= "bw_astral_bank" or not owns(ply, bank) then return end
	if action == BANK_ACTIONS.collect then
		-- Mêmes conditions que E sur un coffre-fort SpaceVX : alimenté et en état
		if not bank:IsPowered() or bank:BadlyDamaged() then ply:Notify("Banque hors tension : récolte impossible.", BASEWARS_NOTIFICATION_ERROR) return end
		if (bank.money or 0) > 0 then bank:PlayerTakeMoney(ply) end
		return
	end
	local printers = P.Connected(bank, ply)
	local done, spent = 0, 0
	if action == BANK_ACTIONS.level then
		table.sort(printers, function(a, b) return a:GetNWInt("UpgradeCost") * a:GetLevel() < b:GetNWInt("UpgradeCost") * b:GetLevel() end)
		for _, e in ipairs(printers) do
			local before, money = e:GetLevel(), ply:GetMoney()
			if e.Upgrade and e:Upgrade(ply, true) ~= false and e:GetLevel() > before then
				done, spent = done + 1, spent + (money - ply:GetMoney())
			end
		end
		if done > 0 then Astral.Logs.Write("upgrade", ply, { via = "banque", kind = "level", count = done, cost = spent }) end
	elseif action == BANK_ACTIONS.upgrade then
		local u = P.Upgrades[kind]
		if not u then return end
		table.sort(printers, function(a, b) return (P.Cost(a, u.id) or math.huge) < (P.Cost(b, u.id) or math.huge) end)
		for _, e in ipairs(printers) do
			local c = P.Buy(ply, e, u.id, true)
			if c then done, spent = done + 1, spent + c end
		end
	end
	if done > 0 then
		ply:Notify(string.format("Banque : %d imprimante(s) améliorée(s) pour %s", done, P.Money(spent)),BASEWARS_NOTIFICATION_MONEY)
	else
		ply:Notify("Banque : aucune amélioration possible (argent insuffisant ou maximum atteint).", BASEWARS_NOTIFICATION_ERROR)
	end
	return done, spent
end

Astral.Net.Receive("Astral.Bank.Action", { rate = 1, burst = 3, maxBytes = 8, alive = true }, function(ply)
	local bank, action, kind = net.ReadEntity(), net.ReadUInt(3), net.ReadUInt(4)
	if not IsValid(bank) or ply:GetPos():DistToSqr(bank:GetPos()) > MAX_DIST then return end
	P.BankAction(ply, bank, action, kind)
end)
