-- Astral BaseWars — test du marché entre joueurs avec deux bots (aucun vrai joueur touché).
-- Console serveur : lua_openscript astral_tools/test_market.lua
-- Vérifie : mise en vente (séquestre), prix hors bornes refusé, achat de sa propre offre refusé, achat partiel,
-- taxe et paiement du vendeur, double achat simultané (verrou), quantité excessive refusée, annulation et restitution.
-- Laisse en base une offre de test annulée (astral_market) et les comptes BaseWars des deux bots.
RunConsoleCommand("sv_hibernate_think", "1")
local M = Astral.Market
if not M or not M.Sell then return print("[Astral Test] ECHEC : module marché absent") end
local function out(ok, msg) print(string.format("[Astral Test] %s %s", ok and "OK   " or "ECHEC", msg)) end
local seller = player.CreateNextBot("AstralVendeur")
local buyer = player.CreateNextBot("AstralAcheteur")
local created = {}
local sBox, bBox, id, sMoney0, bMoney0

local function inv(box) return IsValid(box) and box.AstralStore and box.AstralStore.iron_ingot or 0 end

timer.Simple(6, function()
	if not IsValid(seller) or not IsValid(buyer) then return out(false, "bots absents") end
	local zones = {}
	for _, t in ipairs(ents.FindByClass("trigger_remove")) do local a, b = t:WorldSpaceAABB() zones[#zones + 1] = { a, b } end
	local function inZone(p) for _, z in ipairs(zones) do if p:WithinAABox(z[1], z[2]) then return true end end return false end
	local base
	for dist = 600, 3000, 200 do
		for _, dir in ipairs({ Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0) }) do
			local p = seller:GetPos() + dir * dist + Vector(0, 0, 200)
			local tr = util.TraceLine({ start = p, endpos = p - Vector(0, 0, 1000) })
			if tr.Hit and not tr.StartSolid and not inZone(tr.HitPos) then base = tr.HitPos break end
		end
		if base then break end
	end
	if not base then return out(false, "aucun emplacement libre") end
	local function box(owner, off)
		local e = ents.Create("astral_container") e:SetPos(base + off + Vector(0, 0, 40)) e:Spawn() e:Activate()
		BaseWars.CPPI.SetOwner(e, owner)
		local ph = e:GetPhysicsObject() if IsValid(ph) then ph:EnableMotion(false) end
		created[#created + 1] = e
		return e
	end
	sBox, bBox = box(seller, Vector(0, 0, 0)), box(buyer, Vector(0, 0, 160))   -- empilés : même emplacement libre vérifié
	sBox.AstralStore = { iron_ingot = 30 } sBox:AstralSync()
	if buyer:GetMoney() < 5000 then buyer:GiveMoney(5000) end
	sMoney0, bMoney0 = seller:GetMoney(), buyer:GetMoney()
	M.Sell(seller, "iron_ingot", 20, 50)
	out(inv(sBox) == 10, "mise en vente de 20 lingots : retirés du conteneur (reste " .. inv(sBox) .. ")")
end)

timer.Simple(9, function()
	if not (IsValid(sBox) and IsValid(bBox)) then
		out(false, string.format("conteneurs de test disparus (vendeur %s, acheteur %s) : test interrompu", tostring(IsValid(sBox)), tostring(IsValid(bBox))))
		for _, ent in ipairs(created) do if IsValid(ent) then ent:Remove() end end
		for _, b in ipairs({ seller, buyer }) do if IsValid(b) then b:Kick("Fin du test Astral") end end
		return
	end
	for k, o in pairs(M.Orders) do if o.seller == seller:SteamID64() then id = k end end
	out(id ~= nil and M.Orders[id].qty_left == 20, "offre enregistrée (id " .. tostring(id) .. ")")
	if not id then return end
	M.Sell(seller, "iron_ingot", 5, 1000)
	out(inv(sBox) == 10, "prix hors bornes (1000 > 450) refusé, stock intact")
	M.Buy(seller, id, 1)
	out(M.Orders[id].qty_left == 20 and not M.Orders[id].pending, "achat de sa propre offre refusé")
	M.Buy(buyer, id, 999)
	out(M.Orders[id].qty_left == 20 and not M.Orders[id].pending, "quantité supérieure à l'offre refusée")
	M.Buy(buyer, id, 8)
end)

timer.Simple(13, function()
	out(inv(bBox) == 8, "acheteur : 8 lingots livrés (" .. inv(bBox) .. ")")
	out(bMoney0 - buyer:GetMoney() == 400, "acheteur débité de 400 (" .. (bMoney0 - buyer:GetMoney()) .. ")")
	out(seller:GetMoney() - sMoney0 == 380, "vendeur payé 380 = 400 - taxe 5 % (" .. (seller:GetMoney() - sMoney0) .. ")")
	out(M.Orders[id] and M.Orders[id].qty_left == 12, "offre : 12 restants")
	-- Deux achats simultanés : le second doit être bloqué par le verrou de l'offre
	M.Buy(buyer, id, 5)
	M.Buy(buyer, id, 5)
end)

timer.Simple(17, function()
	out(M.Orders[id] and M.Orders[id].qty_left == 7 and inv(bBox) == 13, "double achat simultané : un seul exécuté (reste " .. tostring(M.Orders[id] and M.Orders[id].qty_left) .. ", acheteur " .. inv(bBox) .. ")")
	M.Cancel(seller, id)
end)

timer.Simple(20, function()
	out(M.Orders[id] == nil and inv(sBox) == 17, "annulation : 7 lingots rendus (conteneur vendeur " .. inv(sBox) .. ")")
	Astral.DB.Conn():FetchOne("SELECT status, qty_left, proceeds FROM astral_market WHERE id = {1}", { params = { id }, callback = function(e, r)
		out(r and tonumber(r.status) == 2 and tonumber(r.qty_left) == 0 and tonumber(r.proceeds) == 0, "base : offre annulée, rien en séquestre, vendeur entièrement payé")
		for _, ent in ipairs(created) do if IsValid(ent) then ent:Remove() end end
		for _, b in ipairs({ seller, buyer }) do if IsValid(b) then b:Kick("Fin du test Astral") end end
		print("[Astral Test] Terminé")
	end })
end)
