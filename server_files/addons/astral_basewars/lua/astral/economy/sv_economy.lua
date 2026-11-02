-- Astral BaseWars — Astral Economy : journal de toutes les variations d'argent et détection d'anomalies.
-- Tout l'argent BaseWars passe par Economy:SetMoney (GiveMoney/TakeMoney/TransferMoney l'appellent).
-- On l'enveloppe une seule fois : l'argent reste géré par BaseWars, Astral ne fait qu'observer.
--
-- Chaque variation → ligne « money » dans astral_logs : { delta, balance, source }.
-- La source est déduite du fichier appelant (achat, paye, imprimante, revente, admin, Astral…).

Astral.Economy = Astral.Economy or {}
local E = Astral.Economy
E.Windows = E.Windows or {}

-- Correspondance fichier appelant → source lisible. Le premier motif trouvé dans la pile gagne.
local SOURCES = {
	{ "spawnmenu.lua", "achat" },
	{ "sv_payday.lua", "paye" },
	{ "moneyprinter", "imprimante" },
	{ "bw_vault", "coffre" },
	{ "sh_payout.lua", "remboursement/destruction" },
	{ "commands.lua", "commande" },
	{ "integration/ulx", "admin_ulx" },
	{ "integration/sam", "admin_sam" },
	{ "sv_bounty.lua", "prime" },
	{ "mysql.lua", "chargement" },
	{ "sv_money.lua", nil }, -- interne à BaseWars : on continue à remonter
	{ "astral/economy", nil },
	{ "astral/industry", "astral_industrie" },
	{ "entities/", "entite" },
	{ "lua_run", "console" },
}

-- Renvoie la source du premier fichier de la pile qui n'est pas un intermédiaire (motif associé à nil)
local function classify(src)
	for _, pair in ipairs(SOURCES) do
		if src:find(pair[1], 1, true) then return pair[2] or false end
	end
	return src:match("([^/]+)$") or "inconnu"
end

local function detectSource()
	for level = 3, 14 do
		local info = debug.getinfo(level, "S")
		if not info then break end
		local label = classify(info.short_src or "")
		if label then return label end
	end
	return "inconnu"
end

-- Somme glissante des gains par joueur ; alerte une fois par fenêtre si le seuil est dépassé
local function trackGain(ply, delta, source)
	if delta <= 0 or source == "chargement" then return end
	local sid = Astral.PlayerID(ply)
	if not sid then return end
	local now = CurTime()
	local window = Astral.Cfg("Economy.AlertWindow", 300)
	local w = E.Windows[sid]
	if not w or now - w.start > window then
		w = { start = now, gain = 0, alerted = false }
		E.Windows[sid] = w
	end
	w.gain = w.gain + delta
	if w.alerted or w.gain < Astral.Cfg("Economy.AlertGain", 5000000) then return end
	w.alerted = true
	Astral.Logs.Write("economy_alert", ply, { gain = w.gain, window = window, last_source = source })
	local msg = string.format("[Astral] Alerte économie : %s a gagné %s en moins de %d s (dernière source : %s)",
		ply:Nick(), BaseWars.NumberFormat(w.gain), window, source)
	Astral.Log("economy", msg)
	for _, admin in player.Iterator() do
		Astral.HasAccess(admin, "Logs", function(allowed)
			if allowed and IsValid(admin) then admin:ChatPrint(msg) end
		end)
	end
end

local function install()
	local eco = BaseWars.Economy
	if not eco or E.Installed then return end
	local original = getmetatable(eco).__index.SetMoney
	E.Installed = true
	eco.SetMoney = function(self, ply, amount)
		local before = ply.BaseWarsMoney
		original(self, ply, amount)
		if before == nil or not IsValid(ply) then return end -- premier chargement depuis la base
		local after = ply.BaseWarsMoney or 0
		local delta = after - before
		if delta == 0 then return end
		local source = detectSource()
		Astral.Logs.Write("money", ply, { delta = delta, balance = after, source = source })
		trackGain(ply, delta, source)
	end
	Astral.Log("economy", "Journal des transactions actif")
end

install()

hook.Add("PlayerDisconnected", "Astral.Economy.Cleanup", function(ply)
	local sid = Astral.PlayerID(ply)
	if sid then E.Windows[sid] = nil end
end)
