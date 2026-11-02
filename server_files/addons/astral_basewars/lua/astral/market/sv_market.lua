-- Astral Market — marché entre joueurs (ressources Astral Industries contre argent).
--
-- Mise en vente : les unités sont retirées des conteneurs du vendeur et placées sous séquestre dans la ligne
-- astral_market (qty_left) ; elles ne peuvent donc plus être volées en raid ni vendues deux fois.
-- Achat : l'argent est débité, les unités livrées dans les conteneurs de l'acheteur, puis la ligne est mise à jour
-- par une requête CONDITIONNELLE (status = 0 AND qty_left >= n). Si la base refuse (offre déjà vendue/annulée,
-- erreur), tout est annulé : argent rendu, unités reprises. Une offre en cours de traitement est verrouillée.
-- Paiement du vendeur : le produit (moins la taxe) s'accumule dans proceeds et lui est versé dès qu'il est
-- connecté (immédiatement, ou à sa prochaine connexion), par une remise à zéro conditionnelle : jamais deux fois.
-- Annulation : mise à jour conditionnelle puis restitution des unités dans ses conteneurs.

Astral.Market = Astral.Market or {}
local M = Astral.Market
local R, I = Astral.Resources, Astral.Inv
M.Orders = M.Orders or {}
util.AddNetworkString("Astral.Market.Sync")

local function cfg(k, d) return Astral.Cfg("Market." .. k, d) end
local function sidOf(ply) local s = IsValid(ply) and ply:SteamID64() return s and tostring(s):match("^%d+$") and s or nil end
local function money(n) return BaseWars.LANG.CURRENCY .. BaseWars.NumberFormat(n) end
local function bySid(sid) for _, p in player.Iterator() do if sidOf(p) == sid then return p end end end

