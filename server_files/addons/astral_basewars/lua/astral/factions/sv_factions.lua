-- Astral Factions — persistance des factions SpaceVX (modules/factions) sans modifier le gamemode.
--
-- Avant : une faction n'existait qu'en mémoire ; elle était dissoute dès que son chef se déconnectait
-- (hook PlayerDisconnected « BaseWars.Factions.Clean ») et perdue au redémarrage.
-- Maintenant :
--   * création, adhésion, départ et dissolution sont enregistrés en base (hooks BaseWars_Faction*) ;
--   * une déconnexion retire seulement le joueur de la liste des membres en ligne (la faction reste) ;
--   * au démarrage, les factions actives sont recréées (équipe, couleur) et chaque membre retrouve
--     sa faction (et son rôle de chef) à la reconnexion ;
--   * le mot de passe n'est plus gardé en clair : sel + SHA-256, vérifié par le hook CanJoinFaction.
-- Rien n'est jamais supprimé en base : une faction dissoute reçoit disbanded_at, un membre parti faction = NULL.
-- Les factions créées avant que la base soit prête restent gérées comme avant (comportement SpaceVX d'origine).

Astral.Factions = Astral.Factions or {}
local AF = Astral.Factions
AF.Active = AF.Active or {}   -- [nom] = { leader, r, g, b, salt, hash } : factions actives en base
local LEADER_NW = "BaseWars.Factions.Leader"

local function FT() return BaseWars.Factions.FactionTable end
local function key(name) return string.lower(string.Trim(name or "")) end

local function activeByKey(name)
	local k = key(name)
	for n, row in pairs(AF.Active) do if key(n) == k then return n, row end end
end

local function hashPass(salt, pass) return util.SHA256(salt .. "\0" .. pass) end

local function run(query, params, what)
	local db = Astral.DB.Conn()
	if not db or not Astral.DB.Ready then return end
	db:Run(query, { params = params, callback = function(err)
		if err then Astral.Log("factions", "ERREUR " .. what .. " : " .. tostring(err)) end
	end })
end

-- Recrée en mémoire une faction active (même procédure que MODULE:Create, sans chef connecté)
function AF.EnsureLoaded(name)
	local row = AF.Active[name]
	if not row then return false end
	if FT()[name] then return true end
	local col = Color(row.r, row.g, row.b, 255)
	local teamid = BaseWars.Factions:GetEmptyTeamID() + 1
	FT()[name] = { leader = row.leader, members = {}, teamid = teamid, color = col, AstralSalt = row.salt, AstralHash = row.hash }
	team.SetUp(teamid, name, col)
	BaseWars.Factions:SendFactionData(teamid, name, col)
	return true
end

local function remember(name, r)
	local function str(v) return isstring(v) and v ~= "" and v or nil end   -- NULL SQL → nil
	AF.Active[name] = { leader = r.leader, r = tonumber(r.color_r) or 255, g = tonumber(r.color_g) or 255, b = tonumber(r.color_b) or 255, salt = str(r.pass_salt), hash = str(r.pass_hash) }
end

---------------------------------------------------------------------------
-- Événements SpaceVX → base
---------------------------------------------------------------------------
hook.Add("BaseWars_FactionCreated", "Astral.Factions", function(ply, name)
	local fac = FT()[name]
	if not fac or not Astral.DB.Ready then return end
	local salt, hash
	if fac.password and fac.password ~= "" then
		salt = string.sub(util.SHA256(tostring(SysTime()) .. math.random() .. ply:SteamID()), 1, 16)
		hash = hashPass(salt, fac.password)
		fac.AstralSalt, fac.AstralHash = salt, hash
	end
	fac.password = nil   -- plus de mot de passe en clair en mémoire : vérification par CanJoinFaction
	local c = fac.color
	remember(name, { leader = fac.leader, color_r = c.r, color_g = c.g, color_b = c.b, pass_salt = salt, pass_hash = hash })
	run([[INSERT INTO astral_factions (name, leader, color_r, color_g, color_b, pass_salt, pass_hash, created_at, disbanded_at)
		VALUES ({1}, {2}, {3}, {4}, {5}, NULLIF({6}, ''), NULLIF({7}, ''), {8}, NULL)
		ON DUPLICATE KEY UPDATE leader = VALUES(leader), color_r = VALUES(color_r), color_g = VALUES(color_g), color_b = VALUES(color_b),
		pass_salt = VALUES(pass_salt), pass_hash = VALUES(pass_hash), created_at = VALUES(created_at), disbanded_at = NULL]],
		{ name, fac.leader, c.r, c.g, c.b, salt or "", hash or "", os.time() }, "création " .. name)
	run("INSERT INTO astral_faction_members (sid64, faction, joined_at) VALUES ({1}, {2}, {3}) ON DUPLICATE KEY UPDATE faction = VALUES(faction), joined_at = VALUES(joined_at)",
		{ ply:SteamID64(), name, os.time() }, "chef " .. name)
end)
-- (journal : les catégories faction_create/join/leave/disband sont déjà écrites par sv_logs.lua)

hook.Add("BaseWars_FactionJoined", "Astral.Factions", function(ply, name)
	if ply.AstralFactionRestore or not AF.Active[name] then return end
	run("INSERT INTO astral_faction_members (sid64, faction, joined_at) VALUES ({1}, {2}, {3}) ON DUPLICATE KEY UPDATE faction = VALUES(faction), joined_at = VALUES(joined_at)",
		{ ply:SteamID64(), name, os.time() }, "adhésion " .. name)
end)

hook.Add("BaseWars_FactionLeft", "Astral.Factions", function(ply, name)
	if not AF.Active[name] then return end
	run("UPDATE astral_faction_members SET faction = NULL WHERE sid64 = {1} AND faction = {2}", { ply:SteamID64(), name }, "départ " .. name)
end)

hook.Add("BaseWars_FactionDisbanded", "Astral.Factions", function(ply, name)
	if not AF.Active[name] then return end
	AF.Active[name] = nil
	run("UPDATE astral_factions SET disbanded_at = {2} WHERE name = {1}", { name, os.time() }, "dissolution " .. name)
	run("UPDATE astral_faction_members SET faction = NULL WHERE faction = {1}", { name }, "dissolution (membres) " .. name)
end)

---------------------------------------------------------------------------
-- Règles : mot de passe haché, noms réservés par les factions hors ligne
---------------------------------------------------------------------------
hook.Add("CanJoinFaction", "Astral.Factions", function(ply, name, password)
	local fac = FT()[name]
	if ply.AstralFactionRestore or not fac or fac.password or not fac.AstralHash then return end
	if not isstring(password) or hashPass(fac.AstralSalt or "", password) ~= fac.AstralHash then
		return false, BaseWars.LANG.FactionWrongPass
	end
end)

hook.Add("CanCreateFaction", "Astral.Factions", function(ply, name)
	local existing = activeByKey(name)
	if existing and not FT()[existing] then
		return false, "Ce nom appartient déjà à une faction (ses membres sont hors ligne)."
	end
end)

---------------------------------------------------------------------------
-- Connexions
---------------------------------------------------------------------------
-- Déconnexion : remplace « BaseWars.Factions.Clean » (qui dissolvait la faction du chef) pour les factions persistées
local function onDisconnect(ply)
	local name = ply:GetFaction()
	local fac = FT()[name]
	if fac and AF.Active[name] then
		fac.members[ply:SteamID()] = nil
		return
	end
	BaseWars.Factions:Clean(ply)   -- faction non persistée : comportement d'origine
end
hook.Remove("PlayerDisconnected", "BaseWars.Factions.Clean")
hook.Add("PlayerDisconnected", "Astral.Factions", onDisconnect)

-- Reconnexion : rejoindre sa faction (sans mot de passe) et retrouver son rôle de chef
function AF.Restore(ply)
	-- Même identifiant que celui écrit par les hooks ci-dessus (SteamID64, y compris pour les bots de test)
	local sid = IsValid(ply) and ply:SteamID64()
	local db = Astral.DB.Conn()
	if not sid or not tostring(sid):match("^%d+$") or not db then return end
	db:FetchOne([[SELECT f.* FROM astral_faction_members m JOIN astral_factions f ON f.name = m.faction AND f.disbanded_at IS NULL
		WHERE m.sid64 = {1}]], { params = { sid }, callback = function(err, row)
		if err then return Astral.Log("factions", "ERREUR reconnexion : " .. tostring(err)) end
		if not row or not IsValid(ply) or ply:InFaction() then return end
		if not AF.Active[row.name] then remember(row.name, row) end
		if not AF.EnsureLoaded(row.name) then return end
		ply.AstralFactionRestore = true
		local ok, e = pcall(BaseWars.Factions.Set, BaseWars.Factions, ply, row.name, nil, true)
		ply.AstralFactionRestore = nil
		if not ok then return Astral.Log("factions", "ERREUR reconnexion " .. row.name .. " : " .. tostring(e)) end
		if FT()[row.name].leader == ply:SteamID() then ply:SetNW2Bool(LEADER_NW, true) end
		ply:Notify("Tu as retrouvé ta faction : " .. row.name, BASEWARS_NOTIFICATION_GENRL)
	end })
end

-- SpaceVX remet l'équipe à 1 au tick suivant PlayerInitialSpawn : on attend quelques secondes
hook.Add("PlayerInitialSpawn", "Astral.Factions", function(ply)
	timer.Simple(3, function() if IsValid(ply) then Astral.DB.OnReady(function() AF.Restore(ply) end) end end)
end)

-- Démarrage : recharge toutes les factions actives, puis les joueurs déjà connectés (rechargement à chaud)
Astral.DB.OnReady(function(db)
	db:Fetch("SELECT * FROM astral_factions WHERE disbanded_at IS NULL", { callback = function(err, rows)
		if err then return Astral.Log("factions", "ERREUR chargement : " .. tostring(err)) end
		for _, r in ipairs(rows or {}) do remember(r.name, r) AF.EnsureLoaded(r.name) end
		Astral.Log("factions", #(rows or {}) .. " faction(s) persistée(s) chargée(s)")
		for _, p in player.Iterator() do AF.Restore(p) end
	end })
end)
