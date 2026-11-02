-- Astral BaseWars — équilibrage en jeu : réglages modifiables depuis le menu admin (onglet « Équilibrage »).
--
-- Seuls les réglages de la liste EDITABLE peuvent être changés, chacun validé par sa règle (sv_config.lua) :
-- type, entier, minimum, maximum. Les valeurs modifiées sont enregistrées dans astral_settings, réappliquées au
-- démarrage et envoyées aux clients (certaines servent à l'affichage : prix des ressources, bornes du marché).
-- « Rétablir » réécrit la valeur par défaut du fichier de configuration (aucune ligne supprimée).

Astral.Settings = Astral.Settings or {}
local ST = Astral.Settings
util.AddNetworkString("Astral.Settings.Sync")

-- Groupes affichés dans le menu, dans cet ordre ; label en français
local EDITABLE = {
	{ "Économie", "Economy.AlertGain", "Alerte : gain maximal sur la fenêtre (£)" },
	{ "Économie", "Economy.AlertWindow", "Alerte : fenêtre de surveillance (s)" },
	{ "Industrie", "Industry.DrillSecondsPerOre", "Foreuse : secondes par minerai" },
	{ "Industrie", "Industry.DrillBuffer", "Foreuse : stock interne" },
	{ "Industrie", "Industry.RefinerySecondsPerIngot", "Raffinerie : secondes par lingot" },
	{ "Industrie", "Industry.RefineryOrePerIngot", "Raffinerie : minerais par lingot" },
	{ "Industrie", "Industry.RefineryBuffer", "Raffinerie : stock interne" },
	{ "Industrie", "Industry.ContainerCapacity", "Conteneur : capacité" },
	{ "Industrie", "Industry.TransferRadius", "Rayon d'échange entre machines" },
	{ "Marché", "Market.TaxPercent", "Taxe sur les ventes (%)" },
	{ "Marché", "Market.MaxOrders", "Offres ouvertes par joueur" },
	{ "Marché", "Market.MaxQty", "Unités maximum par offre" },
	{ "Marché", "Market.MinPriceFactor", "Prix minimum (× valeur de référence)" },
	{ "Marché", "Market.MaxPriceFactor", "Prix maximum (× valeur de référence)" },
	{ "Événements", "Events.AutoInterval", "Intervalle entre événements auto (s)" },
	{ "Événements", "Events.Duration", "Durée d'un événement (s)" },
	{ "Événements", "Events.MinPlayers", "Joueurs minimum pour un événement" },
}

-- Prix de vente au serveur de chaque ressource : réglage « Resources.<id>.value »
local RES_RULE = { type = "number", integer = true, min = 1, max = 10000000 }
for _, id in ipairs(Astral.Resources.order) do
	local r = Astral.Resources.Get(id)
	EDITABLE[#EDITABLE + 1] = { "Prix des ressources", "Resources." .. id .. ".value", r.name }
end

local byPath = {}
for _, e in ipairs(EDITABLE) do byPath[e[2]] = e end

local function resId(path) return path:match("^Resources%.([%w_]+)%.value$") end

local function rule(path)
	if resId(path) then return RES_RULE end
	return Astral.ConfigRules[path]
end

local function current(path)
	local id = resId(path)
	if id then local r = Astral.Resources.Get(id) return r and r.value end
	return Astral.Cfg(path)
end

local function apply(path, value)
	local id = resId(path)
	if id then
		local r = Astral.Resources.Get(id)
		if r then r.value = value end
	else
		Astral.SetCfg(path, value)
	end
end

-- Valeurs par défaut = celles du fichier de configuration, capturées avant toute surcharge
ST.Defaults = ST.Defaults or {}
for _, e in ipairs(EDITABLE) do if ST.Defaults[e[2]] == nil then ST.Defaults[e[2]] = current(e[2]) end end

ST.Overrides = ST.Overrides or {}   -- [path] = valeur appliquée (différente ou non du défaut)

local function sendSync(target)
	net.Start("Astral.Settings.Sync")
	net.WriteTable(ST.Overrides)
	if target then net.Send(target) else net.Broadcast() end
end

-- Convertit et valide le texte saisi ; renvoie valeur, nil ou nil, message
local function parse(path, text)
	local r = rule(path)
	if not byPath[path] or not r then return nil, "Réglage non modifiable." end
	local v = tonumber((tostring(text or ""):gsub(",", "."):gsub("%s", "")))
	if not v then return nil, "Valeur numérique attendue." end
	local err = Astral.CheckConfigValue(v, r)
	if err then return nil, err end
	return v
end

-- Modifie un réglage (admin) ; done(ok, message)
function ST.Set(ply, path, text, done)
	local v, err = parse(path, text)
	if v == nil then return done(false, err) end
	local old = current(path)
	Astral.DB.Conn():Execute([[INSERT INTO astral_settings (path, value, updated_by, updated_at) VALUES ({1}, {2}, NULLIF({3}, ''), {4})
		ON DUPLICATE KEY UPDATE value = VALUES(value), updated_by = VALUES(updated_by), updated_at = VALUES(updated_at)]], {
		params = { path, tostring(v), Astral.PlayerID(ply) or "", os.time() },
		callback = function(e)
			if e then return done(false, "Erreur d'enregistrement : " .. tostring(e)) end
			apply(path, v)
			ST.Overrides[path] = v
			sendSync()
			Astral.Logs.Write("admin_action", ply, { action = "setting", path = path, old = old, new = v })
			Astral.Log("settings", string.format("%s : %s → %s (%s)", path, tostring(old), tostring(v), IsValid(ply) and ply:Nick() or "console"))
			done(true, string.format("%s : %s → %s", byPath[path][3], tostring(old), tostring(v)))
		end,
	})
end

function ST.List()
	local list = {}
	for _, e in ipairs(EDITABLE) do
		local r = rule(e[2]) or {}
		list[#list + 1] = { group = e[1], path = e[2], label = e[3], value = current(e[2]), default = ST.Defaults[e[2]], min = r.min, max = r.max, integer = r.integer or false }
	end
	return list
end

-- Démarrage : réapplique les réglages enregistrés (une valeur devenue invalide est ignorée et signalée)
Astral.DB.OnReady(function(db)
	db:Fetch("SELECT path, value FROM astral_settings", { callback = function(e, rows)
		if e then return Astral.Log("settings", "ERREUR chargement : " .. tostring(e)) end
		local n = 0
		for _, r in ipairs(rows or {}) do
			local v, err = parse(r.path, r.value)
			if v ~= nil then apply(r.path, v) ST.Overrides[r.path] = v n = n + 1
			else Astral.Log("settings", "IGNORÉ " .. tostring(r.path) .. " = " .. tostring(r.value) .. " (" .. tostring(err) .. ")") end
		end
		Astral.Log("settings", n .. " réglage(s) d'équilibrage appliqué(s)")
		if n > 0 then sendSync() end
	end })
end)

hook.Add("PlayerInitialSpawn", "Astral.Settings", function(ply)
	timer.Simple(5, function() if IsValid(ply) and next(ST.Overrides) then sendSync(ply) end end)
end)
