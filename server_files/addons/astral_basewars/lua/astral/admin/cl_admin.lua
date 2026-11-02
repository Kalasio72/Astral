-- Astral BaseWars — menu d'administration (partie client).
-- Le client n'affiche que ce que le serveur lui envoie ; toutes les vérifications de droits sont côté serveur.

local C = {
	bg = Color(11, 14, 28, 245),
	panel = Color(20, 26, 48),
	line = Color(40, 52, 90),
	accent = Color(120, 210, 255),
	text = Color(230, 234, 245),
	dim = Color(150, 160, 190),
	good = Color(120, 220, 140),
	bad = Color(255, 120, 120),
}

surface.CreateFont("Astral.Title", { font = "Roboto", size = 22, weight = 800 })
surface.CreateFont("Astral.Body", { font = "Roboto", size = 15, weight = 500 })
surface.CreateFont("Astral.Mono", { font = "Consolas", size = 14, weight = 500 })

local Admin = { categories = {}, handlers = {} }
Astral.AdminMenu = Admin

local function request(action, arg)
	net.Start("Astral.Admin.Request")
		net.WriteString(action)
		net.WriteString(arg or "")
	net.SendToServer()
end

local function money(n)
	n = tonumber(n) or 0
	return (n < 0 and "-" or "") .. BaseWars.LANG.CURRENCY .. BaseWars.NumberFormat(math.abs(n))
end

local function styleList(list)
	list:SetDataHeight(20)
	list:SetHeaderHeight(22)
	function list:Paint(w, h) draw.RoundedBox(4, 0, 0, w, h, C.panel) end
	for _, col in ipairs(list.Columns) do
		col.Header:SetTextColor(C.accent)
		function col.Header:Paint(w, h) draw.RoundedBox(0, 0, 0, w, h, C.line) end
	end
end

local function addLine(list, ...)
	local line = list:AddLine(...)
	for _, col in ipairs(line.Columns) do col:SetTextColor(C.text) end
	function line:Paint(w, h)
		if self:IsHovered() or self:IsLineSelected() then draw.RoundedBox(0, 0, 0, w, h, C.line) end
	end
	return line
end

local function errorLabel(parent, text)
	local l = vgui.Create("DLabel", parent)
	l:Dock(TOP)
	l:SetFont("Astral.Body")
	l:SetTextColor(C.bad)
	l:SetText(text)
	l:SizeToContents()
	return l
end

local function button(parent, text, onClick)
	local b = vgui.Create("DButton", parent)
	b:SetText(text)
	b:SetFont("Astral.Body")
	b:SetTextColor(C.text)
	b:SetTall(26)
	function b:Paint(w, h) draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and C.accent or C.line) end
	b.DoClick = onClick
	return b
end

---------------------------------------------------------------------------
-- Onglets
---------------------------------------------------------------------------
local function buildDiag(sheet)
	local pnl = vgui.Create("DPanel", sheet)
	pnl:DockPadding(8, 8, 8, 8)
	function pnl:Paint() end
	local bar = vgui.Create("DPanel", pnl)
	bar:Dock(TOP) bar:SetTall(26) function bar:Paint() end
	local text = vgui.Create("RichText", pnl)
	text:Dock(FILL) text:DockMargin(0, 8, 0, 0)
	function text:PerformLayout() self:SetFontInternal("Astral.Mono") self:SetFGColor(C.text) end
	function text:Paint(w, h) draw.RoundedBox(4, 0, 0, w, h, C.panel) end
	local refresh = button(bar, "Actualiser", function() request("diag") end)
	refresh:Dock(LEFT) refresh:SetWide(120)
	Admin.handlers.diag = function(data)
		if not IsValid(text) then return end
		text:SetText("")
		if data.error then return text:AppendText(data.error) end
		text:AppendText(table.concat(data.lines or {}, "\n"))
	end
	request("diag")
	return pnl
end

