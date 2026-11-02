-- Compatibilité client : un addon tiers qui plante à la connexion ne doit pas bloquer les autres.
--
-- Constaté le 2026-11-02 (13 h 40) : le hook InitPostEntity « atlaschat.CreateChatbox » plante
-- (addons/pixel-ui-master/lua/pixelui/core/cl_color.lua:167). Une erreur dans un hook interrompt toute la chaîne :
-- les hooks suivants ne s'exécutent jamais. Conséquences : argent affiché à £0 (BaseWars.Money.Ready jamais lancé),
-- erreur Customizable Weaponry 2.0 à chaque image (CW20_Grenade_InitPostEntity jamais lancé).
--
-- Correctif : au chargement d'Astral (avant la connexion), chaque hook de connexion des addons tiers est protégé.
-- S'il plante, l'erreur est affichée en console et les suivants s'exécutent quand même.

local GUARDED_EVENTS = { "InitPostEntity" }

local function guard(event)
	local list = hook.GetTable()[event]
	if not list then return end
	for name, fn in pairs(table.Copy(list)) do
		local id = tostring(name)
		if isfunction(fn) and not id:find("^Astral") then
			hook.Add(event, name, function(...)
				local res = { pcall(fn, ...) }
				if not res[1] then
					ErrorNoHalt(string.format("[Astral] Le hook %s « %s » a planté (les autres continuent) : %s\n", event, id, tostring(res[2])))
					return
				end
				return unpack(res, 2)
			end)
		end
	end
end

for _, e in ipairs(GUARDED_EVENTS) do guard(e) end

-- Filet de sécurité : si l'initialisation de CW 2.0 manque malgré tout, on la relance
local function fixCW()
	local me = LocalPlayer()
	if not IsValid(me) or me.cwFlashbangDuration ~= nil then return end
	local init = (hook.GetTable().InitPostEntity or {}).CW20_Grenade_InitPostEntity
	if init then
		init()
		print("[Astral] Initialisation de Customizable Weaponry 2.0 relancée")
	end
end
hook.Add("InitPostEntity", "Astral.Compat", function() timer.Simple(3, fixCW) end)
