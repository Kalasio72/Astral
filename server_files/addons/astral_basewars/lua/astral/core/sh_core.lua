-- Astral BaseWars — fonctions communes du socle.

local colTag = SERVER and Color(120, 200, 255) or Color(180, 140, 255)
local colText = Color(230, 230, 230)

-- Journal console : Astral.Log("categorie", "message")
function Astral.Log(category, msg)
	MsgC(colTag, "[Astral:" .. tostring(category) .. "] ", colText, tostring(msg), "\n")
end

-- Lecture sûre d'une valeur de configuration : Astral.Cfg("Logs.FlushInterval", 10)
function Astral.Cfg(path, fallback)
	local node = Astral.Config
	for key in string.gmatch(path, "[^%.]+") do
		if not istable(node) then return fallback end
		node = node[key]
	end
	if node == nil then return fallback end
	return node
end

-- Écriture d'une valeur de configuration (crée les tables intermédiaires) : Astral.SetCfg("Market.TaxPercent", 5)
function Astral.SetCfg(path, value)
	local node, keys = Astral.Config, {}
	for key in string.gmatch(path, "[^%.]+") do keys[#keys + 1] = key end
	for i = 1, #keys - 1 do
		node[keys[i]] = istable(node[keys[i]]) and node[keys[i]] or {}
		node = node[keys[i]]
	end
	node[keys[#keys]] = value
end

-- Identifiant stable d'un joueur pour la base (SteamID64), ou nil
function Astral.PlayerID(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return nil end
	if ply:IsBot() then return nil end
	return ply:SteamID64()
end
