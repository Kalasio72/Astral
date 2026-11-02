-- Astral Shield — bouclier anti-porte dérobée (serveur uniquement).
--
-- Nommé « !!!… » pour être chargé AVANT les autres fichiers autorun/server (ordre alphabétique, tous addons
-- confondus) : les portes dérobées qui capturent CompileString au chargement récupèrent donc la version surveillée.
--
-- Protections :
--   1. Adresses de portes dérobées connues bloquées (http.Fetch, http.Post, HTTP).
--   2. Code téléchargé puis exécuté : tout RunString / RunStringEx / CompileString appelé PENDANT le traitement
--      d'une réponse HTTP est refusé (c'est le mécanisme de toutes les portes dérobées trouvées le 2026-11-02).
--   3. Code qui contient à la fois un téléchargement et une exécution (signature des fausses textures .vtf)
--      refusé à la compilation.
--   4. Promotion en admin/superadmin faite hors ULX/ULib/CAMI/Astral bloquée.
--   5. Commandes console sensibles (rcon_password, sv_password, ulx adduser…) refusées depuis une réponse HTTP.
-- Chaque blocage est affiché en rouge dans la console, envoyé aux superadmins connectés et écrit dans le journal
-- Astral (catégorie « security », visible dans le panel et le menu admin).

if not SERVER or AstralShield then return end
AstralShield = { Blocked = 0, Pending = {}, Version = 1 }
local S = AstralShield

S.BlockedHosts = {
	["kvcdoor.ovh"] = true, ["panelpetitvac.xyz"] = true, ["vcmod.xyz"] = true, ["sinax.site"] = true,
}

local origRunString, origRunStringEx, origCompileString = RunString, RunStringEx, CompileString
local origFetch, origPost, origHTTP = http.Fetch, http.Post, HTTP
local origRunConsoleCommand = RunConsoleCommand
local origGameConsoleCommand = game.ConsoleCommand
local inHttpCallback = 0

-- Fichier Lua qui a déclenché l'appel : premier fichier .lua hors de ce bouclier dans la pile (« chemin:ligne »),
-- plus les autres fichiers de la pile. Un code compilé à la volée (CompileString) a un nom arbitraire : on remonte
-- jusqu'au vrai fichier qui l'a lancé.
local function caller()
	local chain, first = {}, nil
	for level = 3, 16 do
		local info = debug.getinfo(level, "Sl")
		if not info then break end
		local src = (info.short_src or "?"):gsub("\\", "/")
		if not src:find("astral_shield", 1, true) and src ~= "[C]" then
			local at = src .. ":" .. tostring(info.currentline or 0)
			if #chain < 5 then chain[#chain + 1] = at end
			if not first and src:find("%.lua$") then first = at end
		end
	end
	return first or chain[1] or "?", chain
end

-- Addon auquel appartient un fichier (« addons/<nom>/… », gamemode, dossier lua/ ou addon Workshop)
function S.AddonOf(src)
	src = tostring(src or ""):gsub("\\", "/"):gsub(":%d+$", "")
	local a = src:match("^addons/([^/]+)/")
	if a then return a end
	local g = src:match("^gamemodes/([^/]+)/")
	if g then return "gamemode " .. g end
	if src:match("^lua/") then
		if file.Exists(src, "MOD") then return "dossier lua/ du serveur" end
		for _, ad in ipairs(engine.GetAddons()) do
			if ad.mounted and ad.title and file.Exists(src, ad.title) then return "Workshop : " .. ad.title .. " (" .. tostring(ad.wsid) .. ")" end
		end
	end
	return "inconnu"
end

local function hostOf(url)
	local host = tostring(url or ""):lower():match("^%a+://([^/:%?#]+)")
	return host or ""
end

