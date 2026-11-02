-- Astral BaseWars — journal des actions sensibles, en base (table astral_logs).
-- Les lignes sont mises en file puis écrites par paquets toutes les Logs.FlushInterval secondes,
-- au lieu d'une requête par événement. La file est bornée (Logs.MaxQueue) pour ne jamais saturer la mémoire.
--
-- Astral.Logs.Write("categorie", ply_ou_nil, { cle = valeur, ... })

Astral.Logs = Astral.Logs or {}
local L = Astral.Logs
L.Queue = L.Queue or {}
L.Stats = L.Stats or { written = 0, dropped = 0, failed = 0, lastFlush = 0 }
local flushing = false

function L.Write(category, ply, data)
	local queue = L.Queue
	if #queue >= Astral.Cfg("Logs.MaxQueue", 2000) then
		table.remove(queue, 1)
		L.Stats.dropped = L.Stats.dropped + 1
	end
	queue[#queue + 1] = {
		os.time(),
		tostring(category):sub(1, 32),
		Astral.PlayerID(ply) or "",   -- "" → NULL (NULLIF dans la requête) : goobie-sql refuse un paramètre nil
		util.TableToJSON(data or {}) or "{}",
	}
end

function L.Flush(sync)
	if flushing or #L.Queue == 0 or not Astral.DB.Ready then return end
	local db = Astral.DB.Conn()
	if not db then return end
	local size = math.min(#L.Queue, Astral.Cfg("Logs.BatchSize", 200))
	local batch, values, params = {}, {}, {}
	for i = 1, size do
		local row = L.Queue[i]
		batch[i] = row
		local b = (i - 1) * 4
		values[i] = "({" .. (b + 1) .. "}, {" .. (b + 2) .. "}, NULLIF({" .. (b + 3) .. "}, ''), {" .. (b + 4) .. "})"
		params[b + 1], params[b + 2], params[b + 3], params[b + 4] = row[1], row[2], row[3], row[4]
	end
	for i = 1, size do table.remove(L.Queue, 1) end
	local query = "INSERT INTO astral_logs (ts, category, sid64, data) VALUES " .. table.concat(values, ", ")
	local function done(err)
		flushing = false
		L.Stats.lastFlush = os.time()
		if err then
			L.Stats.failed = L.Stats.failed + size
			Astral.Log("logs", "ERREUR écriture de " .. size .. " lignes : " .. tostring(err))
			-- On remet les lignes en tête de file pour un nouvel essai (dans la limite de MaxQueue)
			for i = size, 1, -1 do table.insert(L.Queue, 1, batch[i]) end
			while #L.Queue > Astral.Cfg("Logs.MaxQueue", 2000) do table.remove(L.Queue) L.Stats.dropped = L.Stats.dropped + 1 end
			return
		end
		L.Stats.written = L.Stats.written + size
	end
	flushing = true
	-- pcall : une erreur levée par la bibliothèque ne doit ni bloquer « flushing » ni perdre le paquet
	local ok, err = pcall(function()
		if sync then
			done(db:RunSync(query, { params = params }))
		else
			db:Run(query, { params = params, callback = done })
		end
	end)
	if not ok and flushing then done(err) end
end

timer.Create("Astral.Logs.Flush", Astral.Cfg("Logs.FlushInterval", 10), 0, function() L.Flush(false) end)

-- À l'arrêt : on vide la file de façon synchrone (plusieurs paquets si besoin)
hook.Add("ShutDown", "Astral.Logs.Flush", function()
	for _ = 1, 50 do
		if #L.Queue == 0 then break end
		L.Flush(true)
	end
end)

-- Rétention : suppression des lignes anciennes, une fois au démarrage (désactivée si RetentionDays = 0)
hook.Add("Astral.DBReady", "Astral.Logs.Retention", function()
	local days = Astral.Cfg("Logs.RetentionDays", 30)
	if days <= 0 then return end
	Astral.DB.Conn():Run("DELETE FROM astral_logs WHERE ts < {1} LIMIT 50000", {
		params = { os.time() - days * 86400 },
		callback = function(err) if err then Astral.Log("logs", "ERREUR rétention : " .. tostring(err)) end end,
	})
end)

---------------------------------------------------------------------------
-- Événements journalisés (hooks réellement appelés par SpaceVX et ULib)
---------------------------------------------------------------------------
local function entInfo(ent)
	if not IsValid(ent) then return nil end
	return ent:GetClass()
end

local function onBuy(kind)
	return function(ply, ent, price, item)
		L.Write("buy", ply, { kind = kind, item = item, class = entInfo(ent), price = price })
	end
end
hook.Add("BaseWars_PlayerBuyEntity", "Astral.Logs", onBuy("entity"), PRE_HOOK)
hook.Add("BaseWars_PlayerBuyGun", "Astral.Logs", onBuy("gun"), PRE_HOOK)
hook.Add("BaseWars_PlayerBuyDrug", "Astral.Logs", onBuy("drug"), PRE_HOOK)
hook.Add("BaseWars_PlayerBuyProp", "Astral.Logs", onBuy("prop"), PRE_HOOK)

hook.Add("BaseWars_PlayerEmptyPrinter", "Astral.Logs", function(ply, ent, money)
	local owner = BaseWars.CPPI.GetOwner(ent)
	L.Write("collect", ply, { class = entInfo(ent), amount = money, owner = Astral.PlayerID(owner), own = owner == ply })
end, PRE_HOOK)

hook.Add("BaseWars_MoneyTransferred", "Astral.Logs", function(from, to, amount)
	L.Write("money_transfer", from, { to = Astral.PlayerID(to), amount = amount })
end, PRE_HOOK)

hook.Add("BaseWars_PlayerLevelChanged", "Astral.Logs", function(ply, previous, new)
	L.Write("level", ply, { from = previous, to = new })
end, PRE_HOOK)

hook.Add("BaseWars_FactionCreated", "Astral.Logs", function(ply, name) L.Write("faction_create", ply, { name = name }) end, PRE_HOOK)
hook.Add("BaseWars_FactionDisbanded", "Astral.Logs", function(ply, name) L.Write("faction_disband", ply, { name = name }) end, PRE_HOOK)
hook.Add("BaseWars_FactionJoined", "Astral.Logs", function(ply, name) L.Write("faction_join", ply, { name = name }) end, PRE_HOOK)
hook.Add("BaseWars_FactionLeft", "Astral.Logs", function(ply, name) L.Write("faction_leave", ply, { name = name }) end, PRE_HOOK)

hook.Add("RaidStart", "Astral.Logs", function(attacker, target, isFaction)
	L.Write("raid_start", attacker, { target = Astral.PlayerID(target), faction = isFaction == true })
end, PRE_HOOK)
hook.Add("RaidEnded", "Astral.Logs", function() L.Write("raid_end", nil, {}) end, PRE_HOOK)

hook.Add("PlayerInitialSpawn", "Astral.Logs", function(ply) L.Write("join", ply, { name = ply:Nick() }) end, PRE_HOOK)
hook.Add("PlayerDisconnected", "Astral.Logs", function(ply)
	L.Write("leave", ply, { money = ply.GetMoney and ply:GetMoney() or nil })
end, PRE_HOOK)

-- Commandes ULX (ULib appelle ce hook après chaque commande ; args[1] est l'appelant)
local function argText(a)
	if isentity(a) then return IsValid(a) and a:IsPlayer() and a:SteamID64() or tostring(a) end
	if istable(a) then
		local list = {}
		for _, v in ipairs(a) do list[#list + 1] = argText(v) end
		return "[" .. table.concat(list, ",") .. "]"
	end
	return tostring(a)
end

if ULib and ULib.HOOK_POST_TRANSLATED_COMMAND then
	hook.Add(ULib.HOOK_POST_TRANSLATED_COMMAND, "Astral.Logs", function(ply, commandName, args)
		local parts = {}
		for i = 2, #(args or {}) do parts[#parts + 1] = argText(args[i]):sub(1, 200) end
		L.Write("admin_command", ply, { command = commandName, args = parts })
	end, PRE_HOOK)
end
