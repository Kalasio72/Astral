-- Astral BaseWars — export des tables MySQL en JSON vers data/astral_backups/
-- Lancement depuis la console serveur uniquement : lua_openscript astral_tools/backup_db.lua
-- Aucune donnée n'est modifiée : uniquement des SELECT.

local TABLES = { "basewars", "basewars_crash_refunds", "basewars_textscreen_configs" }
local DIR = "astral_backups"

local db = BaseWars and BaseWars.MySQL and BaseWars.MySQL.DbObj
if not db then
	print("[Astral Backup] ECHEC : connexion MySQL BaseWars indisponible")
	return
end

file.CreateDir(DIR)
local stamp = os.date("%Y%m%d_%H%M%S")
local dump = { created = os.time(), tables = {} }
local remaining = #TABLES

local function finish()
	local path = DIR .. "/db_" .. stamp .. ".json"
	file.Write(path, util.TableToJSON(dump, true))
	local counts = {}
	for name, rows in pairs(dump.tables) do counts[#counts + 1] = name .. "=" .. #rows end
	print("[Astral Backup] OK data/" .. path .. " (" .. table.concat(counts, ", ") .. ")")
end

for _, name in ipairs(TABLES) do
	db:Fetch("SELECT * FROM `" .. name .. "`", {
		callback = function(err, rows)
			if err then
				print("[Astral Backup] ERREUR sur " .. name .. " : " .. tostring(err))
				dump.tables[name] = {}
			else
				dump.tables[name] = rows or {}
			end
			remaining = remaining - 1
			if remaining == 0 then finish() end
		end,
	})
end