---------------------------------------------------------------------------
-- Conteneurs du joueur
---------------------------------------------------------------------------
local function boxes(ply)
	local list = {}
	for _, b in ipairs(ents.FindByClass("astral_container")) do
		if b.AstralStore and BaseWars.CPPI.GetOwner(b) == ply then list[#list + 1] = b end
	end
	return list
end

local function capacity(ply, box)
	return Astral.Cfg("Industry.ContainerCapacity", 500) + Astral.Research.Add(ply, "capacity") - I.Count(box.AstralStore)
end

local function stock(ply)
	local s = {}
	for _, b in ipairs(boxes(ply)) do for id, q in pairs(b.AstralStore) do s[id] = (s[id] or 0) + q end end
	return s
end

local function room(ply)
	local n = 0
	for _, b in ipairs(boxes(ply)) do n = n + math.max(0, capacity(ply, b)) end
	return n
end

-- Retire n unités ; renvoie la liste des retraits (pour restitution) ou nil si le stock est insuffisant
local function take(ply, res, n)
	if (stock(ply)[res] or 0) < n then return nil end
	local taken = {}
	for _, b in ipairs(boxes(ply)) do
		if n <= 0 then break end
		local k = math.min(n, b.AstralStore[res] or 0)
		if k > 0 then I.Add(b.AstralStore, res, -k) taken[#taken + 1] = { b, k } n = n - k b:AstralSync() end
	end
	return taken
end

local function untake(res, taken)
	for _, t in ipairs(taken) do if IsValid(t[1]) then I.Add(t[1].AstralStore, res, t[2]) t[1]:AstralSync() end end
end

-- Livre n unités : d'abord dans la place libre, le reste dans le premier conteneur (dépassement toléré, rien ne se perd)
local function give(ply, res, n)
	local list = boxes(ply)
	if #list == 0 then return false end
	for _, b in ipairs(list) do
		local k = math.min(n, math.max(0, capacity(ply, b)))
		if k > 0 then I.Add(b.AstralStore, res, k) n = n - k b:AstralSync() end
		if n <= 0 then break end
	end
	if n > 0 then I.Add(list[1].AstralStore, res, n) list[1]:AstralSync() end
	return true
end

---------------------------------------------------------------------------
-- Synchronisation
---------------------------------------------------------------------------
function M.Sync(ply)
	if not IsValid(ply) then return end
	local list, mine, sid = {}, {}, sidOf(ply)
	for _, o in pairs(M.Orders) do
		local row = { id = o.id, r = o.resource, q = o.qty_left, p = o.unit_price, s = o.seller_name, t = o.created_at }
		if o.seller == sid then mine[#mine + 1] = row else list[#list + 1] = row end
	end
	local order = {}
	for i, id in ipairs(R.order) do order[id] = i end
	local function cmp(a, b)
		if a.r ~= b.r then return (order[a.r] or 999) < (order[b.r] or 999) end
		return a.p < b.p
	end
	table.sort(list, cmp) table.sort(mine, cmp)
	while #list > 150 do table.remove(list) end
	net.Start("Astral.Market.Sync")
	net.WriteTable(list) net.WriteTable(mine) net.WriteTable(stock(ply))
	net.Send(ply)
end

local function syncAll() for _, p in player.Iterator() do if p.AstralMarketOpen then M.Sync(p) end end end

---------------------------------------------------------------------------
-- Paiement des vendeurs
---------------------------------------------------------------------------
function M.Payout(ply)
	local sid = sidOf(ply)
	local db = Astral.DB.Conn()
	if not sid or not db or ply.AstralPayoutBusy then return end
	ply.AstralPayoutBusy = true
	db:Fetch("SELECT id, proceeds FROM astral_market WHERE seller = {1} AND proceeds > 0", { params = { sid }, callback = function(err, rows)
		if err or not rows or #rows == 0 then ply.AstralPayoutBusy = nil return end
		local left, total = #rows, 0
		for _, r in ipairs(rows) do
			local amount = tonumber(r.proceeds) or 0
			db:Execute("UPDATE astral_market SET proceeds = 0 WHERE id = {1} AND proceeds = {2}", { params = { r.id, amount }, callback = function(e, res)
				if not e and res and res.rows_affected == 1 and IsValid(ply) then
					ply:GiveMoney(amount)
					total = total + amount
					Astral.Logs.Write("market_payout", ply, { order = r.id, amount = amount })
				end
				left = left - 1
				if left == 0 then
					if IsValid(ply) then
						ply.AstralPayoutBusy = nil
						if total > 0 then ply:Notify("Marché : " .. money(total) .. " reçus pour tes ventes.", BASEWARS_NOTIFICATION_MONEY) end
					end
				end
			end })
		end
	end })
end

---------------------------------------------------------------------------
-- Actions des joueurs
---------------------------------------------------------------------------
local function err(ply, msg) ply:Notify(msg, BASEWARS_NOTIFICATION_ERROR) end

function M.Sell(ply, resId, qty, price)
	local res, sid = R.Get(resId), sidOf(ply)
	if not res or not sid or not Astral.DB.Ready or ply.AstralMarketBusy then return end
	if qty < 1 or qty > cfg("MaxQty", 500) then return err(ply, "Quantité invalide (1 à " .. cfg("MaxQty", 500) .. ").") end
	local minP, maxP = math.max(1, math.ceil(res.value * cfg("MinPriceFactor", 0.25))), math.floor(res.value * cfg("MaxPriceFactor", 10))
	if price < minP or price > maxP then return err(ply, string.format("Prix unitaire autorisé pour %s : %s à %s.", res.name, money(minP), money(maxP))) end
	local open = 0
	for _, o in pairs(M.Orders) do if o.seller == sid then open = open + 1 end end
	if open >= cfg("MaxOrders", 5) then return err(ply, "Tu as déjà " .. open .. " offres ouvertes (maximum atteint).") end
	local taken = take(ply, resId, qty)
	if not taken then return err(ply, "Pas assez de " .. res.name .. " dans tes conteneurs.") end
	ply.AstralMarketBusy = true
	local now, name = os.time(), string.sub(ply:Nick(), 1, 64)
	Astral.DB.Conn():Execute("INSERT INTO astral_market (seller, seller_name, resource, qty_total, qty_left, unit_price, created_at) VALUES ({1}, {2}, {3}, {4}, {4}, {5}, {6})", {
		params = { sid, name, resId, qty, price, now },
		callback = function(e, r)
			if IsValid(ply) then ply.AstralMarketBusy = nil end
			local id = not e and r and tonumber(r.last_insert_id)
			if not id or id == 0 then
				untake(resId, taken)
				Astral.Log("market", "ERREUR mise en vente : " .. tostring(e))
				if IsValid(ply) then err(ply, "Erreur d'enregistrement : ressources rendues.") end
				return
			end
			M.Orders[id] = { id = id, seller = sid, seller_name = name, resource = resId, qty_total = qty, qty_left = qty, unit_price = price, created_at = now }
			Astral.Logs.Write("market_list", ply, { order = id, resource = resId, qty = qty, price = price })
			if IsValid(ply) then ply:Notify(string.format("Offre publiée : %d × %s à %s l'unité.", qty, res.name, money(price)), BASEWARS_NOTIFICATION_GENRL) end
			syncAll()
		end,
	})
end

function M.Buy(ply, id, qty)
	local o, sid = M.Orders[id], sidOf(ply)
	if not o or not sid or o.pending then return err(ply, "Cette offre n'est plus disponible.") end
	if o.seller == sid then return err(ply, "Tu ne peux pas acheter ta propre offre.") end
	if qty < 1 or qty > o.qty_left then return err(ply, "Quantité invalide.") end
	if #boxes(ply) == 0 then return err(ply, "Il te faut un conteneur industriel pour recevoir tes achats.") end
	if room(ply) < qty then return err(ply, "Pas assez de place dans tes conteneurs.") end
	local cost = qty * o.unit_price
	if ply:GetMoney() < cost then return err(ply, "Pas assez d'argent (" .. money(cost) .. ").") end
	local tax = math.floor(cost * cfg("TaxPercent", 5) / 100)
	o.pending = true
	ply:TakeMoney(cost)
	give(ply, o.resource, qty)
	Astral.DB.Conn():Execute([[UPDATE astral_market SET qty_left = qty_left - {2}, proceeds = proceeds + {3},
		status = IF(qty_left = 0, 1, 0), closed_at = IF(qty_left = 0, {4}, NULL)
		WHERE id = {1} AND status = 0 AND qty_left >= {2}]], {
		params = { id, qty, cost - tax, os.time() },
		callback = function(e, r)
			o.pending = nil
			if e or not r or r.rows_affected ~= 1 then
				-- Annulation complète : argent rendu, unités reprises
				if IsValid(ply) then
					ply:GiveMoney(cost)
					take(ply, o.resource, math.min(qty, stock(ply)[o.resource] or 0))
					err(ply, "Achat impossible (offre modifiée entre-temps) : argent rendu.")
				end
				Astral.Log("market", "Achat refusé par la base (offre " .. id .. ") : " .. tostring(e))
				return
			end
			o.qty_left = o.qty_left - qty
			if o.qty_left <= 0 then M.Orders[id] = nil end
			local res = R.Get(o.resource)
			Astral.Logs.Write("market_buy", ply, { order = id, seller = o.seller, resource = o.resource, qty = qty, cost = cost, tax = tax })
			if IsValid(ply) then ply:Notify(string.format("Acheté %d × %s pour %s.", qty, res.name, money(cost)), BASEWARS_NOTIFICATION_MONEY) end
			local seller = bySid(o.seller)
			if IsValid(seller) then
				seller:Notify(string.format("Marché : %s a acheté %d × %s.", IsValid(ply) and ply:Nick() or "?", qty, res.name), BASEWARS_NOTIFICATION_GENRL)
				M.Payout(seller)
			end
			hook.Run("Astral.MarketSold", o.seller, ply, o.resource, qty, cost)
			syncAll()
		end,
	})
end

function M.Cancel(ply, id)
	local o, sid = M.Orders[id], sidOf(ply)
	if not o or o.seller ~= sid or o.pending then return end
	if #boxes(ply) == 0 then return err(ply, "Il te faut un conteneur industriel pour récupérer tes ressources.") end
	o.pending = true
	local left = o.qty_left
	Astral.DB.Conn():Execute("UPDATE astral_market SET status = 2, qty_left = 0, closed_at = {3} WHERE id = {1} AND status = 0 AND qty_left = {2}", {
		params = { id, left, os.time() },
		callback = function(e, r)
			o.pending = nil
			if e or not r or r.rows_affected ~= 1 then
				if IsValid(ply) then err(ply, "Annulation impossible pour le moment.") end
				return
			end
			M.Orders[id] = nil
			local ok = IsValid(ply) and give(ply, o.resource, left)
			Astral.Logs.Write("market_cancel", ply, { order = id, resource = o.resource, qty = left, returned = ok and true or false })
			if not ok then Astral.Log("market", "ATTENTION : offre " .. id .. " annulée sans conteneur pour restituer " .. left .. " × " .. o.resource) end
			if IsValid(ply) then
				ply:Notify(string.format("Offre retirée : %d × %s rendus dans tes conteneurs.", left, R.Get(o.resource).name), BASEWARS_NOTIFICATION_GENRL)
				M.Payout(ply)
			end
			syncAll()
		end,
	})
end

Astral.Net.Receive("Astral.Market.Sell", { rate = 1, burst = 2, maxBytes = 64, alive = true }, function(ply)
	M.Sell(ply, net.ReadString(), net.ReadUInt(16), net.ReadUInt(32))
end)
Astral.Net.Receive("Astral.Market.Buy", { rate = 2, burst = 4, maxBytes = 16, alive = true }, function(ply)
	M.Buy(ply, net.ReadUInt(32), net.ReadUInt(16))
end)
Astral.Net.Receive("Astral.Market.Cancel", { rate = 1, burst = 3, maxBytes = 8, alive = true }, function(ply)
	M.Cancel(ply, net.ReadUInt(32))
end)

Astral.Net.Receive("Astral.Market.Request", { rate = 1, burst = 3, maxBytes = 8 }, function(ply)
	ply.AstralMarketOpen = true
	M.Sync(ply)
	M.Payout(ply)
end)
Astral.Net.Receive("Astral.Market.Close", { rate = 2, burst = 4, maxBytes = 8 }, function(ply) ply.AstralMarketOpen = nil end)

---------------------------------------------------------------------------
-- Démarrage et connexions
---------------------------------------------------------------------------
Astral.DB.OnReady(function(db)
	db:Fetch("SELECT id, seller, seller_name, resource, qty_total, qty_left, unit_price, created_at FROM astral_market WHERE status = 0 AND qty_left > 0", { callback = function(e, rows)
		if e then return Astral.Log("market", "ERREUR chargement : " .. tostring(e)) end
		M.Orders = {}
		for _, r in ipairs(rows or {}) do
			if R.Get(r.resource) then
				local id = tonumber(r.id)
				M.Orders[id] = { id = id, seller = r.seller, seller_name = r.seller_name, resource = r.resource, qty_total = tonumber(r.qty_total),
					qty_left = tonumber(r.qty_left), unit_price = tonumber(r.unit_price), created_at = tonumber(r.created_at) }
			end
		end
		Astral.Log("market", table.Count(M.Orders) .. " offre(s) ouverte(s) chargée(s)")
	end })
end)

-- Versement des ventes faites pendant l'absence (après le chargement de l'argent par BaseWars)
hook.Add("PlayerInitialSpawn", "Astral.Market", function(ply)
	timer.Simple(15, function() if IsValid(ply) then Astral.DB.OnReady(function() M.Payout(ply) end) end end)
end)
