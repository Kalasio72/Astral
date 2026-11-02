-- Analyse de sécurité : recherche de portes dérobées dans les fichiers du serveur.
-- Parcourt addons/, lua/, gamemodes/ et les addons Workshop montés, en tâche de fond (quelques ms par tick),
-- puis écrit le rapport dans data/astral/securite_analyse.json (lu par le panel, onglet Sécurité).
-- Lancement : automatiquement 30 s après le démarrage, ou commande console « astral_securite_analyse ».
-- Chaque constat donne la gravité, la faille, l'addon concerné, le chemin et la ligne.

Astral.Security = Astral.Security or {}
local SEC = Astral.Security
local OUT_DIR, OUT = "astral", "astral/securite_analyse.json"
local BUDGET = 0.004          -- secondes de calcul par tick
local MAX_SIZE = 2 * 1024 * 1024

-- Fichiers qui contiennent volontairement les signatures recherchées
local IGNORED = {
	["addons/astral_basewars/lua/autorun/server/!!!astral_shield.lua"] = "Astral Shield (le bouclier lui-même)",
	["addons/astral_basewars/lua/astral/admin/sv_security.lua"] = "cet analyseur",
	["lua/securite_tests/test_bouclier.lua"] = "test du bouclier (fausses attaques volontaires)",
	["lua/securite_tests/test_analyse.lua"] = "test de l'analyseur (échantillons de portes dérobées)",
}

local READ_EXT = { lua = true, txt = true, dat = true, json = true, cfg = true, vtf = true, vmt = true, png = true, jpg = true, jpeg = true }
-- En-têtes attendus : un fichier qui ne les a pas est un faux (code Lua déguisé)
local MAGIC = { vtf = "VTF\0", png = "\137PNG", jpg = "\255\216", jpeg = "\255\216" }

local DANGEROUS = { "RunString", "CompileString", "http.Fetch", "http.Post", "HTTP", "RunConsoleCommand", "game.ConsoleCommand", "SetUserGroup", "file.Read", "rcon_password", "materials/", ".vtf" }

---------------------------------------------------------------------------
-- Règles
---------------------------------------------------------------------------
local function lineAt(text, pos)
	local n = 1
	for _ in text:sub(1, pos):gmatch("\n") do n = n + 1 end
	return n
end

