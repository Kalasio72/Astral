-- Astral Quests — moteur serveur.
-- Progression en mémoire (chargée à la connexion pour les seules périodes en cours), écrite en base par paquets
-- toutes les 60 s, à la déconnexion et immédiatement lors d'une réclamation. Réinitialisation : minuit (quotidien)
-- et lundi minuit (hebdomadaire), heure du serveur. La récompense n'est versée qu'une fois : l'état « réclamée »
-- est fixé et enregistré AVANT le paiement.

local Q = Astral.Quests
util.AddNetworkString("Astral.Quests.Sync")

---------------------------------------------------------------------------
-- Périodes et tirage des quêtes actives (identique pour tous les joueurs)
---------------------------------------------------------------------------
function Q.DailyKey() return "d" .. os.date("%Y%m%d") end
function Q.WeeklyKey() return "w" .. os.date("%Y%W") end

local function pick(list, count, period)
	local copy = table.Copy(list)
	local seed = tonumber(util.CRC(period)) or 1
	for i = #copy, 2, -1 do
		seed = (seed * 1103515245 + 12345) % 2147483648
		local j = seed % i + 1
		copy[i], copy[j] = copy[j], copy[i]
	end
	local out = {}
	for i = 1, math.min(count, #copy) do out[i] = copy[i] end
	return out
end

local activeCache = {}
function Q.Active(period)
	if not activeCache[period] then
		local daily = period:sub(1, 1) == "d"
		activeCache[period] = pick(daily and Q.Daily or Q.Weekly, daily and Q.DailyCount or Q.WeeklyCount, period)
	end
	return activeCache[period]
end

local function secondsUntilReset()
	local t = os.date("*t")
	local midnight = os.time({ year = t.year, month = t.month, day = t.day + 1, hour = 0 })
	local daysToMonday = (8 - (t.wday == 1 and 8 or t.wday)) % 7
	if daysToMonday == 0 then daysToMonday = 7 end
	local monday = os.time({ year = t.year, month = t.month, day = t.day + daysToMonday, hour = 0 })
	return midnight - os.time(), monday - os.time()
end

---------------------------------------------------------------------------
-- État joueur
---------------------------------------------------------------------------
local function state(ply)
	local d, w = Q.DailyKey(), Q.WeeklyKey()
	local s = ply.AstralQuests
	if not s or not s.loaded then return nil end
	-- Changement de période pendant la session : on repart de zéro pour la nouvelle période
	if not s[d] then s[d] = {} end
	if not s[w] then s[w] = {} end
	return s, d, w
end

local function entry(s, period, qid)
	s[period][qid] = s[period][qid] or { progress = 0, claimed = false, dirty = false }
	return s[period][qid]
end

function Q.Sync(ply)
	local s, d, w = state(ply)
	if not s then return end
	local dl, wl = secondsUntilReset()
	local out = {}
	for _, period in ipairs({ d, w }) do
		for _, q in ipairs(Q.Active(period)) do
			local e = entry(s, period, q.id)
			out[#out + 1] = { id = q.id, period = period, progress = e.progress, claimed = e.claimed }
		end
	end
	net.Start("Astral.Quests.Sync")
		net.WriteUInt(dl, 32) net.WriteUInt(wl, 32)
		net.WriteTable(out)
	net.Send(ply)
end

local function save(ply, onlyDirty)
	local sid = Astral.PlayerID(ply)
	local s = ply.AstralQuests
	if not sid or not s or not s.loaded or not Astral.DB.Ready then return end
	local values, params = {}, {}
	for period, quests in pairs(s) do
		if istable(quests) then
			for qid, e in pairs(quests) do
				if e.dirty or not onlyDirty then
					local b = #params
					values[#values + 1] = string.format("({%d}, {%d}, {%d}, {%d}, {%d})", b + 1, b + 2, b + 3, b + 4, b + 5)
					params[b + 1], params[b + 2], params[b + 3], params[b + 4], params[b + 5] = sid, period, qid, e.progress, e.claimed and 1 or 0
					e.dirty = false
				end
			end
		end
	end
	if #values == 0 then return end
	Astral.DB.Conn():Run("INSERT INTO astral_quests (sid64, period, quest_id, progress, claimed) VALUES " .. table.concat(values, ", ")
		.. " ON DUPLICATE KEY UPDATE progress = GREATEST(progress, VALUES(progress)), claimed = GREATEST(claimed, VALUES(claimed))",
		{ params = params, callback = function(err) if err then Astral.Log("quests", "ERREUR sauvegarde : " .. tostring(err)) end end })
end
Q.Save = save

local function load(ply)
	local sid = Astral.PlayerID(ply)
	if not sid then return end
	local d, w = Q.DailyKey(), Q.WeeklyKey()
	Astral.DB.OnReady(function(db)
		db:Fetch("SELECT period, quest_id, progress, claimed FROM astral_quests WHERE sid64 = {1} AND period IN ({2}, {3})", {
			params = { sid, d, w },
			callback = function(err, rows)
				if not IsValid(ply) then return end
				if err then return Astral.Log("quests", "ERREUR chargement : " .. tostring(err)) end
				local s = { loaded = true, [d] = {}, [w] = {} }
				for _, r in ipairs(rows or {}) do
					if s[r.period] then s[r.period][r.quest_id] = { progress = tonumber(r.progress) or 0, claimed = tonumber(r.claimed) == 1, dirty = false } end
				end
				ply.AstralQuests = s
				Q.Sync(ply)
			end,
		})
	end)
end

---------------------------------------------------------------------------
-- Progression
---------------------------------------------------------------------------
function Q.Advance(ply, counter, amount)
	if not IsValid(ply) or not ply:IsPlayer() or amount <= 0 then return end
	local s, d, w = state(ply)
	if not s then return end
	local changed = false
	for _, period in ipairs({ d, w }) do
		for _, q in ipairs(Q.Active(period)) do
			if q.counter == counter then
				local e = entry(s, period, q.id)
				if not e.claimed and e.progress < q.goal then
					e.progress = math.min(q.goal, e.progress + math.floor(amount))
					e.dirty = true
					changed = true
					if e.progress >= q.goal then
						ply:Notify("Quête terminée : " .. q.name .. " — réclame ta récompense (F3 → Quêtes).", BASEWARS_NOTIFICATION_MONEY)
					end
				end
			end
		end
	end
	if changed and (ply.AstralQuestSyncAt or 0) < CurTime() then
		ply.AstralQuestSyncAt = CurTime() + 2
		timer.Simple(0.2, function() if IsValid(ply) then Q.Sync(ply) end end)
	end
end

Astral.Net.Receive("Astral.Quests.Claim", { rate = 2, burst = 4, maxBytes = 64 }, function(ply)
	local period, qid = net.ReadString(), net.ReadString()
	local s, d, w = state(ply)
	if not s or (period ~= d and period ~= w) then return end
	local q = Q.ById[qid]
	if not q then return end
	local active = false
	for _, a in ipairs(Q.Active(period)) do if a.id == qid then active = true end end
	if not active then return end
	local e = entry(s, period, qid)
	if e.claimed or e.progress < q.goal then return end
	e.claimed, e.dirty = true, true      -- verrou AVANT paiement
	save(ply, true)
	ply:GiveMoney(q.money)
	ply:AddXP(q.xp)
	ply:Notify(string.format("Récompense : %s%s et %d XP (%s).", BaseWars.LANG.CURRENCY, BaseWars.NumberFormat(q.money), q.xp, q.name), BASEWARS_NOTIFICATION_MONEY)
	Astral.Logs.Write("quest_claim", ply, { quest = qid, period = period, money = q.money, xp = q.xp })
	Q.Sync(ply)
end)

Astral.Net.Receive("Astral.Quests.Request", { rate = 1, burst = 3, maxBytes = 8 }, function(ply) Q.Sync(ply) end)

---------------------------------------------------------------------------
-- Sources de progression (hooks SpaceVX et Astral)
---------------------------------------------------------------------------
hook.Add("BaseWars_PlayerEmptyPrinter", "Astral.Quests", function(ply, ent, money) Q.Advance(ply, "collect_money", tonumber(money) or 0) end, POST_HOOK)
hook.Add("BaseWars_PlayerBuyEntity", "Astral.Quests", function(ply) Q.Advance(ply, "buy_entity", 1) end, POST_HOOK)
hook.Add("RaidStart", "Astral.Quests", function(attacker) Q.Advance(attacker, "raid", 1) end, POST_HOOK)
hook.Add("Astral.IndustrySold", "Astral.Quests", function(ply, units, value) Q.Advance(ply, "sell_value", value) end)
hook.Add("Astral.Produced", "Astral.Quests", function(machine, kind, qty)
	local owner = BaseWars.CPPI.GetOwner(machine)
	if IsValid(owner) then Q.Advance(owner, kind, qty) end
end)

timer.Create("Astral.Quests.PlayTime", 60, 0, function()
	for _, p in player.Iterator() do
		if not (p.IsAFK and p:IsAFK()) then Q.Advance(p, "play_minutes", 1) end
	end
end)
timer.Create("Astral.Quests.Save", 60, 0, function() for _, p in player.Iterator() do save(p, true) end end)

hook.Add("PlayerInitialSpawn", "Astral.Quests", load)
hook.Add("PlayerDisconnected", "Astral.Quests", function(ply) save(ply, true) end)
hook.Add("ShutDown", "Astral.Quests", function() for _, p in player.Iterator() do save(p, true) end end)
for _, p in player.Iterator() do load(p) end