local function buildEconomy(sheet)
	local pnl = vgui.Create("DPanel", sheet)
	pnl:DockPadding(8, 8, 8, 8)
	function pnl:Paint() end

	local bar = vgui.Create("DPanel", pnl)
	bar:Dock(TOP) bar:SetTall(26) function bar:Paint() end
	local refresh = button(bar, "Résumé 24 h", function() request("eco_summary") end)
	refresh:Dock(LEFT) refresh:SetWide(130)
	local search = vgui.Create("DTextEntry", bar)
	search:Dock(LEFT) search:DockMargin(16, 0, 4, 0) search:SetWide(220)
	search:SetPlaceholderText("Nom d'un joueur connecté ou SteamID64")
	local go = button(bar, "Historique du joueur", function() request("eco_player", search:GetValue()) end)
	go:Dock(LEFT) go:SetWide(170)

	local info = vgui.Create("DLabel", pnl)
	info:Dock(TOP) info:DockMargin(0, 6, 0, 2) info:SetFont("Astral.Body") info:SetTextColor(C.dim) info:SetText("")

	local players = vgui.Create("DListView", pnl)
	players:Dock(TOP) players:SetTall(220)
	players:AddColumn("Joueur") players:AddColumn("Gagné") players:AddColumn("Dépensé") players:AddColumn("Opérations")
	styleList(players)
	function players:OnRowSelected(_, line) if line.sid then search:SetValue(line.sid) request("eco_player", line.sid) end end

	local detail = vgui.Create("DListView", pnl)
	detail:Dock(FILL) detail:DockMargin(0, 8, 0, 0)
	detail:AddColumn("Source / date") detail:AddColumn("Gagné / variation") detail:AddColumn("Dépensé / solde") detail:AddColumn("Opérations / —")
	styleList(detail)

	Admin.handlers.eco_summary = function(data)
		if not IsValid(players) then return end
		players:Clear() detail:Clear()
		if data.error then info:SetText(data.error) info:SizeToContents() return end
		info:SetText("Dernières 24 h — " .. (data.rows or 0) .. " variations d'argent. Cliquez un joueur pour son historique.")
		info:SizeToContents()
		for _, p in ipairs(data.players or {}) do
			local line = addLine(players, p.name or p.sid, money(p.gain), money(p.loss), p.count)
			line.sid = p.sid
		end
		for _, s in ipairs(data.sources or {}) do addLine(detail, s.source, money(s.gain), money(s.loss), s.count) end
	end
	Admin.handlers.eco_player = function(data)
		if not IsValid(detail) then return end
		detail:Clear()
		if data.error then info:SetText(data.error) info:SizeToContents() return end
		info:SetText("100 dernières variations d'argent de " .. data.sid)
		info:SizeToContents()
		for _, r in ipairs(data.rows or {}) do
			local line = addLine(detail, os.date("%d/%m %H:%M:%S", r.ts or 0) .. "  " .. tostring(r.source), money(r.delta), money(r.balance), "")
			line.Columns[2]:SetTextColor((tonumber(r.delta) or 0) >= 0 and C.good or C.bad)
		end
	end
	request("eco_summary")
	return pnl
end

