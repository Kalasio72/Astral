-- Astral BaseWars — accès MySQL et migrations de schéma.
-- Réutilise la connexion goobie-sql de BaseWars (BaseWars.MySQL.DbObj) : une seule connexion pour tout le serveur.
-- Les tables Astral sont toutes préfixées astral_ ; les tables basewars* ne sont jamais modifiées.
--
-- Migrations : liste ordonnée et définitive. On n'édite JAMAIS une migration déjà déployée ;
-- toute évolution du schéma = une nouvelle entrée à la fin. La version courante est dans astral_schema_version.

Astral.DB = Astral.DB or {}
local DB = Astral.DB
DB.Ready = false
DB.SchemaVersion = nil
DB.LastError = nil
local waiting = {}

DB.Migrations = {
	-- 1 : journal des actions sensibles
	{
		[[CREATE TABLE IF NOT EXISTS astral_logs (
			id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
			ts INT UNSIGNED NOT NULL,
			category VARCHAR(32) CHARACTER SET ascii NOT NULL,
			sid64 VARCHAR(20) CHARACTER SET ascii NULL,
			data TEXT NOT NULL,
			INDEX idx_category_ts (category, ts),
			INDEX idx_sid64_ts (sid64, ts),
			INDEX idx_ts (ts)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
	},
	-- 2 : quêtes journalières / hebdomadaires (une ligne par joueur, période et quête)
	{
		[[CREATE TABLE IF NOT EXISTS astral_quests (
			sid64 VARCHAR(20) CHARACTER SET ascii NOT NULL,
			period VARCHAR(16) CHARACTER SET ascii NOT NULL,
			quest_id VARCHAR(32) CHARACTER SET ascii NOT NULL,
			progress BIGINT UNSIGNED NOT NULL DEFAULT 0,
			claimed TINYINT UNSIGNED NOT NULL DEFAULT 0,
			PRIMARY KEY (sid64, period, quest_id),
			INDEX idx_period (period)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
	},
	-- 3 : technologies débloquées (arbre de recherche)
	{
		[[CREATE TABLE IF NOT EXISTS astral_research (
			sid64 VARCHAR(20) CHARACTER SET ascii NOT NULL,
			tech_id VARCHAR(32) CHARACTER SET ascii NOT NULL,
			unlocked_at INT UNSIGNED NOT NULL,
			PRIMARY KEY (sid64, tech_id)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
	},
	-- 4 : profils joueurs (pseudo pour les classements) et statistiques industrielles cumulées
	{
		[[CREATE TABLE IF NOT EXISTS astral_players (
			sid64 VARCHAR(20) CHARACTER SET ascii NOT NULL PRIMARY KEY,
			name VARCHAR(64) NOT NULL DEFAULT '',
			last_seen INT UNSIGNED NOT NULL DEFAULT 0,
			industry_earned BIGINT UNSIGNED NOT NULL DEFAULT 0,
			produced BIGINT UNSIGNED NOT NULL DEFAULT 0,
			INDEX idx_industry (industry_earned),
			INDEX idx_produced (produced)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
	},
	-- 5 : factions persistées (une faction dissoute est marquée, jamais supprimée ; un membre qui part a faction = NULL)
	{
		[[CREATE TABLE IF NOT EXISTS astral_factions (
			name VARCHAR(191) NOT NULL PRIMARY KEY,
			leader VARCHAR(32) CHARACTER SET ascii NOT NULL,
			color_r TINYINT UNSIGNED NOT NULL, color_g TINYINT UNSIGNED NOT NULL, color_b TINYINT UNSIGNED NOT NULL,
			pass_salt VARCHAR(32) CHARACTER SET ascii NULL,
			pass_hash VARCHAR(64) CHARACTER SET ascii NULL,
			created_at INT UNSIGNED NOT NULL,
			disbanded_at INT UNSIGNED NULL,
			INDEX idx_active (disbanded_at)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
		[[CREATE TABLE IF NOT EXISTS astral_faction_members (
			sid64 VARCHAR(20) CHARACTER SET ascii NOT NULL PRIMARY KEY,
			faction VARCHAR(191) NULL,
			joined_at INT UNSIGNED NOT NULL,
			INDEX idx_faction (faction)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
	},
	-- 6 : marché entre joueurs. Les ressources mises en vente sont sous séquestre dans la ligne (qty_left) ;
	-- proceeds = argent dû au vendeur et pas encore versé (versé à sa prochaine présence). status : 0 ouverte, 1 vendue, 2 annulée.
	{
		[[CREATE TABLE IF NOT EXISTS astral_market (
			id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
			seller VARCHAR(20) CHARACTER SET ascii NOT NULL,
			seller_name VARCHAR(64) NOT NULL DEFAULT '',
			resource VARCHAR(32) CHARACTER SET ascii NOT NULL,
			qty_total INT UNSIGNED NOT NULL,
			qty_left INT UNSIGNED NOT NULL,
			unit_price BIGINT UNSIGNED NOT NULL,
			proceeds BIGINT UNSIGNED NOT NULL DEFAULT 0,
			status TINYINT UNSIGNED NOT NULL DEFAULT 0,
			created_at INT UNSIGNED NOT NULL,
			closed_at INT UNSIGNED NULL,
			INDEX idx_status (status),
			INDEX idx_seller (seller, proceeds)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
	},
	-- 7 : réglages d'équilibrage modifiés en jeu (une ligne par réglage ; « rétablir » réécrit la valeur par défaut)
	{
		[[CREATE TABLE IF NOT EXISTS astral_settings (
			path VARCHAR(96) CHARACTER SET ascii NOT NULL PRIMARY KEY,
			value VARCHAR(64) NOT NULL,
			updated_by VARCHAR(20) CHARACTER SET ascii NULL,
			updated_at INT UNSIGNED NOT NULL
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
	},
}

function DB.Conn()
	return BaseWars.MySQL and BaseWars.MySQL.DbObj
end

-- DB.OnReady(function(db) ... end) : appelé dès que la connexion ET les migrations sont prêtes
function DB.OnReady(fn)
	if DB.Ready then return fn(DB.Conn()) end
	waiting[#waiting + 1] = fn
end

local function fail(context, err)
	DB.LastError = context .. " : " .. tostring(err)
	Astral.Log("db", "ERREUR " .. DB.LastError)
end

local function finish()
	DB.Ready = true
	Astral.Log("db", "Schéma Astral à jour (version " .. DB.SchemaVersion .. ")")
	local list = waiting
	waiting = {}
	for _, fn in ipairs(list) do
		local ok, err = pcall(fn, DB.Conn())
		if not ok then ErrorNoHalt("[Astral:db] " .. tostring(err) .. "\n") end
	end
	hook.Run("Astral.DBReady")
end

-- Exécute les requêtes d'une migration l'une après l'autre, puis enregistre la nouvelle version
local function runMigration(db, index, done)
	local queries = DB.Migrations[index]
	local step = 0
	local function nextQuery()
		step = step + 1
		if step > #queries then
			return db:Run("UPDATE astral_schema_version SET version = {1} WHERE id = 1", {
				params = { index },
				callback = function(err)
					if err then return fail("enregistrement de la version " .. index, err) end
					DB.SchemaVersion = index
					Astral.Log("db", "Migration " .. index .. " appliquée")
					done()
				end,
			})
		end
		db:Run(queries[step], { callback = function(err)
			if err then return fail("migration " .. index .. " requête " .. step, err) end
			nextQuery()
		end })
	end
	nextQuery()
end

local function migrate(db)
	db:Run("CREATE TABLE IF NOT EXISTS astral_schema_version (id TINYINT UNSIGNED NOT NULL PRIMARY KEY, version INT UNSIGNED NOT NULL) ENGINE=InnoDB", { callback = function(err)
		if err then return fail("création de astral_schema_version", err) end
		db:Run("INSERT IGNORE INTO astral_schema_version (id, version) VALUES (1, 0)", { callback = function(err2)
			if err2 then return fail("initialisation de astral_schema_version", err2) end
			db:FetchOne("SELECT version FROM astral_schema_version WHERE id = 1", { callback = function(err3, row)
				if err3 then return fail("lecture de la version", err3) end
				DB.SchemaVersion = tonumber(row and row.version) or 0
				if DB.SchemaVersion > #DB.Migrations then
					return fail("schéma", "version en base " .. DB.SchemaVersion .. " plus récente que le code (" .. #DB.Migrations .. ")")
				end
				local function nextMigration()
					if DB.SchemaVersion >= #DB.Migrations then return finish() end
					runMigration(db, DB.SchemaVersion + 1, nextMigration)
				end
				nextMigration()
			end })
		end })
	end })
end

-- BaseWars ouvre sa connexion sur InitPostEntity ; Connect(callback) attend qu'elle soit prête.
hook.Add("InitPostEntity", "Astral.DB.Init", function()
	BaseWars.MySQL.Connect(function()
		local db = DB.Conn()
		if not db then return fail("connexion", "BaseWars.MySQL.DbObj absent") end
		migrate(db)
	end)
end)
