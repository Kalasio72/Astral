-- Astral Stats — profils joueurs (pseudo, dernière connexion), statistiques industrielles cumulées et classements.
-- Écritures : les gains et productions sont cumulés en mémoire puis écrits toutes les 60 s (une requête par joueur
-- actif), à la déconnexion et à l'arrêt. En cas d'erreur d'écriture, le delta est remis en attente.
-- Lecture : les classements viennent de la base (basewars + astral_players), complétés par les valeurs en direct des
-- joueurs connectés, et sont mis en cache 60 s pour que les demandes répétées ne touchent pas la base.

Astral.Stats = Astral.Stats or {}
local ST = Astral.Stats
util.AddNetworkString("Astral.Leaders.Sync")

local pending = {}   -- [sid64] = { earned = n, produced = n }

local function upsert(ply, earned, produced, done)
	local sid = Astral.PlayerID(ply)
	local db = Astral.DB.Conn()
	if not sid or not db or not Astral.DB.Ready then return done and done(false) end
	db:Run([[INSERT INTO astral_players (sid64, name, last_seen, industry_earned, produced) VALUES ({1}, {2}, {3}, {4}, {5})
		ON DUPLICATE KEY UPDATE name = VALUES(name), last_seen = VALUES(last_seen),
		industry_earned = industry_earned + VALUES(industry_earned), produced = produced + VALUES(produced)]], {
		params = { sid, string.sub(ply:Nick(), 1, 64), os.time(), earned, produced },
		callback = function(err)
			if err then Astral.Log("stats", "ERREUR écriture : " .. tostring(err)) end
			if done then done(not err) end
		end,
	})
end

local function flush(ply)
	if not IsValid(ply) then return end
	local sid = Astral.PlayerID(ply)
	local p = sid and pending[sid]
	if not p then return end
	pending[sid] = nil
	upsert(ply, p.earned, p.produced, function(ok)
		if ok then return end
		local again = pending[sid] or { earned = 0, produced = 0 }
		again.earned, again.produced = again.earned + p.earned, again.produced + p.produced
		pending[sid] = again
	end)
end

local function add(ply, field, n)
	local sid = IsValid(ply) and Astral.PlayerID(ply)
	if not sid or not n or n <= 0 then return end
	local p = pending[sid] or { earned = 0, produced = 0 }
	p[field] = p[field] + math.floor(n)
	pending[sid] = p
end

hook.Add("Astral.IndustrySold", "Astral.Stats", function(ply, units, value) add(ply, "earned", value) end)
hook.Add("Astral.Produced", "Astral.Stats", function(machine, kind, qty) add(BaseWars.CPPI.GetOwner(machine), "produced", qty) end)

hook.Add("PlayerInitialSpawn", "Astral.Stats", function(ply) Astral.DB.OnReady(function() if IsValid(ply) then upsert(ply, 0, 0) end end) end)
hook.Add("PlayerDisconnected", "Astral.Stats", flush)
hook.Add("ShutDown", "Astral.Stats", function() for _, p in player.Iterator() do flush(p) end end)
timer.Create("Astral.Stats.Flush", 60, 0, function() for _, p in player.Iterator() do flush(p) end end)