local function isBlockedHost(url)
	local host = hostOf(url)
	if S.BlockedHosts[host] then return true end
	for h in pairs(S.BlockedHosts) do if host:sub(-#h - 1) == "." .. h then return true end end
	return false
end

function S.Alert(kind, detail)
	S.Blocked = S.Blocked + 1
	local src, chain = caller()
	-- Pendant une réponse HTTP, le vrai responsable est le fichier qui a envoyé la requête
	if S.Origin then src = S.Origin end
	local addon = S.AddonOf(src)
	local line = string.format("[Astral Shield] BLOQUÉ (%s) : %s — addon : %s — fichier : %s", kind, tostring(detail):sub(1, 180), addon, src)
	MsgC(Color(255, 80, 80), line, "\n")
	local entry = { kind = kind, detail = tostring(detail):sub(1, 300), source = src, addon = addon, chain = chain, time = os.time() }
	if Astral and Astral.Logs and Astral.Logs.Write then
		Astral.Logs.Write("security", nil, entry)
	else
		S.Pending[#S.Pending + 1] = entry   -- journal pas encore chargé : écrit au chargement d'Astral
	end
	for _, p in ipairs(player.GetAll()) do
		if IsValid(p) and p:IsSuperAdmin() then p:ChatPrint("[Astral Shield] Tentative bloquée (" .. kind .. ") — addon : " .. addon .. " — voir l'onglet Sécurité du panel.") end
	end
end

-- Code qui télécharge puis exécute : signature des fausses textures
local function looksLikeLoader(code)
	if not isstring(code) then return false end
	local fetch = code:find("http.Fetch", 1, true) or code:find("http.Post", 1, true) or code:find("HTTP(", 1, true)
	local exec = code:find("RunString", 1, true) or code:find("CompileString", 1, true)
	return fetch and exec and true or false
end

---------------------------------------------------------------------------
-- Exécution de code
---------------------------------------------------------------------------
function RunString(code, id, handleError)
	if inHttpCallback > 0 then S.Alert("code téléchargé exécuté", "RunString pendant une réponse HTTP") return "Bloqué par Astral Shield" end
	if looksLikeLoader(code) then S.Alert("chargeur de code distant", code) return "Bloqué par Astral Shield" end
	return origRunString(code, id, handleError)
end

function RunStringEx(code, id, handleError)
	if inHttpCallback > 0 then S.Alert("code téléchargé exécuté", "RunStringEx pendant une réponse HTTP") return "Bloqué par Astral Shield" end
	if looksLikeLoader(code) then S.Alert("chargeur de code distant", code) return "Bloqué par Astral Shield" end
	return origRunStringEx(code, id, handleError)
end

function CompileString(code, id, handleError)
	if inHttpCallback > 0 then
		S.Alert("code téléchargé compilé", "CompileString pendant une réponse HTTP")
		return handleError == false and "Bloqué par Astral Shield" or function() end
	end
	if looksLikeLoader(code) then
		S.Alert("chargeur de code distant", code)
		return handleError == false and "Bloqué par Astral Shield" or function() end
	end
	return origCompileString(code, id, handleError)
end

---------------------------------------------------------------------------
-- Réseau
---------------------------------------------------------------------------
-- origin : fichier qui a envoyé la requête, mémorisé pour attribuer un blocage survenu dans la réponse
local function guard(cb, origin)
	if not isfunction(cb) then return cb end
	return function(...)
		inHttpCallback = inHttpCallback + 1
		local prev = S.Origin
		S.Origin = origin
		local ok, err = pcall(cb, ...)
		S.Origin = prev
		inHttpCallback = inHttpCallback - 1
		if not ok then ErrorNoHalt(err .. "\n") end
	end
end

function http.Fetch(url, onSuccess, onFailure, headers)
	if isBlockedHost(url) then S.Alert("adresse de porte dérobée", url) if isfunction(onFailure) then onFailure("blocked") end return end
	return origFetch(url, guard(onSuccess, (caller())), onFailure, headers)
end

function http.Post(url, params, onSuccess, onFailure, headers)
	if isBlockedHost(url) then S.Alert("adresse de porte dérobée", url) if isfunction(onFailure) then onFailure("blocked") end return end
	return origPost(url, params, guard(onSuccess, (caller())), onFailure, headers)
end

function HTTP(req)
	if istable(req) then
		if isBlockedHost(req.url) then S.Alert("adresse de porte dérobée", req.url) if isfunction(req.failed) then req.failed("blocked") end return false end
		req.success = guard(req.success, (caller()))
	end
	return origHTTP(req)
end

---------------------------------------------------------------------------
-- Commandes console sensibles depuis une réponse HTTP
---------------------------------------------------------------------------
local SENSITIVE = { rcon_password = true, sv_password = true, ulx = true, lua_run = true, sv_allowcslua = true, sv_cheats = true }
local function sensitive(cmd) return SENSITIVE[string.lower(string.Trim(tostring(cmd or "")):match("^(%S+)") or "")] end

function RunConsoleCommand(cmd, ...)
	if inHttpCallback > 0 and sensitive(cmd) then S.Alert("commande console depuis Internet", cmd) return end
	return origRunConsoleCommand(cmd, ...)
end

function game.ConsoleCommand(str)
	if inHttpCallback > 0 and sensitive(str) then S.Alert("commande console depuis Internet", str) return end
	return origGameConsoleCommand(str)
end

---------------------------------------------------------------------------
-- Changements de rang hors des outils d'administration
---------------------------------------------------------------------------
local TRUSTED = { "ulib/", "ulx/", "astral", "cami", "sam/", "serverguard", "fadmin" }
local function trusted()
	for level = 3, 14 do
		local info = debug.getinfo(level, "S")
		if not info then break end
		local src = (info.short_src or ""):lower()
		for _, t in ipairs(TRUSTED) do if src:find(t, 1, true) then return true end end
	end
	return false
end

local PLAYER = FindMetaTable("Player")
local origSetUserGroup = PLAYER.SetUserGroup
function PLAYER:SetUserGroup(group)
	local g = string.lower(tostring(group or ""))
	if g ~= "user" and g ~= "" and not trusted() then
		S.Alert("promotion de rang hors ULX", tostring(IsValid(self) and self:Nick() or "?") .. " → " .. g)
		return
	end
	return origSetUserGroup(self, group)
end

-- Journal Astral : écrit les blocages survenus avant son chargement
hook.Add("Astral.CoreLoaded", "AstralShield.Flush", function()
	for _, e in ipairs(S.Pending) do Astral.Logs.Write("security", nil, e) end
	S.Pending = {}
	Astral.Log("shield", "Bouclier actif (" .. S.Blocked .. " blocage(s) depuis le démarrage)")
end)

MsgC(Color(120, 200, 255), "[Astral Shield] Bouclier anti-porte dérobée chargé\n")
