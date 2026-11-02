-- Astral BaseWars — restauration d'un export JSON (backup_db.lua) vers MySQL.
-- Console serveur uniquement. Paramètres via des globales, puis lancement :
--   lua_run ASTRAL_RESTORE_FILE = "astral_backups/db_AAAAMMJJ_HHMMSS.json"
--   lua_run ASTRAL_RESTORE_MODE = "test"     -- "test" : tables *_restore_test ; "live" : vraies tables
--   lua_openscript astral_tools/restore_db.lua
-- Mode "live" : refusé si des joueurs sont connectés (leur argent en mémoire écraserait la restauration).
-- Tout est fait dans une transaction : en cas d'erreur, rien n'est modifié.

local COLUMNS = {
	basewars = { "sid64", "money", "karma", "time", "xp", "level" },
	basewars_crash_refunds = { "sid64", "session_id", "amount" },
	basewars_textscreen_configs = { "sid64", "config" },
}

local function say(msg) print("[Astral Restore] " .. msg) end

local path, mode = ASTRAL_RESTORE_FILE, ASTRAL_RESTORE_MODE or "test"
ASTRAL_RESTORE_FILE, ASTRAL_RESTORE_MODE = nil, nil
if not isstring(path) or not path:match("^astral_backups/db_%d+_%d+%.json$") then return say("ECHEC : ASTRAL_RESTORE_FILE invalide") end
if mode ~= "test" and mode ~= "live" then return say("ECHEC : ASTRAL_RESTORE_MODE doit valoir test ou live") end
if mode == "live" and player.GetCount() > 0 then return say("ECHEC : des joueurs sont connectés, restauration live refusée") end

local db = BaseWars and BaseWars.MySQL and BaseWars.MySQL.DbObj
if not db then return say("ECHEC : connexion MySQL indisponible") end

local raw = file.Read(path, "DATA")
local dump = raw and util.JSONToTable(raw)
if not dump or not istable(dump.tables) then return say("ECHEC : fichier illisible " .. path) end

local suffix = mode == "test" and "_restore_test" or ""

db:Begin(function(err, txn)
	if err then return say("ECHEC ouverture transaction : " .. tostring(err)) end
	local counts = {}
	for name, cols in pairs(COLUMNS) do
		local target = name .. suffix
		local rows = dump.tables[name] or {}
		local steps = {}
		if mode == "test" then
			steps[#steps + 1] = "CREATE TABLE IF NOT EXISTS `" .. target .. "` LIKE `" .. name .. "`"
		end
		steps[#steps + 1] = "DELETE FROM `" .. target .. "`"
		for _, q in ipairs(steps) do
			local e = txn:Execute(q, { params = {} })
			if e then txn:Rollback() return say("ECHEC sur " .. target .. " : " .. tostring(e)) end
		end
		local placeholders = {}
		for i = 1, #cols do placeholders[i] = "{" .. i .. "}" end
		local insert = "INSERT INTO `" .. target .. "` (`" .. table.concat(cols, "`, `") .. "`) VALUES (" .. table.concat(placeholders, ", ") .. ")"
		for _, row in ipairs(rows) do
			local params = {}
			for i, c in ipairs(cols) do params[i] = row[c] end
			local e = txn:Execute(insert, { params = params })
			if e then txn:Rollback() return say("ECHEC insertion dans " .. target .. " : " .. tostring(e)) end
		end
		counts[#counts + 1] = target .. "=" .. #rows
	end
	local e = txn:Commit()
	if e then return say("ECHEC commit : " .. tostring(e)) end
	say("OK (" .. mode .. ") depuis " .. path .. " : " .. table.concat(counts, ", "))
end)