local function buildLogs(sheet)
	local pnl = vgui.Create("DPanel", sheet)
	pnl:DockPadding(8, 8, 8, 8)
	function pnl:Paint() end
	local bar = vgui.Create("DPanel", pnl)
	bar:Dock(TOP) bar:SetTall(26) function bar:Paint() end
	local combo = vgui.Create("DComboBox", bar)
	combo:Dock(LEFT) combo:SetWide(200)
	combo:AddChoice("Toutes les catégories", "", true)
	for _, c in ipairs(Admin.categories) do combo:AddChoice(c, c) end
	local go = button(bar, "Afficher", function() local _, v = combo:GetSelected() request("logs", v or "") end)
	go:Dock(LEFT) go:DockMargin(6, 0, 0, 0) go:SetWide(100)

	local list = vgui.Create("DListView", pnl)
	list:Dock(FILL) list:DockMargin(0, 8, 0, 0)
	list:AddColumn("Date"):SetFixedWidth(110)
	list:AddColumn("Catégorie"):SetFixedWidth(120)
	list:AddColumn("Joueur"):SetFixedWidth(160)
	list:AddColumn("Détails")
	styleList(list)
	function list:OnRowSelected(_, line) SetClipboardText(line.raw or "") notification.AddLegacy("Détails copiés dans le presse-papiers", NOTIFY_HINT, 3) end

	Admin.handlers.logs = function(data)
		if not IsValid(list) then return end
		list:Clear()
		if data.error then return addLine(list, "", "erreur", "", data.error) end
		for _, r in ipairs(data.rows or {}) do
			local line = addLine(list, os.date("%d/%m %H:%M:%S", r.ts or 0), r.category, r.who, r.data)
			line.raw = r.data
		end
	end
	request("logs", "")
	return pnl
end

---------------------------------------------------------------------------
-- Joueurs : statistiques et actions (privilège Astral.Admin vérifié par le serveur)
---------------------------------------------------------------------------
local function notifyResult(data)
	local UIx = Astral.UI
	local msg = data.error or data.message or "OK"
	if UIx and UIx.Toast then UIx.Toast(msg, data.error and BASEWARS_NOTIFICATION_ERROR or BASEWARS_NOTIFICATION_MONEY) else chat.AddText(msg) end
end

local function askValue(title, label, default, onOk)
	Derma_StringRequest(title, label, default or "", function(v) onOk(v) end, nil, "Valider", "Annuler")
end