---------------------------------------------------------------------------
-- Classements
---------------------------------------------------------------------------
-- live(ply) : valeur en direct d'un joueur connecté (plus récente que la base, sauvegardée périodiquement)
-- Seuls les vrais comptes Steam (SteamID64 en 7656119…) sont classés : les bots de test en sont exclus.
ST.Boards = {
	{ id = "money",    sql = "SELECT b.sid64, b.money AS v, p.name FROM basewars b LEFT JOIN astral_players p ON p.sid64 = b.sid64 WHERE b.sid64 LIKE '7656119%' ORDER BY b.money DESC LIMIT 25",
	  live = function(ply) return ply:GetMoney() end },
	{ id = "level",    sql = "SELECT b.sid64, b.level AS v, b.xp AS v2, p.name FROM basewars b LEFT JOIN astral_players p ON p.sid64 = b.sid64 WHERE b.sid64 LIKE '7656119%' ORDER BY b.level DESC, b.xp DESC LIMIT 25",
	  live = function(ply) return ply:GetLevel(), ply:GetXP() end },
	{ id = "time",     sql = "SELECT b.sid64, b.`time` AS v, p.name FROM basewars b LEFT JOIN astral_players p ON p.sid64 = b.sid64 WHERE b.sid64 LIKE '7656119%' ORDER BY b.`time` DESC LIMIT 25",
	  live = function(ply) return ply.GetPlayTime and ply:GetPlayTime() or nil end },
	{ id = "industry", sql = "SELECT sid64, industry_earned AS v, name FROM astral_players WHERE sid64 LIKE '7656119%' ORDER BY industry_earned DESC LIMIT 25",
	  live = function(ply) local p = pending[Astral.PlayerID(ply)] return p and p.earned or 0, nil, true end },
	{ id = "produced", sql = "SELECT sid64, produced AS v, name FROM astral_players WHERE sid64 LIKE '7656119%' ORDER BY produced DESC LIMIT 25",
	  live = function(ply) local p = pending[Astral.PlayerID(ply)] return p and p.produced or 0, nil, true end },
}

local cache = { at = -math.huge, data = nil }
local building = false
local waiters = {}
local TOP = 10

-- Fusionne les lignes de la base et les joueurs connectés, trie, garde les TOP premiers.
-- Pour les statistiques cumulées (additive = true), la valeur en direct est le delta pas encore écrit.
local function merge(board, rows)
	local byId = {}
	for _, r in ipairs(rows or {}) do
		byId[r.sid64] = { sid = r.sid64, name = (r.name and r.name ~= "") and r.name or "Joueur hors ligne", v = tonumber(r.v) or 0, v2 = tonumber(r.v2) or 0 }
	end
	for _, ply in player.Iterator() do
		local sid = Astral.PlayerID(ply)
		local ok, v, v2, additive = pcall(board.live, ply)
		if sid and ok and v and not ply:IsBot() then
			local e = byId[sid] or { sid = sid, v = 0, v2 = 0 }
			e.name, e.online = ply:Nick(), true
			if additive then e.v = e.v + v else e.v, e.v2 = v, v2 or e.v2 end
			byId[sid] = e
		end
	end
	local list = {}
	for _, e in pairs(byId) do if e.v > 0 then list[#list + 1] = e end end
	table.sort(list, function(a, b) if a.v ~= b.v then return a.v > b.v end return a.v2 > b.v2 end)
	local out = {}
	for i = 1, math.min(TOP, #list) do
		local e = list[i]
		out[i] = { sid = e.sid, name = e.name, v = e.v, v2 = e.v2, online = e.online or false }
	end
	return out
end

local function build(done)
	waiters[#waiters + 1] = done
	if building then return end
	building = true
	local db = Astral.DB.Conn()
	local result, left = {}, #ST.Boards
	local function finish()
		building = false
		cache.at, cache.data = RealTime(), result
		local list = waiters
		waiters = {}
		for _, fn in ipairs(list) do fn(result) end
	end
	for _, board in ipairs(ST.Boards) do
		local function got(err, rows)
			if err then Astral.Log("stats", "ERREUR classement " .. board.id .. " : " .. tostring(err)) end
			result[board.id] = merge(board, not err and rows or nil)
			left = left - 1
			if left == 0 then finish() end
		end
		if db and Astral.DB.Ready then db:Fetch(board.sql, { callback = got }) else got(nil, nil) end
	end
end

function ST.GetLeaders(done)
	if cache.data and RealTime() - cache.at < 60 then return done(cache.data) end
	build(done)
end

Astral.Net.Receive("Astral.Leaders.Request", { rate = 1, burst = 3, maxBytes = 8 }, function(ply)
	ST.GetLeaders(function(data)
		if not IsValid(ply) then return end
		net.Start("Astral.Leaders.Sync") net.WriteTable(data) net.Send(ply)
	end)
end)

-- Rattrapage après un rechargement à chaud : profils des joueurs déjà connectés
Astral.DB.OnReady(function() for _, p in player.Iterator() do upsert(p, 0, 0) end end)