local function excerpt(text, pos)
	local s = pos
	while s > 1 and text:sub(s - 1, s - 1) ~= "\n" do s = s - 1 end
	local e = text:find("\n", pos, true) or (#text + 1)
	return string.Trim((text:sub(s, e - 1):gsub("[%c]", " "))):sub(1, 200)
end

local function decodeEscapes(s)
	s = s:gsub("\\x(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
	return (s:gsub("\\(%d%d?%d?)", function(d) d = tonumber(d) return d < 256 and string.char(d) or "" end))
end

local function hostsIn(text)
	local AS = AstralShield and AstralShield.BlockedHosts or {}
	local low = text:lower()
	for h in pairs(AS) do
		local p = low:find(h, 1, true)
		if p then return h, p end
	end
end

-- Ligne entièrement commentée (« -- » en début de ligne). Un « -- » plus loin dans la ligne ne compte pas :
-- il pourrait être dans une chaîne, placé exprès pour cacher le code qui suit.
local function commentLine(text, pos)
	local s = pos
	while s > 1 and text:sub(s - 1, s - 1) ~= "\n" do s = s - 1 end
	return text:sub(s, pos):match("^%s*%-%-") ~= nil
end

-- Bloc « --[[ … ]] » non refermé : utilisé seulement pour les SteamID (exemples dans la documentation)
local function inBlockComment(text, pos)
	local before = text:sub(1, pos)
	local open = select(2, before:gsub("%-%-%[=*%[", ""))
	local close = select(2, before:gsub("%]=*%]", ""))
	return open > close
end

-- Lignes officielles connues (Garry's Mod donne le rang superadmin à l'hôte d'une partie locale)
local KNOWN = {
	["lua/includes/extensions/player_auth.lua"] = 'ply:SetUserGroup( "superadmin" )',
}

-- Analyse du code Lua (ou de tout texte qui en contient). Retourne la liste des constats.
local function analyseCode(text)
	local found = {}
	local function add(sev, kind, pos, extra)
		if not extra and commentLine(text, pos) then return end
		found[#found + 1] = { severity = sev, kind = kind, line = lineAt(text, pos), excerpt = extra or excerpt(text, pos) }
	end

	local host, hp = hostsIn(text)
	if host then add("critique", "Adresse de porte dérobée connue (" .. host .. ")", hp) end

	-- Appels masqués en \x41 ou \65 : on décode chaque suite d'au moins 6 codes
	for s, run in text:gmatch("()(\\[%dx][%w\\]*)") do
		if select(2, run:gsub("\\", "")) >= 6 then
			local plain = decodeEscapes(run)
			for _, tok in ipairs(DANGEROUS) do
				if plain:find(tok, 1, true) then
					add("critique", "Appel masqué en codes hexadécimaux / décimaux (« " .. plain:gsub("[%c]", " "):sub(1, 60) .. " »)", s)
					break
				end
			end
			local h = hostsIn(plain)
			if h then add("critique", "Adresse de porte dérobée masquée (" .. h .. ")", s) end
		end
	end

	-- Code caché dans un tableau d'octets : { 12, 45, 210, … } (40 nombres ou plus)
	local p = 1
	while true do
		local s, e = text:find("{%s*%d+%s*,%s*%d+%s*,%s*%d+%s*,", p)
		if not s then break end
		local close = text:find("}", e, true) or #text
		local body = text:sub(s + 1, close - 1)
		local count = 0
		for _ in body:gmatch("%d+") do count = count + 1 end
		if count >= 40 and not body:find("[%a_\"']") then
			local exec = text:find("CompileString", 1, true) or text:find("RunString", 1, true)
			local char = text:find("string.char", 1, true) or text:find("utf8.char", 1, true)
			if exec and char then add("critique", "Code caché dans un tableau de " .. count .. " octets, décodé puis exécuté", s)
			elseif char or exec then add("haute", "Tableau de " .. count .. " octets converti en texte (code possiblement caché)", s) end
			break
		end
		p = close + 1
	end

	local fetch = text:find("http%.Fetch") or text:find("http%.Post") or text:find("[^%w_.]HTTP%s*%(")
	local exec = text:find("RunString") or text:find("CompileString")
	if fetch and exec then add("critique", "Télécharge du code sur Internet puis l'exécute (RunString / CompileString)", exec) end

	local fr = text:find("CompileString%s*%(%s*file%.Read") or text:find("RunString%s*%(%s*file%.Read") or text:find("RunStringEx%s*%(%s*file%.Read")
	if fr then add("critique", "Exécute le contenu d'un fichier de données (technique des fausses textures)", fr) end

	local nr = text:find("RunString%s*%(%s*net%.Read") or text:find("CompileString%s*%(%s*net%.Read")
	if nr then add("critique", "Exécute du code envoyé par le réseau (n'importe quel joueur peut prendre le contrôle)", nr)
	elseif exec and text:find("net%.ReadString") and text:find("net%.Receive") then
		add("moyenne", "Reçoit du texte d'un joueur et contient une exécution de code (à vérifier)", exec)
	end

	local dec = text:find("CompileString%s*%(%s*util%.Base64Decode") or text:find("RunString%s*%(%s*util%.Base64Decode")
		or text:find("CompileString%s*%(%s*util%.Decompress") or text:find("RunString%s*%(%s*util%.Decompress")
		or text:find("CompileString%s*%(%s*string%.reverse") or text:find("RunString%s*%(%s*string%.reverse")
	if dec then add("haute", "Exécute du code décodé (Base64, compressé ou inversé)", dec) end

	local su = text:find("SetUserGroup%s*%(%s*[\"']superadmin") or text:find("SetUserGroup%s*%(%s*[\"']admin")
	if su then add("haute", "Donne un rang d'administration directement dans le code", su) end

	local rc = text:find("rcon_password") or text:find("[\"']sv_password")
	if rc and (text:find("RunConsoleCommand") or text:find("game%.ConsoleCommand")) then
		add("haute", "Modifie le mot de passe RCON ou serveur", rc)
	end

	local sid = text:find("STEAM_0:%d:%d%d%d%d") or text:find("7656119%d%d%d%d%d%d%d%d%d%d")
	if sid and not inBlockComment(text, sid) and (text:find("SetUserGroup") or text:find("superadmin") or exec) then
		add("moyenne", "SteamID écrit en dur à côté de droits ou d'exécution de code (compte privilégié caché ?)", sid)
	end

	local g = text:find("_G%s*%[%s*string%.char") or text:find("_G%s*%[%s*string%.reverse") or text:find("getfenv%s*%(%s*%)%s*%[%s*string%.char")
	if g then add("moyenne", "Nom de fonction masqué (_G[string.char(…)])", g) end

	return found
end
SEC.AnalyseCode = analyseCode   -- utilisé par securite_tests/test_analyse.lua

---------------------------------------------------------------------------
-- Parcours
---------------------------------------------------------------------------
local function extOf(path) return (path:match("%.([%w]+)$") or ""):lower() end

local function analyseFile(job, path, pathID, addon, display)
	local ext = extOf(path)
	if not READ_EXT[ext] then return end
	if IGNORED[display] then job.ignored[#job.ignored + 1] = { path = display, reason = IGNORED[display] } return end
	local size = file.Size(path, pathID) or 0
	if size <= 0 or size > MAX_SIZE then return end
	local f = file.Open(path, "rb", pathID)
	if not f then return end
	local findings
	if MAGIC[ext] then
		local head = f:Read(#MAGIC[ext]) or ""
		if head ~= MAGIC[ext] then
			f:Seek(0)
			local text = f:Read(size) or ""
			if text:find("function", 1, true) or text:find("RunString", 1, true) or text:find("http.", 1, true) or text:find("timer.", 1, true) then
				findings = analyseCode(text)
				table.insert(findings, 1, { severity = "critique", kind = "Faux fichier ." .. ext .. " qui contient du code Lua", line = 1, excerpt = excerpt(text, 1) })
			end
		end
	else
		findings = analyseCode(f:Read(size) or "")
	end
	f:Close()
	job.files = job.files + 1
	job.bytes = job.bytes + size
	for _, fd in ipairs(findings or {}) do
		if KNOWN[display] == fd.excerpt then continue end
		fd.addon = addon
		fd.path = display
		job.findings[#job.findings + 1] = fd
	end
end

-- Liste récursive (coroutine) : yield régulier pour ne pas bloquer le serveur
local function walk(job, base, pathID, addon, prefix)
	local files, dirs = file.Find(base .. "*", pathID)
	for _, f in ipairs(files or {}) do
		analyseFile(job, base .. f, pathID, addon, prefix .. base .. f)
		if SysTime() - job.tick > BUDGET then coroutine.yield() end
	end
	for _, d in ipairs(dirs or {}) do
		if d ~= "." and d ~= ".." then walk(job, base .. d .. "/", pathID, addon, prefix) end
	end
end

local function run(job)
	-- Addons du dossier addons/
	local _, addons = file.Find("addons/*", "MOD")
	for _, a in ipairs(addons or {}) do walk(job, "addons/" .. a .. "/", "MOD", a, "") end
	-- Fichiers Lua hors addons et gamemodes
	walk(job, "lua/", "MOD", "dossier lua/ du serveur", "")
	local _, gms = file.Find("gamemodes/*", "MOD")
	for _, g in ipairs(gms or {}) do walk(job, "gamemodes/" .. g .. "/", "MOD", "gamemode " .. g, "") end
	-- Addons Workshop montés (contenu des .gma)
	for _, ad in ipairs(engine.GetAddons()) do
		if ad.mounted and ad.title then
			local label = "Workshop : " .. ad.title .. " (" .. tostring(ad.wsid) .. ")"
			job.workshop = job.workshop + 1
			for _, root in ipairs({ "lua/", "materials/", "data/" }) do
				walk(job, root, ad.title, label, "[" .. tostring(ad.wsid) .. "] ")
			end
		end
	end
end

local ORDER = { critique = 1, haute = 2, moyenne = 3 }

local function finish(job)
	table.sort(job.findings, function(a, b)
		if ORDER[a.severity] ~= ORDER[b.severity] then return ORDER[a.severity] < ORDER[b.severity] end
		if a.addon ~= b.addon then return a.addon < b.addon end
		return a.path < b.path
	end)
	local counts = { critique = 0, haute = 0, moyenne = 0 }
	for _, f in ipairs(job.findings) do counts[f.severity] = counts[f.severity] + 1 end
	local report = {
		started = job.started, finished = os.time(), duration = math.Round(SysTime() - job.clock, 1),
		files = job.files, bytes = job.bytes, workshop = job.workshop, counts = counts,
		findings = job.findings, ignored = job.ignored, by = job.by,
		shield = {
			active = AstralShield ~= nil, blocked = AstralShield and AstralShield.Blocked or 0,
			hosts = AstralShield and table.GetKeys(AstralShield.BlockedHosts) or {},
		},
	}
	file.CreateDir(OUT_DIR)
	file.Write(OUT, util.TableToJSON(report))
	SEC.Last = report
	SEC.Job = nil
	local summary = string.format("Analyse terminée : %d fichiers, %d critique(s), %d haute(s), %d moyenne(s) en %.1f s",
		job.files, counts.critique, counts.haute, counts.moyenne, report.duration)
	Astral.Log("security", summary)
	Astral.Logs.Write("security_scan", nil, { files = job.files, critique = counts.critique, haute = counts.haute, moyenne = counts.moyenne, by = job.by })
	if counts.critique + counts.haute > 0 then
		for _, p in ipairs(player.GetAll()) do
			if p:IsSuperAdmin() then p:ChatPrint("[Astral Shield] " .. summary .. " — détails dans le panel, onglet Sécurité.") end
		end
	end
end

function SEC.Scan(by)
	if SEC.Job then return false end
	local job = { started = os.time(), clock = SysTime(), tick = SysTime(), files = 0, bytes = 0, workshop = 0, findings = {}, ignored = {}, by = by or "console" }
	job.co = coroutine.create(run)
	SEC.Job = job
	timer.Create("Astral.Security.Scan", 0, 0, function()
		job.tick = SysTime()
		local ok, err = coroutine.resume(job.co, job)
		if not ok then
			timer.Remove("Astral.Security.Scan")
			SEC.Job = nil
			Astral.Log("security", "Analyse interrompue : " .. tostring(err))
			return
		end
		if coroutine.status(job.co) == "dead" then
			timer.Remove("Astral.Security.Scan")
			finish(job)
		end
	end)
	return true
end

concommand.Add("astral_securite_analyse", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	local who = IsValid(ply) and ply:Nick() or "console"
	if SEC.Scan(who) then print("[Astral] Analyse de sécurité lancée") else print("[Astral] Une analyse est déjà en cours") end
end)

-- Vérification de syntaxe après suppression d'une ligne depuis le panel (le panel remet le fichier d'origine
-- si la ligne retirée casse le fichier). Compilation seule, rien n'est exécuté.
-- Usage : astral_securite_syntaxe <jeton> <chemin relatif à garrysmod/>
concommand.Add("astral_securite_syntaxe", function(ply, _, args)
	if IsValid(ply) then return end
	local id, path = args[1] or "?", table.concat(args, " ", 2)
	local function say(state, msg) print(string.format("[Astral Syntaxe] %s %s %s", id, state, msg or "")) end
	if not path:match("^[%w_%-./ !]+%.lua$") or path:find("..", 1, true) then return say("ERREUR", "chemin refusé") end
	local text = file.Read(path, "MOD")
	if not text then return say("ERREUR", "fichier introuvable") end
	-- Les noms surveillés par le bouclier sont renommés (même longueur, même syntaxe) : sinon un fichier qui
	-- contient encore un chargeur serait refusé avant même d'être compilé
	local probe = text:gsub("RunString", "RunStrinq"):gsub("CompileString", "CompileStrinq")
	local res = CompileString(probe, path, false)
	if isfunction(res) then say("OK") else say("ERREUR", tostring(res)) end
end)

timer.Simple(30, function() SEC.Scan("démarrage") end)
