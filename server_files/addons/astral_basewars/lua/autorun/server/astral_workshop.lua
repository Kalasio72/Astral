-- Astral BaseWars — contenu Workshop envoyé aux joueurs à la connexion.
-- Le serveur télécharge déjà ces items via la collection (WORKSHOP_ID) ; sans resource.AddWorkshop,
-- les clients ne les reçoivent pas et voient des modèles manquants.

local WORKSHOP_ITEMS = {
	"349050451", -- Chuck's Weaponry 2.0 (CW 2.0)
	"358608166", -- Extra Chuck's Weaponry 2.0
	"108424005", -- Keypad Tool and Cracker (Willox)
}

-- La map en cours est envoyée seulement si elle vient du Workshop (évite 114 Mo de téléchargement inutile)
local MAP_ITEMS = {
	["basewars_evocity_v2"] = "296828130",
	["basewars_bangclaw_v1"] = "425998560",
}
local mapItem = MAP_ITEMS[string.lower(game.GetMap())]
if mapItem then resource.AddWorkshop(mapItem) end

for _, id in ipairs(WORKSHOP_ITEMS) do
	resource.AddWorkshop(id)
end