local function buildPlayers(sheet)
	local pnl = vgui.Create("DPanel", sheet)
	pnl:DockPadding(8, 8, 8, 8)
	function pnl:Paint() end
	local bar = vgui.Create("DPanel", pnl)
	bar:Dock(TOP) bar:SetTall(26) function bar:Paint() end
	local refresh = button(bar, "Actualiser", function() request("players") end)
	refresh:Dock(LEFT) refresh:SetWide(120)
	local hint = vgui.Create("DLabel", bar)
	hint:Dock(FILL) hint:DockMargin(12, 0, 0, 0) hint:SetFont("Astral.Body") hint:SetTextColor(C.dim)
	hint:SetText("Clic droit sur un joueur pour les actions. Toutes les actions sont journalisées.")

	local list = vgui.Create("DListView", pnl)
	list:Dock(FILL) list:DockMargin(0, 8, 0, 0)
	for _, c in ipairs({ "Joueur", "Rang", "Argent", "Niveau", "Faction", "Entités", "Ping", "État" }) do list:AddColumn(c) end
	styleList(list)

	local function act(line, action, value, reason)
		request("player_action", string.format("%s|%s|%s|%s", line.sid, action, value or "", (reason or ""):gsub("|", "/")))
		timer.Simple(0.6, function() request("players") end)
	end
	function list:OnRowRightClick(_, line)
		local m = DermaMenu()
		m:AddOption("Donner de l'argent…", function() askValue("Donner de l'argent", "Montant à donner à " .. line.name, "10000", function(v) act(line, "give_money", v) end) end):SetIcon("icon16/money_add.png")
		m:AddOption("Retirer de l'argent…", function() askValue("Retirer de l'argent", "Montant à retirer à " .. line.name, "10000", function(v) act(line, "take_money", v) end) end):SetIcon("icon16/money_delete.png")
		m:AddOption("Définir le niveau…", function() askValue("Niveau", "Nouveau niveau de " .. line.name, tostring(line.level), function(v) act(line, "set_level", v) end) end):SetIcon("icon16/award_star_gold_1.png")
		m:AddSpacer()
		m:AddOption("Aller vers", function() act(line, "go_to") end):SetIcon("icon16/arrow_right.png")
		m:AddOption("Ramener à moi", function() act(line, "bring") end):SetIcon("icon16/arrow_left.png")
		m:AddOption(line.frozen and "Dégeler" or "Geler", function() act(line, "freeze") end):SetIcon("icon16/weather_snow.png")
		local util_, utilOpt = m:AddSubMenu("Commandes utiles")
		utilOpt:SetIcon("icon16/wrench.png")
		util_:AddOption("Soigner", function() act(line, "heal") end):SetIcon("icon16/heart.png")
		util_:AddOption("Donner 100 d'armure", function() act(line, "armor") end):SetIcon("icon16/shield.png")
		util_:AddOption("Invincibilité (activer / couper)", function() act(line, "god") end):SetIcon("icon16/star.png")
		util_:AddOption("Invisibilité (activer / couper)", function() act(line, "cloak") end):SetIcon("icon16/eye.png")
		util_:AddOption("Noclip (activer / couper)", function() act(line, "noclip") end):SetIcon("icon16/arrow_up.png")
		util_:AddOption("Faire réapparaître", function() act(line, "respawn") end):SetIcon("icon16/arrow_refresh.png")
		util_:AddOption("Retirer ses armes", function() act(line, "strip") end):SetIcon("icon16/gun.png")
		local fun, funOpt = m:AddSubMenu("Commandes fun")
		funOpt:SetIcon("icon16/emoticon_grin.png")
		fun:AddOption("Gifler", function() act(line, "slap") end):SetIcon("icon16/hand.png")
		fun:AddOption("Envoyer en l'air (avec feu d'artifice)", function() act(line, "launch") end):SetIcon("icon16/sport_shuttlecock.png")
		fun:AddOption("Enflammer (5 s)", function() act(line, "ignite") end):SetIcon("icon16/fire.png")
		fun:AddOption("Rétrécir / taille normale", function() act(line, "shrink") end):SetIcon("icon16/arrow_in.png")
		m:AddOption("Rembourser et retirer ses entités", function()
			Derma_Query("Rembourser et retirer toutes les entités de " .. line.name .. " ?", "Confirmation", "Oui", function() act(line, "refund") end, "Non")
		end):SetIcon("icon16/arrow_undo.png")
		m:AddSpacer()
		m:AddOption("Expulser…", function() askValue("Expulser", "Raison de l'expulsion de " .. line.name, "", function(r) act(line, "kick", "", r) end) end):SetIcon("icon16/door_out.png")
		m:AddOption("Bannir…", function()
			askValue("Bannir", "Durée en minutes (0 = définitif)", "1440", function(d)
				askValue("Bannir", "Raison du bannissement de " .. line.name, "", function(r) act(line, "ban", d, r) end)
			end)
		end):SetIcon("icon16/delete.png")
		m:AddOption("Copier le SteamID64", function() SetClipboardText(line.sid) end):SetIcon("icon16/page_copy.png")
		m:Open()
	end

	Admin.handlers.players = function(data)
		if not IsValid(list) then return end
		list:Clear()
		if data.error then return addLine(list, data.error) end
		for _, p in ipairs(data.players or {}) do
			local line = addLine(list, p.name, p.group, money(p.money), p.level, p.faction ~= "" and p.faction or "—", p.ents, p.ping, (p.frozen and "Gelé " or "") .. (p.afk and "AFK" or ""))
			line.sid, line.name, line.level, line.frozen = p.sid, p.name, p.level, p.frozen
		end
	end
	Admin.handlers.player_action = notifyResult
	request("players")
	return pnl
end

