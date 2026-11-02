-- Astral BaseWars — menu d'administration (partie serveur).
-- Ouverture : « !astral » ou « /astral » dans le chat, ou la commande client astral_menu.
-- Chaque demande du menu est vérifiée ici (privilège CAMI), quel que soit ce que le client affiche.

util.AddNetworkString("Astral.Admin.Open")
util.AddNetworkString("Astral.Admin.Data")

local LOG_CATEGORIES = {
	money = true, buy = true, collect = true, money_transfer = true, level = true, join = true, leave = true, upgrade = true,
	faction_create = true, faction_disband = true, faction_join = true, faction_leave = true,
	raid_start = true, raid_end = true, admin_command = true, admin_menu = true,
	net_reject = true, net_error = true, economy_alert = true, diag = true, industry_sell = true, admin_action = true, quest_claim = true, event_start = true, event_end = true, research = true, security = true, setting = true,
	market_list = true, market_buy = true, market_cancel = true, market_payout = true,
	farm_sell = true, farm_explode = true, firework = true, fun_command = true,
}

local function send(ply, action, payload)
	if not IsValid(ply) then return end
	local data = util.Compress(util.TableToJSON(payload) or "{}") or ""
	if #data > 60000 then
		data = util.Compress(util.TableToJSON({ error = "Réponse trop volumineuse, affinez la recherche." }))
	end
	net.Start("Astral.Admin.Data")
		net.WriteString(action)
		net.WriteUInt(#data, 16)
		net.WriteData(data, #data)
	net.Send(ply)
end

-- Noms connus : joueurs en ligne, puis dernières connexions journalisées
local function withNames(db, sids, done)
	local names = {}
	for _, p in player.Iterator() do
		local sid = Astral.PlayerID(p)
		if sid then names[sid] = p:Nick() end
	end
	db:Fetch("SELECT sid64, data FROM astral_logs WHERE category = 'join' ORDER BY id DESC LIMIT 1000", {
		callback = function(err, rows)
			for _, r in ipairs(rows or {}) do
				if r.sid64 and not names[r.sid64] then
					local d = util.JSONToTable(r.data or "") or {}
					names[r.sid64] = d.name
				end
			end
			done(names)
		end,
	})
end

local function findPlayerSid(arg)
	if arg:match("^7656%d+$") then return arg end
	local lower = arg:lower()
	for _, p in player.Iterator() do
		if p:Nick():lower():find(lower, 1, true) then return Astral.PlayerID(p) end
	end
end

local ACTIONS = {}

ACTIONS.diag = { priv = "Diagnostics", run = function(ply, arg, reply)
	reply({ lines = Astral.Diagnostics.Report() })
end }

-- Économie sur 24 h : gains/pertes par joueur et par source
ACTIONS.eco_summary = { priv = "Logs", run = function(ply, arg, reply)
	local db = Astral.DB.Conn()
	db:Fetch("SELECT sid64, data FROM astral_logs WHERE category = 'money' AND ts >= {1} ORDER BY id DESC LIMIT 20000", {
		params = { os.time() - 86400 },
		callback = function(err, rows)
			if err then return reply({ error = tostring(err) }) end
			local players, sources = {}, {}
			for _, r in ipairs(rows or {}) do
				local d = util.JSONToTable(r.data or "") or {}
				local delta = tonumber(d.delta) or 0
				local p = players[r.sid64 or "?"] or { gain = 0, loss = 0, count = 0 }
				players[r.sid64 or "?"] = p
				if delta > 0 then p.gain = p.gain + delta else p.loss = p.loss - delta end
				p.count = p.count + 1
				local s = sources[d.source or "?"] or { gain = 0, loss = 0, count = 0 }
				sources[d.source or "?"] = s
				if delta > 0 then s.gain = s.gain + delta else s.loss = s.loss - delta end
				s.count = s.count + 1
			end
			withNames(db, nil, function(names)
				local list = {}
				for sid, p in pairs(players) do
					list[#list + 1] = { sid = sid, name = names[sid] or sid, gain = p.gain, loss = p.loss, count = p.count }
				end
				table.SortByMember(list, "gain")
				local srcList = {}
				for name, s in pairs(sources) do srcList[#srcList + 1] = { source = name, gain = s.gain, loss = s.loss, count = s.count } end
				table.SortByMember(srcList, "gain")
				reply({ players = list, sources = srcList, rows = #(rows or {}) })
			end)
		end,
	})
end }

-- Dernières transactions d'un joueur (nom partiel d'un joueur en ligne, ou SteamID64)
ACTIONS.eco_player = { priv = "Logs", run = function(ply, arg, reply)
	local sid = findPlayerSid(arg)
	if not sid then return reply({ error = "Joueur introuvable (nom d'un joueur connecté ou SteamID64)." }) end
	Astral.DB.Conn():Fetch("SELECT ts, data FROM astral_logs WHERE category = 'money' AND sid64 = {1} ORDER BY id DESC LIMIT 100", {
		params = { sid },
		callback = function(err, rows)
			if err then return reply({ error = tostring(err) }) end
			local list = {}
			for _, r in ipairs(rows or {}) do
				local d = util.JSONToTable(r.data or "") or {}
				list[#list + 1] = { ts = tonumber(r.ts), delta = d.delta, balance = d.balance, source = d.source }
			end
			reply({ sid = sid, rows = list })
		end,
	})
end }

-- Journaux bruts, filtrables par catégorie
ACTIONS.logs = { priv = "Logs", run = function(ply, arg, reply)
	local db = Astral.DB.Conn()
	local query, params = "SELECT ts, category, sid64, data FROM astral_logs ORDER BY id DESC LIMIT 150", {}
	if arg ~= "" then
		if not LOG_CATEGORIES[arg] then return reply({ error = "Catégorie inconnue." }) end
		query = "SELECT ts, category, sid64, data FROM astral_logs WHERE category = {1} ORDER BY id DESC LIMIT 150"
		params = { arg }
	end
	db:Fetch(query, { params = params, callback = function(err, rows)
		if err then return reply({ error = tostring(err) }) end
		withNames(db, nil, function(names)
			local list = {}
			for _, r in ipairs(rows or {}) do
				list[#list + 1] = { ts = tonumber(r.ts), category = r.category, who = r.sid64 and (names[r.sid64] or r.sid64) or "-", data = r.data }
			end
			reply({ rows = list })
		end)
	end })
end }

---------------------------------------------------------------------------
-- Gestion des joueurs, des machines et annonces (privilège Astral.Admin pour toute modification)
---------------------------------------------------------------------------
util.AddNetworkString("Astral.Announce")

local function bySid(sid)
	for _, p in player.Iterator() do if Astral.PlayerID(p) == sid then return p end end
end

-- Liste des joueurs connectés avec leurs statistiques BaseWars
ACTIONS.players = { priv = "Logs", run = function(ply, arg, reply)
	local list = {}
	for _, p in player.Iterator() do
		local ents = 0
		BaseWars.CPPI.ForEachOwned(p, function(e) if e:GetClass():sub(1, 3) == "bw_" or e:GetClass():sub(1, 7) == "astral_" then ents = ents + 1 end end)
		list[#list + 1] = {
			sid = Astral.PlayerID(p) or "", name = p:Nick(), group = p:GetUserGroup(),
			money = p:GetMoney(), level = p:GetLevel(), karma = p.GetKarma and p:GetKarma() or 0,
			faction = p:InFaction() and p:GetFaction() or "", ping = p:Ping(), ents = ents,
			afk = p.IsAFK and p:IsAFK() or false, frozen = p:IsFrozen(),
		}
	end
	table.SortByMember(list, "name", true)
	reply({ players = list })
end }

-- arg = "sid|action|valeur|raison"
local PLAYER_ACTIONS = {
	give_money = function(admin, target, value)
		local n = math.floor(tonumber(value) or 0)
		if n < 1 or n > 1e12 then return "Montant invalide (1 à 1 000 milliards)." end
		target:GiveMoney(n)
		return string.format("%s%s donnés à %s.", BaseWars.LANG.CURRENCY, BaseWars.NumberFormat(n), target:Nick())
	end,
	take_money = function(admin, target, value)
		local n = math.floor(tonumber(value) or 0)
		if n < 1 or n > 1e12 then return "Montant invalide (1 à 1 000 milliards)." end
		target:TakeMoney(math.min(n, target:GetMoney()))
		return string.format("%s%s retirés à %s.", BaseWars.LANG.CURRENCY, BaseWars.NumberFormat(n), target:Nick())
	end,
	set_level = function(admin, target, value)
		local n = math.floor(tonumber(value) or 0)
		if n < 1 or n > BaseWars.Config.LevelSettings.MaxLevel then return "Niveau invalide." end
		target:SetLevel(n)
		return target:Nick() .. " est maintenant niveau " .. n .. "."
	end,
	kick = function(admin, target, value, reason)
		local why = reason ~= "" and reason or "Expulsé par un administrateur"
		local name = target:Nick()
		target:Kick(why)
		return name .. " expulsé (" .. why .. ")."
	end,
	ban = function(admin, target, value, reason)
		local minutes = math.floor(tonumber(value) or 0)
		if minutes < 0 or minutes > 525600 then return "Durée invalide (0 = définitif, max 1 an)." end
		local why = reason ~= "" and reason or "Banni par un administrateur"
		local name = target:Nick()
		if ULib and ULib.ban then ULib.ban(target, minutes, why, admin) else target:Ban(minutes, true) end
		return name .. " banni " .. (minutes == 0 and "définitivement" or (minutes .. " min")) .. " (" .. why .. ")."
	end,
	go_to = function(admin, target)
		if not IsValid(admin) then return "Action impossible depuis la console." end
		admin:SetPos(target:GetPos() + target:GetForward() * -60 + Vector(0, 0, 10))
		return "Téléporté vers " .. target:Nick() .. "."
	end,
	bring = function(admin, target)
		if not IsValid(admin) then return "Action impossible depuis la console." end
		target:SetPos(admin:GetPos() + admin:GetForward() * 70 + Vector(0, 0, 10))
		return target:Nick() .. " téléporté vers vous."
	end,
	freeze = function(admin, target)
		target:Freeze(not target:IsFrozen())
		return target:Nick() .. (target:IsFrozen() and " gelé." or " dégelé.")
	end,
	refund = function(admin, target)
		BaseWars.UTIL.RefundAll(target)
		return "Entités de " .. target:Nick() .. " remboursées et retirées."
	end,
	-- Commandes utiles
	heal = function(admin, target)
		if not target:Alive() then return target:Nick() .. " est mort." end
		target:SetHealth(target:GetMaxHealth()) target:Extinguish()
		target:EmitSound("items/smallmedkit1.wav")
		return target:Nick() .. " soigné."
	end,
	armor = function(admin, target)
		target:SetArmor(100) target:EmitSound("items/battery_pickup.wav")
		return target:Nick() .. " a 100 d'armure."
	end,
	god = function(admin, target)
		if target:HasGodMode() then target:GodDisable() else target:GodEnable() end
		return target:Nick() .. (target:HasGodMode() and " est invincible." or " n'est plus invincible.")
	end,
	cloak = function(admin, target)
		local on = not target:GetNoDraw()
		target:SetNoDraw(on)
		local w = target:GetActiveWeapon() if IsValid(w) then w:SetNoDraw(on) end
		return target:Nick() .. (on and " est invisible." or " est de nouveau visible.")
	end,
	noclip = function(admin, target)
		target:SetMoveType(target:GetMoveType() == MOVETYPE_NOCLIP and MOVETYPE_WALK or MOVETYPE_NOCLIP)
		return target:Nick() .. (target:GetMoveType() == MOVETYPE_NOCLIP and " vole (noclip)." or " ne vole plus.")
	end,
	respawn = function(admin, target)
		target:Spawn()
		return target:Nick() .. " a réapparu."
	end,
	strip = function(admin, target)
		target:StripWeapons()
		return "Armes retirées à " .. target:Nick() .. "."
	end,
	-- Commandes amusantes
	slap = function(admin, target)
		target:SetVelocity(Vector(math.random(-300, 300), math.random(-300, 300), 300))
		target:EmitSound("physics/body/body_medium_impact_hard" .. math.random(1, 6) .. ".wav")
		return target:Nick() .. " a reçu une gifle."
	end,
	launch = function(admin, target)
		target:SetVelocity(Vector(0, 0, 1200))
		target:EmitSound("weapons/rpg/rocketfire1.wav")
		if Astral.Farms and Astral.Farms.Firework then
			local p = target:GetPos()
			timer.Simple(1.2, function() Astral.Farms.Firework(p, p + Vector(0, 0, 700)) end)
		end
		return target:Nick() .. " s'envole !"
	end,
	ignite = function(admin, target)
		target:Ignite(5)
		return target:Nick() .. " prend feu (5 s)."
	end,
	shrink = function(admin, target)
		local small = target:GetModelScale() >= 1
		target:SetModelScale(small and 0.5 or 1, 0.5)
		target:SetViewOffset(small and Vector(0, 0, 32) or Vector(0, 0, 64))
		target:SetViewOffsetDucked(small and Vector(0, 0, 14) or Vector(0, 0, 28))
		return target:Nick() .. (small and " a rétréci." or " a retrouvé sa taille.")
	end,
}

ACTIONS.player_action = { priv = "Admin", run = function(ply, arg, reply)
	local sid, action, value, reason = arg:match("^(%d+)|([%w_]+)|([^|]*)|?(.*)$")
	local fn = action and PLAYER_ACTIONS[action]
	local target = sid and bySid(sid)
	if not fn then return reply({ error = "Action inconnue." }) end
	if not IsValid(target) then return reply({ error = "Joueur introuvable (déconnecté ?)." }) end
	local msg = fn(ply, target, value, (reason or ""):sub(1, 120))
	Astral.Logs.Write("admin_action", ply, { action = action, target = sid, value = value, reason = reason })
	reply({ message = msg })
end }

-- Machines BaseWars / Astral : liste filtrable, suppression unitaire
ACTIONS.entities = { priv = "Diagnostics", run = function(ply, arg, reply)
	local list = {}
	for _, e in ents.Iterator() do
		local c = e:GetClass()
		if c:sub(1, 3) == "bw_" or c:sub(1, 7) == "astral_" then
			local o = BaseWars.CPPI.GetOwner(e)
			list[#list + 1] = {
				id = e:EntIndex(), class = c, name = e.PrintName or c, owner = IsValid(o) and o:Nick() or "—",
				hp = e:Health(), maxhp = e:GetMaxHealth(), power = e.GetPower and e:GetPower() or nil,
				maxpower = e.GetMaxPower and e:GetMaxPower() or nil, value = e.CurrentValue or 0,
				dist = IsValid(ply) and math.floor(ply:GetPos():Distance(e:GetPos())) or 0,
			}
		end
		if #list >= 400 then break end
	end
	table.SortByMember(list, "dist", true)
	reply({ entities = list })
end }

ACTIONS.entity_action = { priv = "Admin", run = function(ply, arg, reply)
	local id, action = arg:match("^(%d+)|(%a+)$")
	local e = id and Entity(tonumber(id))
	if not IsValid(e) then return reply({ error = "Entité introuvable." }) end
	local c = e:GetClass()
	if c:sub(1, 3) ~= "bw_" and c:sub(1, 7) ~= "astral_" then return reply({ error = "Entité non gérée." }) end
	if action == "remove" then
		local o = BaseWars.CPPI.GetOwner(e)
		if IsValid(o) and e.CurrentValue then BaseWars.UTIL.PayOut(e, o, true) end -- remboursement complet au propriétaire
		e:Remove()
		Astral.Logs.Write("admin_action", ply, { action = "entity_remove", class = c, owner = Astral.PlayerID(o) })
		return reply({ message = "Entité supprimée, propriétaire remboursé." })
	elseif action == "teleport" and IsValid(ply) then
		ply:SetPos(e:GetPos() + Vector(0, 0, 60))
		return reply({ message = "Téléporté vers l'entité." })
	end
	reply({ error = "Action inconnue." })
end }

-- Annonce : message en tête d'écran + chat pour tous les joueurs
ACTIONS.announce = { priv = "Admin", run = function(ply, arg, reply)
	local text = arg:Trim():sub(1, 180)
	if #text < 3 then return reply({ error = "Annonce trop courte." }) end
	net.Start("Astral.Announce") net.WriteString(text) net.Broadcast()
	Astral.Logs.Write("admin_action", ply, { action = "announce", text = text })
	reply({ message = "Annonce envoyée à " .. player.GetCount() .. " joueur(s)." })
end }

-- Événements : lancement (« id » ou « id|minutes ») et arrêt manuels
ACTIONS.event_start = { priv = "Admin", run = function(ply, arg, reply)
	local id, minutes = arg:match("^([%w_]+)|?(%d*)$")
	local ok, err = Astral.Events.Start(id or "", ply, tonumber(minutes) and tonumber(minutes) * 60 or nil)
	reply(ok and { message = "Événement lancé : " .. Astral.Events.List[id].name } or { error = err })
end }

-- Commandes serveur (onglet « Commandes ») : arg = « commande » ou « commande|valeur »
local SERVER_CMDS = {
	heal_all = function()
		for _, p in player.Iterator() do if p:Alive() then p:SetHealth(p:GetMaxHealth()) p:SetArmor(math.max(p:Armor(), 50)) end end
		net.Start("Astral.Announce") net.WriteString("Un administrateur a soigné tout le monde !") net.Broadcast()
		return "Tous les joueurs soignés."
	end,
	fireworks = function()
		Astral.Events.FireworksShow(10)
		return "Spectacle de feux d'artifice lancé."
	end,
	money_rain = function(value)
		local n = math.floor(tonumber(value) or 0)
		if n < 1 or n > 1e9 then return nil, "Montant invalide (1 à 1 milliard par joueur)." end
		for _, p in player.Iterator() do p:GiveMoney(n) end
		net.Start("Astral.EventFX") net.WriteString("gold_rush") net.WriteBool(true) net.Broadcast()
		net.Start("Astral.Announce") net.WriteString("Pluie de billets : " .. Astral.Printers.Money(n) .. " pour chaque joueur !") net.Broadcast()
		return Astral.Printers.Money(n) .. " donnés à " .. player.GetCount() .. " joueur(s)."
	end,
	freeze_all = function(_, admin)
		for _, p in player.Iterator() do if p ~= admin then p:Freeze(true) end end
		return "Tous les joueurs sont gelés."
	end,
	unfreeze_all = function()
		for _, p in player.Iterator() do p:Freeze(false) end
		return "Tous les joueurs sont dégelés."
	end,
	cleanup_decals = function()
		for _, p in player.Iterator() do p:ConCommand("r_cleardecals") end
		return "Impacts et taches effacés chez tous les joueurs."
	end,
	slowmo = function()
		local slow = game.GetTimeScale() >= 1
		game.SetTimeScale(slow and 0.5 or 1)
		return slow and "Ralenti activé (× 0,5)." or "Vitesse normale rétablie."
	end,
}

ACTIONS.server_cmd = { priv = "Admin", run = function(ply, arg, reply)
	local cmd, value = arg:match("^([%w_]+)|?(.*)$")
	local fn = cmd and SERVER_CMDS[cmd]
	if not fn then return reply({ error = "Commande inconnue." }) end
	local msg, err = fn(value, ply)
	Astral.Logs.Write("admin_action", ply, { action = "server_" .. cmd, value = value })
	reply(msg and { message = msg } or { error = err })
end }
ACTIONS.event_stop = { priv = "Admin", run = function(ply, arg, reply)
	local ok, err = Astral.Events.Stop(ply)
	reply(ok and { message = "Événement arrêté." } or { error = err })
end }

-- Équilibrage en jeu (sv_settings.lua) : lecture pour le staff, modification réservée au privilège Admin
ACTIONS.settings_list = { priv = "Diagnostics", run = function(ply, arg, reply)
	reply({ settings = Astral.Settings.List() })
end }
ACTIONS.settings_set = { priv = "Admin", run = function(ply, arg, reply)
	local path, value = arg:match("^([%w_%.]+)|(.+)$")
	if not path then return reply({ error = "Demande invalide." }) end
	Astral.Settings.Set(ply, path, value, function(ok, msg) reply(ok and { message = msg, settings = Astral.Settings.List() } or { error = msg }) end)
end }
ACTIONS.settings_reset = { priv = "Admin", run = function(ply, arg, reply)
	local def = Astral.Settings.Defaults[arg]
	if def == nil then return reply({ error = "Réglage inconnu." }) end
	Astral.Settings.Set(ply, arg, tostring(def), function(ok, msg) reply(ok and { message = "Rétabli — " .. msg, settings = Astral.Settings.List() } or { error = msg }) end)
end }

local function canOpen(ply, cb)
	Astral.HasAccess(ply, "Logs", function(a)
		if a then return cb(true) end
		Astral.HasAccess(ply, "Diagnostics", cb)
	end)
end

local function open(ply)
	canOpen(ply, function(allowed)
		if not allowed or not IsValid(ply) then return end
		local cats = {}
		for k in SortedPairs(LOG_CATEGORIES) do cats[#cats + 1] = k end
		net.Start("Astral.Admin.Open")
			net.WriteTable(cats)
		net.Send(ply)
	end)
end

Astral.Net.Receive("Astral.Admin.Request", { rate = 3, burst = 6, maxBytes = 512 }, function(ply)
	local action = net.ReadString()
	local arg = net.ReadString():sub(1, 240)
	if action == "open" then return open(ply) end
	local def = ACTIONS[action]
	if not def then return end
	Astral.HasAccess(ply, def.priv, function(allowed)
		if not allowed or not IsValid(ply) then return end
		if not Astral.DB.Ready and action ~= "diag" then return send(ply, action, { error = "Base de données non prête." }) end
		Astral.Logs.Write("admin_menu", ply, { action = action, arg = arg })
		def.run(ply, arg, function(payload) send(ply, action, payload) end)
	end)
end)

hook.Add("PlayerSay", "Astral.Admin.Chat", function(ply, text)
	local t = text:lower():Trim()
	if t == "!astral" or t == "/astral" then
		open(ply)
		return ""
	end
end, PRE_HOOK_RETURN)
