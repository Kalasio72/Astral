-- Astral UI — tableau des joueurs (touche Tab).
--
-- Maintenir Tab : affichage rapide. Clic dans le tableau : il reste ouvert (mode épinglé) pour chercher, trier ou
-- agir sur un joueur ; on le ferme avec la croix, Échap ou Tab.
-- Colonnes : joueur (+ faction), rang, niveau, temps de jeu, frags, morts, ping. Onglets Tous / Factions / Staff,
-- recherche par nom ou SteamID, tri en cliquant sur une colonne.
-- Fiche joueur (clic sur une ligne) : profil Steam, SteamID, message privé, micro, masquer son chat ; actions staff
-- (aller à, amener, renvoyer, geler, observer, muet, kick, ban) affichées seulement si le rang ULX les autorise.
-- L'argent des autres joueurs n'est pas affiché (le tableau d'origine ne le montre pas).
-- Hook en priorité haute : il passe avant les autres tableaux installés. « astral_hud 0 » rend la main au précédent.

local UI = Astral.UI
local C, S = UI.Colors, UI.Scale

Astral.Scoreboard = Astral.Scoreboard or { Blocked = {} }
local SB = Astral.Scoreboard

local RANKS = {
	superadmin = { "Fondateur", Color(255, 105, 115), 5 },
	admin = { "Admin", Color(255, 200, 90), 4 },
	moderator = { "Modérateur", Color(110, 225, 150), 3 },
	operator = { "Modérateur", Color(110, 225, 150), 3 },
	vip = { "VIP", Color(170, 130, 255), 2 },
}

local function rankOf(ply)
	local g = ply:GetUserGroup()
	local r = RANKS[g]
	if r then return r[1], r[2], r[3] end
	if g == "user" or g == "" then return nil, nil, 1 end
	return g:sub(1, 1):upper() .. g:sub(2), C.dim, 1
end

local function factionOf(ply)
	if ply.InFaction and ply:InFaction() then return team.GetName(ply:Team()), team.GetColor(ply:Team()) end
end

local function playTime(ply) return ply.GetPlayTime and (ply:GetPlayTime() or 0) or 0 end
local function fmtTime(s)
	s = math.floor(s or 0)
	local h = math.floor(s / 3600)
	if h >= 1 then return h .. " h" end
	return math.floor(s / 60) .. " min"
end

local function pingColor(p)
	if p < 80 then return C.good elseif p < 150 then return C.warn end
	return C.bad
end

-- Cible ULX : « $SteamID » pour un joueur, « $userid » pour un bot
local function target(ply) return "$" .. (ply:IsBot() and ply:UserID() or ply:SteamID()) end
local function can(cmd)
	local me = LocalPlayer()
	if ULib and ULib.ucl and ULib.ucl.query then return ULib.ucl.query(me, cmd) end
	return me:IsAdmin()
end
local function ulx(cmd, ply, ...) RunConsoleCommand("ulx", cmd, target(ply), ...) end

-- Colonnes : clé de tri, titre, position (fraction de la largeur), alignement
local COLS = {
	{ "name", "JOUEUR", 0, TEXT_ALIGN_LEFT },
	{ "rank", "RANG", 0.37, TEXT_ALIGN_LEFT },
	{ "level", "NIVEAU", 0.56, TEXT_ALIGN_CENTER },
	{ "time", "TEMPS DE JEU", 0.66, TEXT_ALIGN_CENTER },
	{ "frags", "FRAGS", 0.76, TEXT_ALIGN_CENTER },
	{ "deaths", "MORTS", 0.84, TEXT_ALIGN_CENTER },
	{ "ping", "PING", 0.93, TEXT_ALIGN_CENTER },
}
local SORTERS = {
	name = function(p) return p:Nick():lower() end,
	rank = function(p) return select(3, rankOf(p)) end,
	level = function(p) return p.GetLevel and p:GetLevel() or 0 end,
	time = playTime,
	frags = function(p) return p:Frags() end,
	deaths = function(p) return p:Deaths() end,
	ping = function(p) return p:Ping() end,
}

local board
SB.sort, SB.desc, SB.tab, SB.query = SB.sort or "rank", SB.desc ~= false, SB.tab or "all", ""

---------------------------------------------------------------------------
-- Lignes
---------------------------------------------------------------------------
local function pingBars(x, y, p, bot)
	local n = bot and 0 or (p < 60 and 4 or p < 100 and 3 or p < 160 and 2 or 1)
	local col = bot and C.dim or pingColor(p)
	for i = 1, 4 do
		local bh = S(3) + i * S(3)
		draw.RoundedBox(1, x + (i - 1) * S(5), y - bh, S(3), bh, i <= n and col or Color(255, 255, 255, 25))
	end
end

local function row(parent, ply)
	local r = parent:Add("DButton")
	r:Dock(TOP) r:DockMargin(0, 0, 0, S(4)) r:SetTall(S(46)) r:SetText("")
	local av = vgui.Create("AvatarImage", r)
	av:SetSize(S(32), S(32)) av:SetPos(S(10), S(7)) av:SetPlayer(ply, 64) av:SetMouseInputEnabled(false)
	function r:Paint(w, h)
		if not IsValid(ply) then return end
		local me, sel = ply == LocalPlayer(), SB.selected == ply
		self.hov = Lerp(FrameTime() * 14, self.hov or 0, (self:IsHovered() or sel) and 1 or 0)
		local base = me and Color(30, 40, 72, 235) or Color(16, 21, 40, 220)
		draw.RoundedBox(S(6), 0, 0, w, h, base)
		if self.hov > 0.01 then draw.RoundedBox(S(6), 0, 0, w, h, Color(110, 205, 255, 22 * self.hov)) end
		if sel then surface.SetDrawColor(C.accent) surface.DrawOutlinedRect(0, 0, w, h, 1) end
		local fname, fcol = factionOf(ply)
		if fcol then draw.RoundedBoxEx(S(6), 0, 0, S(3), h, fcol, true, false, true, false) end
		local x = S(52) + S(4) * self.hov
		local blocked = SB.Blocked[ply:SteamID64() or ""]
		local name = UI.Truncate(ply:Nick(), "Astral.UI.Text", w * 0.3)
		draw.SimpleText(name, "Astral.UI.Text", x, h / 2 - S(1), blocked and C.dim or C.text, TEXT_ALIGN_LEFT, fname and TEXT_ALIGN_BOTTOM or TEXT_ALIGN_CENTER)
		if fname then draw.SimpleText(UI.Truncate(fname, "Astral.UI.Tiny", w * 0.3), "Astral.UI.Tiny", x, h / 2 + S(1), fcol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP) end
		local rank, rcol = rankOf(ply)
		if rank then
			surface.SetFont("Astral.UI.Tiny")
			local tw = surface.GetTextSize(rank) + S(12)
			local rx = w * 0.37
			draw.RoundedBox(S(4), rx, h / 2 - S(10), tw, S(20), Color(rcol.r, rcol.g, rcol.b, 40))
			draw.SimpleText(rank, "Astral.UI.Tiny", rx + tw / 2, h / 2, rcol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		draw.SimpleText(ply.GetLevel and ply:GetLevel() or 0, "Astral.UI.Text", w * 0.56, h / 2, C.xp, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(fmtTime(playTime(ply)), "Astral.UI.Small", w * 0.66, h / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(ply:Frags(), "Astral.UI.Text", w * 0.76, h / 2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(ply:Deaths(), "Astral.UI.Text", w * 0.84, h / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		local p = ply:Ping()
		pingBars(w * 0.93 - S(26), h / 2 + S(8), p, ply:IsBot())
		draw.SimpleText(ply:IsBot() and "BOT" or p, "Astral.UI.Small", w * 0.93 + S(4), h / 2, ply:IsBot() and C.dim or pingColor(p), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		if ply:IsMuted() or blocked then draw.SimpleText(ply:IsMuted() and "MUET" or "MASQUÉ", "Astral.UI.Tiny", w - S(12), h / 2, C.warn, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER) end
	end
	r.DoClick = function() SB.Pin() SB.Select(ply) end
	r.DoRightClick = r.DoClick
	return r
end

local function groupHeader(parent, title, col, n)
	local g = parent:Add("DPanel")
	g:Dock(TOP) g:DockMargin(0, S(6), 0, S(4)) g:SetTall(S(24))
	function g:Paint(w, h)
		draw.SimpleText(title, "Astral.UI.Small", S(6), h / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetFont("Astral.UI.Small")
		local tw = surface.GetTextSize(title)
		draw.SimpleText(n .. " joueur" .. (n > 1 and "s" or ""), "Astral.UI.Tiny", S(14) + tw, h / 2, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(col.r, col.g, col.b, 60) surface.DrawRect(S(100) + tw, h / 2, w - S(100) - tw, 1)
	end
end

---------------------------------------------------------------------------
-- Fiche joueur et actions
---------------------------------------------------------------------------
local function actionButton(parent, label, col, fn)
	local b = UI.Button(parent, label, col, function() surface.PlaySound("ui/buttonclick.wav") fn() end)
	b:Dock(TOP) b:DockMargin(0, 0, 0, S(6)) b:SetTall(S(32))
	return b
end

local function buildDetail(panel, ply)
	panel:Clear()
	if not IsValid(ply) then panel:SetVisible(false) return end
	panel:SetVisible(true)
	local head = vgui.Create("DPanel", panel)
	head:Dock(TOP) head:SetTall(S(150))
	local av = vgui.Create("AvatarImage", head)
	av:SetSize(S(72), S(72)) av:SetPos(S(14), S(14)) av:SetPlayer(ply, 128)
	function head:Paint(w, h)
		if not IsValid(ply) then return end
		draw.SimpleText(UI.Truncate(ply:Nick(), "Astral.UI.Big", w - S(110)), "Astral.UI.Big", S(98), S(22), C.text)
		local rank, rcol = rankOf(ply)
		draw.SimpleText(rank or "Joueur", "Astral.UI.Small", S(98), S(52), rcol or C.dim)
		local fname, fcol = factionOf(ply)
		draw.SimpleText(fname or "Sans faction", "Astral.UI.Small", S(98), S(70), fcol or C.dim)
		local stats = {
			{ "Niveau", ply.GetLevel and ply:GetLevel() or 0, C.xp },
			{ "Session", fmtTime(ply.GetSessionTime and ply:GetSessionTime() or 0), C.text },
			{ "Temps", fmtTime(playTime(ply)), C.text },
			{ "K/D", string.format("%.2f", ply:Frags() / math.max(ply:Deaths(), 1)), C.text },
		}
		local cw = (w - S(28)) / #stats
		for i, s in ipairs(stats) do
			local x = S(14) + (i - 1) * cw
			draw.RoundedBox(S(6), x + S(2), S(100), cw - S(4), S(42), C.panel)
			draw.SimpleText(s[2], "Astral.UI.Text", x + cw / 2, S(108), s[3], TEXT_ALIGN_CENTER)
			draw.SimpleText(s[1], "Astral.UI.Tiny", x + cw / 2, S(128), C.dim, TEXT_ALIGN_CENTER)
		end
	end

	local list = vgui.Create("DScrollPanel", panel)
	list:Dock(FILL) list:DockMargin(S(14), S(8), S(14), S(10))
	local function title(t)
		local l = UI.Label(list, t, "Astral.UI.Tiny", C.dim)
		l:Dock(TOP) l:DockMargin(0, S(6), 0, S(6))
	end
	local me = LocalPlayer()
	local isMe, bot = ply == me, ply:IsBot()

	title("JOUEUR")
	if not bot then
		actionButton(list, "Voir le profil Steam", nil, function() ply:ShowProfile() end)
		actionButton(list, "Copier le SteamID", nil, function() SetClipboardText(ply:SteamID()) notification.AddLegacy("SteamID copié : " .. ply:SteamID(), NOTIFY_GENERIC, 3) end)
		actionButton(list, "Copier le SteamID64", nil, function() SetClipboardText(ply:SteamID64() or "") notification.AddLegacy("SteamID64 copié", NOTIFY_GENERIC, 3) end)
	end
	if not isMe then
		actionButton(list, "Message privé", C.accent2, function()
			Derma_StringRequest("Message privé", "Message pour " .. ply:Nick() .. " :", "", function(msg)
				msg = string.Trim(msg or "")
				if msg == "" or not IsValid(ply) then return end
				if can("ulx psay") then ulx("psay", ply, msg) else RunConsoleCommand("say", "/pm " .. ply:Nick() .. " " .. msg) end
			end, nil, "Envoyer", "Annuler")
		end)
		actionButton(list, ply:IsMuted() and "Réactiver son micro" or "Couper son micro", nil, function() ply:SetMuted(not ply:IsMuted()) buildDetail(panel, ply) end)
		local sid = ply:SteamID64() or ""
		actionButton(list, SB.Blocked[sid] and "Afficher ses messages" or "Masquer ses messages", nil, function()
			SB.Blocked[sid] = not SB.Blocked[sid] or nil
			buildDetail(panel, ply)
		end)
	end

	-- Fun et social (commandes de chat Astral, astral/social/sv_commands.lua)
	local function say(cmd) RunConsoleCommand("say", cmd) end
	title("FUN & SOCIAL")
	if not isMe then
		actionButton(list, "Saluer " .. UI.Truncate(ply:Nick(), "Astral.UI.Text", S(160)), C.good, function() say("!saluer " .. ply:Nick()) end)
		actionButton(list, "Lui donner de l'argent…", C.good, function()
			Derma_StringRequest("Donner de l'argent", "Somme à donner à " .. ply:Nick() .. " :", "1000", function(v)
				local n = math.floor(tonumber(v) or 0)
				if n > 0 and IsValid(ply) then say("!donner " .. ply:Nick() .. " " .. n) end
			end, nil, "Donner", "Annuler")
		end)
	else
		local emotes = { { "Danser", "!danse" }, { "Rire", "!rire" }, { "Applaudir", "!applaudir" }, { "Saluer tout le monde", "!saluer" } }
		for _, e in ipairs(emotes) do actionButton(list, e[1], nil, function() say(e[2]) end) end
		actionButton(list, "Lancer un dé", C.accent, function() say("!roll") end)
		actionButton(list, "Pile ou face", C.accent, function() say("!pile") end)
		actionButton(list, "Tirer un feu d'artifice", Color(255, 90, 200), function() say("!feu") end)
		actionButton(list, "Toutes les commandes", nil, function() say("!commandes") end)
	end

	-- Actions staff : seulement celles que le rang ULX autorise
	local staff = {
		{ "ulx goto", "Aller à lui", nil, function() ulx("goto", ply) end, true },
		{ "ulx bring", "L'amener à moi", nil, function() ulx("bring", ply) end, true },
		{ "ulx return", "Le renvoyer à sa position", nil, function() ulx("return", ply) end },
		{ "ulx freeze", "Geler / dégeler", C.accent, function() ulx(ply:IsFrozen() and "unfreeze" or "freeze", ply) end },
		{ "ulx spectate", "Observer", nil, function() ulx("spectate", ply) end, true },
		{ "ulx mute", "Rendre muet (chat) / rétablir", C.warn, function() ulx(ply:GetNWBool("ulx_muted") and "unmute" or "mute", ply) end },
		{ "ulx gag", "Couper sa voix / rétablir", C.warn, function() ulx(ply:GetNWBool("ulx_gagged") and "ungag" or "gag", ply) end },
		{ "ulx kick", "Expulser", C.bad, function()
			Derma_StringRequest("Expulser " .. ply:Nick(), "Raison de l'expulsion :", "", function(reason)
				if IsValid(ply) then ulx("kick", ply, reason ~= "" and reason or "Expulsé par un membre du staff") end
			end, nil, "Expulser", "Annuler")
		end },
		{ "ulx ban", "Bannir", C.bad, function()
			local m = DermaMenu()
			for _, d in ipairs({ { "1 heure", 60 }, { "1 jour", 1440 }, { "7 jours", 10080 }, { "30 jours", 43200 }, { "Définitivement", 0 } }) do
				m:AddOption(d[1], function()
					Derma_StringRequest("Bannir " .. ply:Nick() .. " (" .. d[1] .. ")", "Raison du bannissement :", "", function(reason)
						if IsValid(ply) then ulx("ban", ply, tostring(d[2]), reason ~= "" and reason or "Banni par un membre du staff") end
					end, nil, "Bannir", "Annuler")
				end)
			end
			m:Open()
		end },
	}
	local shown = false
	for _, a in ipairs(staff) do
		if can(a[1]) and not (isMe and a[5]) then
			if not shown then title("STAFF") shown = true end
			actionButton(list, a[2], a[3], a[4])
		end
	end
end

---------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------
local function visiblePlayers()
	local q = string.lower(SB.query or "")
	local out = {}
	for _, p in ipairs(player.GetAll()) do
		local ok = true
		if q ~= "" then
			ok = p:Nick():lower():find(q, 1, true) or (p:SteamID() or ""):lower():find(q, 1, true) or (p:SteamID64() or ""):find(q, 1, true)
		end
		if ok and SB.tab == "staff" then ok = select(3, rankOf(p)) >= 3 end
		if ok then out[#out + 1] = p end
	end
	local get = SORTERS[SB.sort] or SORTERS.rank
	table.sort(out, function(a, b)
		local va, vb = get(a), get(b)
		if va == vb then return a:Nick():lower() < b:Nick():lower() end
		if SB.desc then return va > vb end
		return va < vb
	end)
	return out
end

local function build()
	if IsValid(board) then board:Remove() end
	local w, h = math.min(ScrW() - S(60), S(1180)), math.min(ScrH() - S(100), S(760))
	board = vgui.Create("EditablePanel")
	board:SetSize(w, h) board:Center()
	board.baseY = board.y
	board.openT = SysTime()

	function board:Paint(pw, ph)
		draw.RoundedBox(S(12), 0, 0, pw, ph, Color(8, 11, 22, 250))
		draw.RoundedBoxEx(S(12), 0, 0, pw, S(4), C.accent, true, true, false, false)
		draw.SimpleText("ASTRAL", "Astral.UI.Huge", S(24), S(18), C.accent)
		surface.SetFont("Astral.UI.Huge")
		draw.SimpleText("BASEWARS", "Astral.UI.Huge", S(24) + surface.GetTextSize("ASTRAL "), S(18), C.text)
		draw.SimpleText(UI.Truncate(GetHostName(), "Astral.UI.Small", pw * 0.4), "Astral.UI.Small", S(26), S(56), C.dim)
		-- Pastilles d'information
		local staff, facs = 0, {}
		for _, p in ipairs(player.GetAll()) do
			if select(3, rankOf(p)) >= 3 then staff = staff + 1 end
			local f = factionOf(p) if f then facs[f] = true end
		end
		local chips = {
			{ "JOUEURS", player.GetCount() .. " / " .. game.MaxPlayers(), C.text },
			{ "STAFF EN LIGNE", staff, staff > 0 and C.good or C.dim },
			{ "FACTIONS", table.Count(facs), C.accent2 },
			{ "CARTE", game.GetMap(), C.text },
			{ "HEURE", os.date("%H:%M"), C.text },
		}
		local x = pw - S(24)
		for i = #chips, 1, -1 do
			local c = chips[i]
			surface.SetFont("Astral.UI.Text")
			local vw = math.max(surface.GetTextSize(tostring(c[2])), select(1, surface.GetTextSize(c[1])) * 0.7) + S(24)
			x = x - vw
			draw.RoundedBox(S(8), x, S(18), vw, S(50), Color(20, 26, 48, 200))
			draw.SimpleText(c[1], "Astral.UI.Tiny", x + vw / 2, S(24), C.dim, TEXT_ALIGN_CENTER)
			draw.SimpleText(c[2], "Astral.UI.Text", x + vw / 2, S(40), c[3], TEXT_ALIGN_CENTER)
			x = x - S(8)
		end
		if not SB.pinned then
			draw.SimpleText("Clique dans le tableau pour le garder ouvert", "Astral.UI.Tiny", pw / 2, ph - S(16), Color(C.dim.r, C.dim.g, C.dim.b, 140), TEXT_ALIGN_CENTER)
		else
			draw.SimpleText("Échap, Tab ou la croix pour fermer", "Astral.UI.Tiny", pw / 2, ph - S(16), Color(C.dim.r, C.dim.g, C.dim.b, 140), TEXT_ALIGN_CENTER)
		end
	end
	function board:OnMousePressed() SB.Pin() end
	-- Ouverture : fondu + léger glissement
	function board:Think()
		local t = math.Clamp((SysTime() - self.openT) / 0.18, 0, 1)
		local e = 1 - (1 - t) ^ 3
		self:SetAlpha(255 * e)
		self:SetY(self.baseY + S(16) * (1 - e))
		if (self.next or 0) < RealTime() then
			self.next = RealTime() + 1
			self:Refresh()
		end
	end

	-- Barre d'outils : recherche, onglets, fermeture
	local bar = vgui.Create("DPanel", board)
	bar:Dock(TOP) bar:DockMargin(S(20), S(84), S(20), S(8)) bar:SetTall(S(34))
	function bar:Paint() end
	local search = UI.Input(bar, "Rechercher un joueur ou un SteamID…")
	search:Dock(LEFT) search:SetWide(S(300))
	search:SetValue(SB.query or "")
	search.OnGetFocus = function() SB.Pin() end
	search.OnChange = function(s) SB.query = s:GetValue() board.key = nil board:Refresh() end
	local close = UI.Button(bar, "✕", C.bad, function() SB.Close() end)
	close:Dock(RIGHT) close:SetWide(S(40))
	local tabs = vgui.Create("DPanel", bar)
	tabs:Dock(LEFT) tabs:DockMargin(S(12), 0, 0, 0) tabs:SetWide(S(330))
	function tabs:Paint() end
	for _, t in ipairs({ { "all", "Tous" }, { "factions", "Factions" }, { "staff", "Staff" } }) do
		local b = vgui.Create("DButton", tabs)
		b:Dock(LEFT) b:DockMargin(0, 0, S(6), 0) b:SetWide(S(100)) b:SetText("")
		function b:Paint(bw, bh)
			local act = SB.tab == t[1]
			draw.RoundedBox(S(6), 0, 0, bw, bh, act and Color(110, 205, 255, 40) or (self:IsHovered() and C.panel or Color(16, 21, 40, 200)))
			if act then surface.SetDrawColor(110, 205, 255, 120) surface.DrawOutlinedRect(0, 0, bw, bh, 1) end
			draw.SimpleText(t[2], "Astral.UI.Small", bw / 2, bh / 2, act and C.accent or C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		b.DoClick = function() SB.Pin() SB.tab = t[1] board.key = nil board:Refresh() end
	end

	-- Fiche joueur (à droite)
	local detail = vgui.Create("DPanel", board)
	detail:Dock(RIGHT) detail:DockMargin(0, 0, S(20), S(34)) detail:SetWide(S(320)) detail:SetVisible(false)
	function detail:Paint(pw, ph) draw.RoundedBox(S(10), 0, 0, pw, ph, Color(16, 21, 40, 230)) end
	board.detail = detail

	-- En-têtes de colonnes cliquables (tri)
	local heads = vgui.Create("DPanel", board)
	heads:Dock(TOP) heads:DockMargin(S(20), 0, S(20) + S(6), S(4)) heads:SetTall(S(20))
	function heads:Paint() end
	function heads:PerformLayout(hw)
		for i, col in ipairs(COLS) do
			local b = self.btns and self.btns[i]
			if b then
				local x = col[3] == 0 and S(52) or hw * col[3]
				if col[4] == TEXT_ALIGN_CENTER then x = x - S(50) end
				b:SetPos(x, 0) b:SetSize(S(100), S(20))
			end
		end
	end
	heads.btns = {}
	for i, col in ipairs(COLS) do
		local b = vgui.Create("DButton", heads)
		b:SetText("")
		function b:Paint(bw, bh)
			local act = SB.sort == col[1]
			local label = col[2] .. (act and (SB.desc and " ▼" or " ▲") or "")
			local ax = col[4] == TEXT_ALIGN_CENTER and bw / 2 or 0
			draw.SimpleText(label, "Astral.UI.Tiny", ax, bh / 2, act and C.accent or (self:IsHovered() and C.text or C.dim), col[4], TEXT_ALIGN_CENTER)
		end
		b.DoClick = function()
			SB.Pin()
			if SB.sort == col[1] then SB.desc = not SB.desc else SB.sort, SB.desc = col[1], col[1] ~= "name" end
			board.key = nil board:Refresh()
		end
		heads.btns[i] = b
	end
	board.heads = heads

	local scroll = vgui.Create("DScrollPanel", board)
	scroll:Dock(FILL) scroll:DockMargin(S(20), 0, S(12), S(34))
	local vbar = scroll:GetVBar() vbar:SetWide(S(6))
	function vbar:Paint() end function vbar.btnUp:Paint() end function vbar.btnDown:Paint() end
	function vbar.btnGrip:Paint(bw, bh) draw.RoundedBox(S(3), 0, 0, bw, bh, C.line) end
	board.scroll = scroll

	function board:Refresh()
		local list = visiblePlayers()
		local key = { SB.tab, SB.sort, tostring(SB.desc), SB.query or "" }
		for _, p in ipairs(list) do key[#key + 1] = p:UserID() .. ":" .. (factionOf(p) or "") end
		key = table.concat(key, ",")
		if key == self.key then return end
		self.key = key
		self.scroll:Clear()
		if #list == 0 then
			local e = self.scroll:Add("DLabel")
			e:Dock(TOP) e:SetTall(S(60)) e:SetFont("Astral.UI.Text") e:SetTextColor(C.dim) e:SetContentAlignment(5)
			e:SetText("Aucun joueur ne correspond.")
			return
		end
		if SB.tab == "factions" then
			local groups, order = {}, {}
			for _, p in ipairs(list) do
				local f, col = factionOf(p)
				local k = f or "~"
				if not groups[k] then groups[k] = { name = f or "Sans faction", col = col or C.dim, players = {} } order[#order + 1] = k end
				table.insert(groups[k].players, p)
			end
			table.sort(order, function(a, b) return #groups[a].players > #groups[b].players or (#groups[a].players == #groups[b].players and a < b) end)
			for _, k in ipairs(order) do
				local g = groups[k]
				groupHeader(self.scroll, g.name, g.col, #g.players)
				for _, p in ipairs(g.players) do row(self.scroll, p) end
			end
		else
			for _, p in ipairs(list) do row(self.scroll, p) end
		end
		if IsValid(SB.selected) == false and SB.selected ~= nil then SB.Select(nil) end
	end
	board:Refresh()
end

function SB.Select(ply)
	SB.selected = ply
	if IsValid(board) then buildDetail(board.detail, ply) board:InvalidateLayout(true) end
end

function SB.Pin()
	if SB.pinned or not IsValid(board) then return end
	SB.pinned = true
	board:SetKeyboardInputEnabled(true)
end

function SB.IsOpen() return IsValid(board) and board:IsVisible() end

function SB.Close()
	SB.pinned = false
	if IsValid(board) then board:SetVisible(false) board:SetKeyboardInputEnabled(false) end
	CloseDermaMenus()
end

function SB.Open()
	if not IsValid(board) then build() end
	board.openT = SysTime()
	board:SetVisible(true)
	board:MakePopup()
	board:SetKeyboardInputEnabled(SB.pinned and true or false)
end

hook.Add("ScoreboardShow", "Astral.Scoreboard", function()
	if not GetConVar("astral_hud"):GetBool() then return end
	if SB.IsOpen() and SB.pinned then SB.Close() return true end
	SB.Open()
	return true
end, HOOK_HIGH)

hook.Add("ScoreboardHide", "Astral.Scoreboard", function()
	if not SB.IsOpen() then return end
	if not SB.pinned then SB.Close() end
	return true
end, HOOK_HIGH)

-- Messages des joueurs masqués depuis la fiche joueur (côté client uniquement)
hook.Add("OnPlayerChat", "Astral.Scoreboard.Block", function(ply)
	if IsValid(ply) and SB.Blocked[ply:SteamID64() or ""] then return true end
end, HOOK_HIGH)

hook.Add("OnScreenSizeChanged", "Astral.Scoreboard", function() if IsValid(board) then board:Remove() end end)