local function buildEntities(sheet)
	local pnl = vgui.Create("DPanel", sheet)
	pnl:DockPadding(8, 8, 8, 8)
	function pnl:Paint() end
	local bar = vgui.Create("DPanel", pnl)
	bar:Dock(TOP) bar:SetTall(26) function bar:Paint() end
	local refresh = button(bar, "Actualiser", function() request("entities") end)
	refresh:Dock(LEFT) refresh:SetWide(120)
	local hint = vgui.Create("DLabel", bar)
	hint:Dock(FILL) hint:DockMargin(12, 0, 0, 0) hint:SetFont("Astral.Body") hint:SetTextColor(C.dim)
	hint:SetText("Machines BaseWars et Astral, triées par distance. Clic droit : aller vers / supprimer (avec remboursement).")
	local list = vgui.Create("DListView", pnl)
	list:Dock(FILL) list:DockMargin(0, 8, 0, 0)
	for _, c in ipairs({ "Machine", "Classe", "Propriétaire", "PV", "Énergie", "Valeur", "Distance" }) do list:AddColumn(c) end
	styleList(list)
	function list:OnRowRightClick(_, line)
		local m = DermaMenu()
		m:AddOption("Aller vers", function() request("entity_action", line.id .. "|teleport") end):SetIcon("icon16/arrow_right.png")
		m:AddOption("Supprimer (rembourser le propriétaire)", function()
			Derma_Query("Supprimer " .. line.name .. " ?", "Confirmation", "Oui", function()
				request("entity_action", line.id .. "|remove") timer.Simple(0.6, function() request("entities") end)
			end, "Non")
		end):SetIcon("icon16/delete.png")
		m:Open()
	end
	Admin.handlers.entities = function(data)
		if not IsValid(list) then return end
		list:Clear()
		for _, e in ipairs(data.entities or {}) do
			local power = e.maxpower and e.maxpower > 0 and (e.power .. " / " .. e.maxpower) or "—"
			local line = addLine(list, e.name, e.class, e.owner, e.hp .. " / " .. e.maxhp, power, money(e.value), e.dist)
			line.id, line.name = e.id, e.name
		end
	end
	Admin.handlers.entity_action = notifyResult
	request("entities")
	return pnl
end

