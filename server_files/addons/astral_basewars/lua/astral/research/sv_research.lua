-- Astral Research — serveur : chargement, déblocage (paiement puis enregistrement), synchronisation.
-- Paiement : argent + composants retirés des conteneurs industriels du joueur, dans une seule étape Lua (pas de
-- double dépense possible). Si l'écriture en base échoue, tout est remboursé et l'échec est journalisé.

local RS = Astral.Research
util.AddNetworkString("Astral.Research.Sync")

local function sync(ply)
	if not IsValid(ply) or not ply.AstralResearch then return end
	local list = {}
	for id in pairs(ply.AstralResearch) do list[#list + 1] = id end
	-- Composants disponibles dans ses conteneurs (pour afficher « 4 / 10 » dans le menu)
	local stock = {}
	for _, box in ipairs(ents.FindByClass("astral_container")) do
		if BaseWars.CPPI.GetOwner(box) == ply and box.AstralStore then
			for res, q in pairs(box.AstralStore) do stock[res] = (stock[res] or 0) + q end
		end
	end
	net.Start("Astral.Research.Sync") net.WriteTable(list) net.WriteTable(stock) net.Send(ply)
end
RS.Sync = sync

local function load(ply)
	local sid = Astral.PlayerID(ply)
	if not sid then return end
	Astral.DB.OnReady(function(db)
		db:Fetch("SELECT tech_id FROM astral_research WHERE sid64 = {1}", { params = { sid }, callback = function(err, rows)
			if not IsValid(ply) then return end
			if err then return Astral.Log("research", "ERREUR chargement : " .. tostring(err)) end
			ply.AstralResearch = {}
			for _, r in ipairs(rows or {}) do if RS.ById[r.tech_id] then ply.AstralResearch[r.tech_id] = true end end
			sync(ply)
		end })
	end)
end

-- Retire les composants des conteneurs du joueur ; renvoie la liste des retraits pour un éventuel remboursement
local function takeItems(ply, items)
	local boxes = {}
	for _, box in ipairs(ents.FindByClass("astral_container")) do
		if BaseWars.CPPI.GetOwner(box) == ply and box.AstralStore then boxes[#boxes + 1] = box end
	end
	for res, need in pairs(items) do
		local have = 0
		for _, b in ipairs(boxes) do have = have + (b.AstralStore[res] or 0) end
		if have < need then return nil, Astral.Resources.Get(res).name end
	end
	local taken = {}
	for res, need in pairs(items) do
		for _, b in ipairs(boxes) do
			if need <= 0 then break end
			local n = math.min(need, b.AstralStore[res] or 0)
			if n > 0 then
				Astral.Inv.Add(b.AstralStore, res, -n)
				taken[#taken + 1] = { box = b, res = res, n = n }
				need = need - n
			end
		end
	end
	for _, b in ipairs(boxes) do b:AstralSync() end
	return taken
end

Astral.Net.Receive("Astral.Research.Unlock", { rate = 1, burst = 2, maxBytes = 48, alive = true }, function(ply)
	local id = net.ReadString()
	local tech = RS.ById[id]
	if not tech or not ply.AstralResearch or ply.AstralResearch[id] or ply.AstralResearchPending then return end
	if tech.requires and not ply.AstralResearch[tech.requires] then
		return ply:Notify("Il faut d'abord débloquer : " .. RS.ById[tech.requires].name, BASEWARS_NOTIFICATION_ERROR)
	end
	if ply:GetMoney() < tech.money then return ply:Notify("Pas assez d'argent pour cette recherche.", BASEWARS_NOTIFICATION_ERROR) end
	local taken, missing = takeItems(ply, tech.items)
	if not taken then return ply:Notify("Il manque des composants dans tes conteneurs : " .. missing, BASEWARS_NOTIFICATION_ERROR) end
	ply:TakeMoney(tech.money)
	ply.AstralResearchPending = true
	Astral.DB.Conn():Run("INSERT IGNORE INTO astral_research (sid64, tech_id, unlocked_at) VALUES ({1}, {2}, {3})", {
		params = { Astral.PlayerID(ply), id, os.time() },
		callback = function(err)
			if not IsValid(ply) then return end
			ply.AstralResearchPending = nil
			if err then
				-- Remboursement complet
				ply:GiveMoney(tech.money)
				for _, t in ipairs(taken) do if IsValid(t.box) then Astral.Inv.Add(t.box.AstralStore, t.res, t.n) t.box:AstralSync() end end
				Astral.Log("research", "ERREUR enregistrement " .. id .. " : " .. tostring(err))
				return ply:Notify("Erreur d'enregistrement : recherche remboursée.", BASEWARS_NOTIFICATION_ERROR)
			end
			ply.AstralResearch[id] = true
			ply:Notify("Recherche terminée : " .. tech.name .. " — " .. tech.desc, BASEWARS_NOTIFICATION_MONEY)
			Astral.Logs.Write("research", ply, { tech = id, money = tech.money, items = tech.items })
			sync(ply)
		end,
	})
end)

Astral.Net.Receive("Astral.Research.Request", { rate = 1, burst = 3, maxBytes = 8 }, function(ply) sync(ply) end)

hook.Add("PlayerInitialSpawn", "Astral.Research", load)
for _, p in player.Iterator() do load(p) end
