-- Astral BaseWars — chargeur du socle (partagé serveur/client).
-- Le gamemode BaseWars doit être chargé avant le socle : le chargement réel se fait sur PostGamemodeLoaded.

Astral = Astral or {}
Astral.Version = "0.1.0"

local SHARED = {
	"astral/config/sh_config.lua",
	"astral/core/sh_core.lua",
	"astral/industry/sh_resources.lua",
	"astral/industry/sh_spawnlist.lua",
	"astral/industry/sh_printers.lua",
	"astral/industry/sh_looks.lua",
	"astral/farms/sh_farms.lua",
	"astral/world/sh_adverts.lua",
	"astral/quests/sh_quests.lua",
	"astral/events/sh_events.lua",
	"astral/research/sh_research.lua",
}
local SERVER_ONLY = {
	"astral/core/sv_config.lua",
	"astral/core/sv_permissions.lua",
	"astral/core/sv_net.lua",
	"astral/core/sv_db.lua",
	"astral/core/sv_logs.lua",
	"astral/core/sv_diag.lua",
	"astral/economy/sv_economy.lua",
	"astral/economy/sv_upgrade.lua",
	"astral/admin/sv_admin.lua",
	"astral/industry/sv_industry.lua",
	"astral/industry/sv_printers.lua",
	"astral/world/sv_npcs.lua",
	"astral/farms/sv_farms.lua",
	"astral/social/sv_commands.lua",
	"astral/quests/sv_quests.lua",
	"astral/events/sv_events.lua",
	"astral/research/sv_research.lua",
	"astral/stats/sv_stats.lua",
	"astral/factions/sv_factions.lua",
	"astral/market/sv_market.lua",
	"astral/admin/sv_settings.lua",
	"astral/admin/sv_security.lua",
}
local CLIENT_ONLY = {
	"astral/core/cl_core.lua",
	"astral/ui/cl_theme.lua",
	"astral/ui/cl_overlays.lua",
	"astral/ui/cl_hud.lua",
	"astral/ui/cl_shop.lua",
	"astral/ui/cl_menu.lua",
	"astral/ui/cl_printers.lua",
	"astral/ui/cl_printerlook.lua",
	"astral/ui/cl_looks.lua",
	"astral/ui/cl_npcs.lua",
	"astral/ui/cl_farms.lua",
	"astral/ui/cl_events.lua",
	"astral/ui/cl_social.lua",
	"astral/ui/cl_scoreboard.lua",
	"astral/ui/cl_pausemenu.lua",
	"astral/ui/cl_compat.lua",
	"astral/ui/cl_upgrade.lua",
	"astral/ui/cl_welcome.lua",
	"astral/ui/cl_chat.lua",
	"astral/industry/cl_industry.lua",
	"astral/admin/cl_admin.lua",
}

if SERVER then
	for _, f in ipairs(SHARED) do AddCSLuaFile(f) end
	for _, f in ipairs(CLIENT_ONLY) do AddCSLuaFile(f) end
end

local function load()
	if not BaseWars then
		MsgC(Color(255, 80, 80), "[Astral] BaseWars introuvable : le socle Astral n'est pas chargé.\n")
		return
	end
	for _, f in ipairs(SHARED) do include(f) end
	if SERVER then
		for _, f in ipairs(SERVER_ONLY) do include(f) end
	else
		for _, f in ipairs(CLIENT_ONLY) do include(f) end
	end
	hook.Run("Astral.CoreLoaded")
	Astral.Log("core", "Socle Astral " .. Astral.Version .. " chargé")
end

hook.Add("PostGamemodeLoaded", "Astral.Load", load)