local function buildAnnounce(sheet)
	local pnl = vgui.Create("DPanel", sheet)
	pnl:DockPadding(16, 16, 16, 16)
	function pnl:Paint() end
	local l = vgui.Create("DLabel", pnl)
	l:Dock(TOP) l:SetFont("Astral.Title") l:SetTextColor(C.text) l:SetText("Annonce à tous les joueurs") l:SizeToContents()
	local d = vgui.Create("DLabel", pnl)
	d:Dock(TOP) d:DockMargin(0, 4, 0, 12) d:SetFont("Astral.Body") d:SetTextColor(C.dim)
	d:SetText("Affichée 8 secondes en haut de l'écran et dans le chat (180 caractères max).") d:SizeToContents()
	local entry = vgui.Create("DTextEntry", pnl)
	entry:Dock(TOP) entry:SetTall(32) entry:SetFont("Astral.Body") entry:SetPlaceholderText("Ex. : Redémarrage du serveur dans 5 minutes")
	local send = button(pnl, "Envoyer l'annonce", function()
		local t = entry:GetValue()
		if #t:Trim() < 3 then return end
		request("announce", t) entry:SetValue("")
	end)
	send:Dock(TOP) send:DockMargin(0, 10, 0, 0) send:SetTall(32)
	local presets = { "Redémarrage du serveur dans 5 minutes.", "Événement en cours : rejoignez-nous !", "Merci de respecter les règles (F3 → Règles)." }
	for _, ptxt in ipairs(presets) do
		local b = button(pnl, ptxt, function() entry:SetValue(ptxt) end)
		b:Dock(TOP) b:DockMargin(0, 6, 0, 0)
	end
	Admin.handlers.announce = notifyResult

	-- Événements
	local evTitle = vgui.Create("DLabel", pnl)
	evTitle:Dock(TOP) evTitle:DockMargin(0, 24, 0, 6) evTitle:SetFont("Astral.Title") evTitle:SetTextColor(C.text)
	evTitle:SetText("Événements") evTitle:SizeToContents()
	local evState = vgui.Create("DLabel", pnl)
	evState:Dock(TOP) evState:SetFont("Astral.Body") evState:SetTextColor(C.dim)
	function evState:Think()
		local id, ev = Astral.Events.Current()
		self:SetText(id and string.format("En cours : %s (%d s restantes)", ev.name, math.max(0, math.floor(GetGlobal2Float("AstralEventEnds", 0) - CurTime()))) or "Aucun événement en cours.")
	end
	-- Durée choisie avant de lancer (10 min par défaut)
	local durBar = vgui.Create("DPanel", pnl)
	durBar:Dock(TOP) durBar:DockMargin(0, 6, 0, 0) durBar:SetTall(26) function durBar:Paint() end
	local durLabel = vgui.Create("DLabel", durBar)
	durLabel:Dock(LEFT) durLabel:SetWide(70) durLabel:SetFont("Astral.Body") durLabel:SetTextColor(C.dim) durLabel:SetText("Durée :")
	local minutes = 10
	for _, m in ipairs({ 5, 10, 20, 30, 60 }) do
		local b = button(durBar, m .. " min", function() minutes = m end)
		b:Dock(LEFT) b:SetWide(70) b:DockMargin(0, 0, 6, 0)
		function b:Paint(w, h)
			draw.RoundedBox(4, 0, 0, w, h, minutes == m and C.accent or (self:IsHovered() and C.line or C.panel))
		end
	end
	local grid = vgui.Create("DIconLayout", pnl)
	grid:Dock(TOP) grid:DockMargin(0, 6, 0, 0) grid:SetSpaceX(6) grid:SetSpaceY(6)
	for _, id in ipairs(Astral.Events.Order) do
		local ev = Astral.Events.List[id]
		local col = ev.fx and ev.fx.color or C.accent
		local b = grid:Add("DButton")
		b:SetSize(340, 44) b:SetText("") b:SetTooltip(ev.desc)
		function b:Paint(w, h)
			draw.RoundedBox(6, 0, 0, w, h, self:IsHovered() and C.line or C.panel)
			draw.RoundedBox(2, 0, 6, 4, h - 12, col)
			draw.SimpleText(ev.name, "Astral.Title", 14, 4, C.text)
			draw.SimpleText(ev.desc, "Astral.Body", 14, 25, C.dim)
		end
		b.DoClick = function() request("event_start", id .. "|" .. minutes) end
	end
	grid:SetTall(math.ceil(#Astral.Events.Order / 3) * 50)
	local stop = button(pnl, "Arrêter l'événement en cours", function() request("event_stop") end)
	stop:Dock(TOP) stop:DockMargin(0, 10, 0, 0)
	Admin.handlers.event_start = notifyResult
	Admin.handlers.event_stop = notifyResult
	return pnl
end

---------------------------------------------------------------------------
-- Commandes serveur : actions globales utiles et amusantes (sv_admin.lua, SERVER_CMDS)
---------------------------------------------------------------------------
local function buildCommands(sheet)
	local pnl = vgui.Create("DPanel", sheet)
	pnl:DockPadding(16, 16, 16, 16)
	function pnl:Paint() end
	local function section(title, desc)
		local l = vgui.Create("DLabel", pnl)
		l:Dock(TOP) l:DockMargin(0, 10, 0, 2) l:SetFont("Astral.Title") l:SetTextColor(C.text) l:SetText(title) l:SizeToContents()
		local d = vgui.Create("DLabel", pnl)
		d:Dock(TOP) d:DockMargin(0, 0, 0, 6) d:SetFont("Astral.Body") d:SetTextColor(C.dim) d:SetText(desc) d:SizeToContents()
		local g = vgui.Create("DIconLayout", pnl)
		g:Dock(TOP) g:SetSpaceX(6) g:SetSpaceY(6) g:SetTall(96)
		return g
	end
	local function card(grid, title, desc, col, fn)
		local b = grid:Add("DButton")
		b:SetSize(340, 44) b:SetText("")
		function b:Paint(w, h)
			draw.RoundedBox(6, 0, 0, w, h, self:IsHovered() and C.line or C.panel)
			draw.RoundedBox(2, 0, 6, 4, h - 12, col)
			draw.SimpleText(title, "Astral.Title", 14, 4, C.text)
			draw.SimpleText(desc, "Astral.Body", 14, 25, C.dim)
		end
		b.DoClick = function() surface.PlaySound("ui/buttonclick.wav") fn() end
	end
	local function cmd(name, value) request("server_cmd", name .. (value and ("|" .. value) or "")) end

	local useful = section("Utiles", "Actions sur tous les joueurs connectés. Toutes sont journalisées.")
	card(useful, "Soigner tout le monde", "Vie au maximum, au moins 50 d'armure", C.good, function() cmd("heal_all") end)
	card(useful, "Geler tout le monde", "Sauf toi ; idéal pour une annonce", C.accent, function() cmd("freeze_all") end)
	card(useful, "Dégeler tout le monde", "Rend la main à tous les joueurs", C.accent, function() cmd("unfreeze_all") end)
	card(useful, "Effacer les impacts", "Taches et impacts de balles, chez tous", C.dim, function() cmd("cleanup_decals") end)

	local fun = section("Fun", "Animations pour la communauté.")
	card(fun, "Spectacle de feux d'artifice", "10 fusées au-dessus des joueurs", Color(255, 90, 200), function() cmd("fireworks") end)
	card(fun, "Pluie de billets…", "Donne une somme à chaque joueur", Color(255, 205, 60), function()
		askValue("Pluie de billets", "Montant donné à CHAQUE joueur connecté", "100000", function(v) cmd("money_rain", v) end)
	end)
	card(fun, "Ralenti (activer / couper)", "Le temps s'écoule à moitié vitesse", Color(170, 130, 255), function() cmd("slowmo") end)

	Admin.handlers.server_cmd = notifyResult
	return pnl
end

---------------------------------------------------------------------------
-- Équilibrage : réglages modifiables en jeu (validés et enregistrés par le serveur, sv_settings.lua)
---------------------------------------------------------------------------
local function fmtValue(v)
	if not isnumber(v) then return tostring(v) end
	if math.floor(v) == v then return string.Comma(v) end
	return tostring(math.Round(v, 3))
end

local function buildSettings(sheet)
	local pnl = vgui.Create("DPanel", sheet)
	pnl:DockPadding(8, 8, 8, 8)
	function pnl:Paint() end
	local bar = vgui.Create("DPanel", pnl)
	bar:Dock(TOP) bar:SetTall(26) bar:DockMargin(0, 0, 0, 6) function bar:Paint() end
	local refresh = button(bar, "Actualiser", function() request("settings_list") end)
	refresh:Dock(LEFT) refresh:SetWide(110)
	local hint = vgui.Create("DLabel", bar)
	hint:Dock(FILL) hint:DockMargin(12, 0, 0, 0) hint:SetFont("Astral.Body") hint:SetTextColor(C.dim)
	hint:SetText("Double-clic : modifier  ·  clic droit : rétablir la valeur par défaut  ·  appliqué tout de suite, conservé après redémarrage")
	local list = vgui.Create("DListView", pnl)
	list:Dock(FILL) list:SetMultiSelect(false)
	list:AddColumn("Groupe"):SetFixedWidth(150)
	list:AddColumn("Réglage")
	list:AddColumn("Valeur"):SetFixedWidth(120)
	list:AddColumn("Défaut"):SetFixedWidth(120)
	list:AddColumn("Plage autorisée"):SetFixedWidth(170)
	styleList(list)
	local function fill(data)
		if data.error then return notifyResult(data) end
		if data.message then notifyResult(data) end
		if not data.settings then return end
		list:Clear()
		for _, s in ipairs(data.settings) do
			local range = (s.min and fmtValue(s.min) or "—") .. " à " .. (s.max and fmtValue(s.max) or "—") .. (s.integer and " (entier)" or "")
			local line = addLine(list, s.group, s.label, fmtValue(s.value), fmtValue(s.default), range)
			line.setting = s
			if s.value ~= s.default then for _, col in ipairs(line.Columns) do col:SetTextColor(Color(255, 200, 90)) end end
		end
	end
	function list:DoDoubleClick(_, line)
		local s = line.setting
		if not s then return end
		askValue("Équilibrage", s.label .. "\nValeur actuelle : " .. fmtValue(s.value) .. " (défaut " .. fmtValue(s.default) .. ")", tostring(s.value), function(v)
			request("settings_set", s.path .. "|" .. v)
		end)
	end
	function list:OnRowRightClick(_, line)
		local s = line.setting
		if not s then return end
		local m = DermaMenu()
		m:AddOption("Rétablir la valeur par défaut (" .. fmtValue(s.default) .. ")", function() request("settings_reset", s.path) end):SetIcon("icon16/arrow_undo.png")
		m:Open()
	end
	Admin.handlers.settings_list = fill
	Admin.handlers.settings_set = fill
	Admin.handlers.settings_reset = fill
	request("settings_list")
	return pnl
end

---------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------
function Admin.Open()
	if IsValid(Admin.Frame) then Admin.Frame:Remove() end
	local f = vgui.Create("DFrame")
	Admin.Frame = f
	f:SetSize(math.min(ScrW() - 40, 1150), math.min(ScrH() - 40, 700))
	f:Center()
	f:SetTitle("")
	f:MakePopup()
	f.btnMinim:SetVisible(false) f.btnMaxim:SetVisible(false)
	function f:Paint(w, h)
		draw.RoundedBox(8, 0, 0, w, h, C.bg)
		draw.SimpleText("ASTRAL", "Astral.Title", 14, 6, C.accent)
		draw.SimpleText("Administration", "Astral.Title", 100, 6, C.text)
		surface.SetDrawColor(C.line) surface.DrawLine(0, 34, w, 34)
	end
	local sheet = vgui.Create("DPropertySheet", f)
	sheet:Dock(FILL) sheet:DockMargin(0, 10, 0, 0)
	function sheet:Paint() end
	sheet:AddSheet("Joueurs", buildPlayers(sheet), "icon16/group.png")
	sheet:AddSheet("Machines", buildEntities(sheet), "icon16/cog.png")
	sheet:AddSheet("Annonce & événements", buildAnnounce(sheet), "icon16/sound.png")
	sheet:AddSheet("Commandes", buildCommands(sheet), "icon16/lightning.png")
	sheet:AddSheet("Diagnostic", buildDiag(sheet), "icon16/monitor.png")
	sheet:AddSheet("Économie", buildEconomy(sheet), "icon16/money.png")
	sheet:AddSheet("Équilibrage", buildSettings(sheet), "icon16/wrench.png")
	sheet:AddSheet("Journaux", buildLogs(sheet), "icon16/book.png")
	for _, item in ipairs(sheet.Items) do
		item.Tab:SetTextColor(C.text)
		function item.Tab:Paint(w, h) draw.RoundedBoxEx(4, 0, 0, w, h - 6, self:IsActive() and C.line or C.panel, true, true, false, false) end
	end
end

net.Receive("Astral.Admin.Open", function()
	Admin.categories = net.ReadTable()
	Admin.Open()
end)

net.Receive("Astral.Admin.Data", function()
	local action = net.ReadString()
	local len = net.ReadUInt(16)
	local raw = util.Decompress(net.ReadData(len) or "")
	local data = raw and util.JSONToTable(raw) or { error = "Réponse illisible." }
	local handler = Admin.handlers[action]
	if handler then handler(data) end
end)

concommand.Add("astral_menu", function() request("open") end)
