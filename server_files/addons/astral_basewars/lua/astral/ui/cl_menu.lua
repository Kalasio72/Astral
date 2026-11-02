-- Astral UI — menu principal (touche F3).
-- Remplace le menu SpaceVX (cl_bwmenu.lua : hook Think « BaseWars.Menu.Open ») en reprenant toutes ses fonctions :
-- factions (créer / rejoindre / quitter), raids (lancer / abandonner), règles ; ajoute un accueil et une aide en français.
-- Les actions passent par les fonctions client SpaceVX existantes (CreateFaction, JoinFaction, LeaveFaction,
-- StartRaid, ConceedRaid) : le serveur vérifie tout, comme avant. astral_hud 0 rétablit le menu d'origine.

local UI = Astral.UI
local C = UI.Colors
local S = UI.Scale

local function section(parent, title, subtitle)
	local p = vgui.Create("DPanel", parent)
	p:Dock(FILL) p:DockPadding(S(20), S(16), S(20), S(16))
	function p:Paint() end
	local t = UI.Label(p, title, "Astral.UI.Huge", C.text)
	t:Dock(TOP)
	if subtitle then
		local s = UI.Label(p, subtitle, "Astral.UI.Small", C.dim)
		s:Dock(TOP) s:DockMargin(0, S(2), 0, S(12))
	end
	return p
end

-- Liste de lignes sélectionnables ; rows = { { text, sub, color, data }, ... }
local function rowList(parent, onSelect)
	local scroll = vgui.Create("DScrollPanel", parent)
	scroll:Dock(FILL)
	scroll.selected = nil
	function scroll:SetRows(rows)
		self:Clear()
		for _, r in ipairs(rows) do
			local b = self:Add("DButton")
			b:Dock(TOP) b:DockMargin(0, 0, 0, S(4)) b:SetTall(S(40)) b:SetText("")
			b.data = r.data
			function b:Paint(w, h)
				local sel = scroll.selected == self.data
				draw.RoundedBox(S(6), 0, 0, w, h, sel and C.line or (self:IsHovered() and C.panel or ColorAlpha(C.panel, 140)))
				if r.color then draw.RoundedBox(S(3), S(10), h / 2 - S(5), S(10), S(10), r.color) end
				draw.SimpleText(r.text, "Astral.UI.Text", S(30), h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				if r.sub then draw.SimpleText(r.sub, "Astral.UI.Small", w - S(12), h / 2, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER) end
			end
			b.DoClick = function() scroll.selected = r.data if onSelect then onSelect(r.data) end end
		end
	end
	return scroll
end

local function factionList()
	local list = {}
	for id, t in pairs(team.GetAllTeams()) do
		if id > 1 and id < 1000 and team.NumPlayers(id) > 0 then
			list[#list + 1] = { text = t.Name, sub = team.NumPlayers(id) .. " membre(s)", color = t.Color, data = t.Name }
		end
	end
	table.SortByMember(list, "text", true)
	return list
end

local function playerRows(me)
	local rows = {}
	for _, p in player.Iterator() do
		if p ~= me then
			local fac = p:InFaction() and p:GetFaction() or "Sans faction"
			rows[#rows + 1] = { text = p:Nick(), sub = fac, color = team.GetColor(p:Team()), data = p }
		end
	end
	table.SortByMember(rows, "text", true)
	return rows
end

---------------------------------------------------------------------------
-- Boîtes de dialogue
---------------------------------------------------------------------------
local PALETTE = {
	Color(110, 205, 255), Color(170, 130, 255), Color(255, 105, 115), Color(110, 225, 150),
	Color(255, 200, 90), Color(255, 140, 200), Color(90, 230, 220), Color(240, 240, 255),
}

local function dialogCreateFaction()
	local f = UI.Frame("Créer une faction", S(460), S(330))
	local body = vgui.Create("DPanel", f)
	body:Dock(FILL) body:DockMargin(S(6), S(26), S(6), S(6)) function body:Paint() end
	UI.Label(body, "Nom (5 à 36 caractères)", "Astral.UI.Small", C.dim):Dock(TOP)
	local name = UI.Input(body, "Nom de la faction") name:Dock(TOP) name:DockMargin(0, S(4), 0, S(10))
	UI.Label(body, "Mot de passe (facultatif, 5 à 32 caractères)", "Astral.UI.Small", C.dim):Dock(TOP)
	local pw = UI.Input(body, "Laisser vide pour une faction ouverte") pw:Dock(TOP) pw:DockMargin(0, S(4), 0, S(10))
	UI.Label(body, "Couleur", "Astral.UI.Small", C.dim):Dock(TOP)
	local chosen = PALETTE[math.random(#PALETTE)]
	local swatches = vgui.Create("DPanel", body)
	swatches:Dock(TOP) swatches:SetTall(S(30)) swatches:DockMargin(0, S(4), 0, S(14)) function swatches:Paint() end
	for _, col in ipairs(PALETTE) do
		local sw = vgui.Create("DButton", swatches)
		sw:Dock(LEFT) sw:SetWide(S(30)) sw:DockMargin(0, 0, S(6), 0) sw:SetText("")
		function sw:Paint(w, h)
			draw.RoundedBox(S(6), 0, 0, w, h, col)
			if chosen == col then surface.SetDrawColor(C.text) surface.DrawOutlinedRect(0, 0, w, h, 2) end
		end
		sw.DoClick = function() chosen = col end
	end
	local ok = UI.Button(body, "Créer", C.good, function()
		local n, p = name:GetValue():Trim(), pw:GetValue():Trim()
		LocalPlayer():CreateFaction(n, #p > 0 and p or nil, chosen)
		f:Close()
	end)
	ok:Dock(TOP)
	function ok:Think()
		local n, p = name:GetValue():Trim(), pw:GetValue():Trim()
		self:SetDisabled(utf8.len(n) < 5 or utf8.len(n) > 36 or (#p > 0 and (#p < 5 or #p > 32)))
	end
end

local function dialogJoinFaction(prefill)
	local f = UI.Frame("Rejoindre une faction", S(460), S(250))
	local body = vgui.Create("DPanel", f)
	body:Dock(FILL) body:DockMargin(S(6), S(26), S(6), S(6)) function body:Paint() end
	local name = UI.Input(body, "Nom de la faction") name:Dock(TOP) name:DockMargin(0, 0, 0, S(10))
	name:SetValue(prefill or "")
	local pw = UI.Input(body, "Mot de passe (si la faction en a un)") pw:Dock(TOP) pw:DockMargin(0, 0, 0, S(14))
	local ok = UI.Button(body, "Rejoindre", C.good, function()
		local p = pw:GetValue():Trim()
		LocalPlayer():JoinFaction(name:GetValue():Trim(), #p > 0 and p or nil, true)
		f:Close()
	end)
	ok:Dock(TOP)
	function ok:Think() self:SetDisabled(utf8.len(name:GetValue():Trim()) < 1) end
end

local function dialogConfirm(title, text, label, col, fn)
	local f = UI.Frame(title, S(440), S(190))
	local body = vgui.Create("DPanel", f)
	body:Dock(FILL) body:DockMargin(S(6), S(26), S(6), S(6)) function body:Paint() end
	local l = UI.Label(body, text, "Astral.UI.Text", C.text) l:Dock(TOP) l:SetWrap(true) l:SetTall(S(50))
	local ok = UI.Button(body, label, col, function() fn() f:Close() end) ok:Dock(TOP) ok:DockMargin(0, S(10), 0, 0)
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------
local PAGES = {}

PAGES[#PAGES + 1] = { "Accueil", function(parent, me)
	local p = section(parent, "Bienvenue sur Astral BaseWars", "Construis ta base, produis, défends-toi et attaque les bases adverses.")
	local stats = vgui.Create("DPanel", p)
	stats:Dock(TOP) stats:SetTall(S(150)) stats:DockMargin(0, 0, 0, S(16))
	function stats:Paint(w, h)
		draw.RoundedBox(S(8), 0, 0, w, h, C.panel)
		local items = {
			{ "Argent", UI.Money(me:GetMoney()), C.accent },
			{ "Niveau", tostring(me:GetLevel()), C.xp },
			{ "Temps de jeu", me.GetPlayTime and (math.floor((me:GetPlayTime() or 0) / 3600) .. " h") or "—", C.good },
			{ "Faction", me:InFaction() and me:GetFaction() or "Aucune", C.accent2 },
		}
		local cw = w / #items
		for i, it in ipairs(items) do
			local x = (i - 1) * cw + cw / 2
			draw.SimpleText(it[1], "Astral.UI.Small", x, S(36), C.dim, TEXT_ALIGN_CENTER)
			draw.SimpleText(it[2], "Astral.UI.Big", x, S(62), it[3], TEXT_ALIGN_CENTER)
		end
		if me.GetPlayTimeTable then
			local t = me:GetPlayTimeTable()
			draw.SimpleText(string.format("Temps de jeu total : %d h %02d min", t.h, t.m), "Astral.UI.Small", w / 2, S(116), C.dim, TEXT_ALIGN_CENTER)
		end
	end
	local quick = vgui.Create("DPanel", p)
	quick:Dock(TOP) quick:SetTall(S(34)) function quick:Paint() end
	local shop = UI.Button(quick, "Ouvrir la boutique (F4)", C.accent, function() if IsValid(Astral.Menu.Frame) then Astral.Menu.Frame:Close() end if UI.OpenShop then UI.OpenShop() end end)
	shop:Dock(LEFT) shop:SetWide(S(260))
	local tips = UI.Label(p, "Astuce : regarde une machine et tape /upg pour l'améliorer, /sell pour la revendre.", "Astral.UI.Small", C.dim)
	tips:Dock(TOP) tips:DockMargin(0, S(16), 0, 0)
end }

-- Quêtes : données envoyées par le serveur (Astral.Quests.Sync), définitions partagées (sh_quests.lua)
Astral.QuestData = Astral.QuestData or { list = {}, dailyLeft = 0, weeklyLeft = 0, at = 0 }
net.Receive("Astral.Quests.Sync", function()
	local d = Astral.QuestData
	d.dailyLeft, d.weeklyLeft = net.ReadUInt(32), net.ReadUInt(32)
	d.list, d.at = net.ReadTable(), RealTime()
end)

local function fmtLeft(s)
	s = math.max(0, math.floor(s))
	local d, h, m = math.floor(s / 86400), math.floor(s / 3600) % 24, math.floor(s / 60) % 60
	return d > 0 and string.format("%d j %d h", d, h) or string.format("%d h %02d min", h, m)
end

PAGES[#PAGES + 1] = { "Quêtes", function(parent, me)
	local p = section(parent, "Quêtes", "Nouvelles quêtes chaque jour à minuit et chaque lundi. Réclame tes récompenses ici.")
	net.Start("Astral.Quests.Request") net.SendToServer()
	local scroll = vgui.Create("DScrollPanel", p) scroll:Dock(FILL)
	local function build()
		if not IsValid(scroll) then return end
		scroll:Clear()
		local data = Astral.QuestData
		local elapsed = RealTime() - data.at
		for _, kind in ipairs({ { "d", "Quotidiennes", data.dailyLeft }, { "w", "Hebdomadaires", data.weeklyLeft } }) do
			local head = scroll:Add("DPanel")
			head:Dock(TOP) head:SetTall(S(34)) head:DockMargin(0, S(6), 0, S(4))
			function head:Paint(w, h)
				draw.SimpleText(kind[2], "Astral.UI.Big", 0, h / 2, C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText("Réinitialisation dans " .. fmtLeft(kind[3] - (RealTime() - data.at)), "Astral.UI.Small", w, h / 2, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
			for _, e in ipairs(data.list) do
				local q = Astral.Quests.ById[e.id]
				if q and e.period:sub(1, 1) == kind[1] then
					local done = e.progress >= q.goal
					local card = scroll:Add("DPanel")
					card:Dock(TOP) card:SetTall(S(86)) card:DockMargin(0, 0, 0, S(6))
					function card:Paint(w, h)
						draw.RoundedBox(S(8), 0, 0, w, h, C.panel)
						if done then draw.RoundedBoxEx(S(8), 0, 0, S(4), h, e.claimed and C.dim or C.good, true, false, true, false) end
						draw.SimpleText(q.name, "Astral.UI.Big", S(16), S(10), e.claimed and C.dim or C.text)
						draw.SimpleText(string.format(q.desc, Astral.Quests.FormatGoal(q)), "Astral.UI.Small", S(16), S(38), C.dim)
						local barW = w - S(230)
						UI.Bar(S(16), S(62), barW, S(8), e.progress / q.goal, done and C.good or C.accent)
						local prog = Astral.Quests.MoneyCounters[q.counter] and (UI.Money(e.progress) .. " / " .. Astral.Quests.FormatGoal(q)) or (e.progress .. " / " .. q.goal)
						draw.SimpleText(prog, "Astral.UI.Tiny", S(16) + barW, S(46), C.dim, TEXT_ALIGN_RIGHT)
						draw.SimpleText(UI.Money(q.money) .. "  +" .. q.xp .. " XP", "Astral.UI.Small", w - S(16), S(12), C.warn, TEXT_ALIGN_RIGHT)
					end
					local btn = UI.Button(card, e.claimed and "Réclamée" or (done and "Réclamer" or "En cours"), C.good, function()
						net.Start("Astral.Quests.Claim") net.WriteString(e.period) net.WriteString(e.id) net.SendToServer()
						timer.Simple(0.5, build)
					end)
					btn:SetSize(S(150), S(32))
					function card:PerformLayout(w) btn:SetPos(w - S(166), S(44)) end
					btn:SetDisabled(e.claimed or not done)
				end
			end
		end
	end
	build()
	timer.Simple(0.6, build)
end }

-- Recherche : état envoyé par le serveur (Astral.Research.Sync) : technologies débloquées + composants en stock
Astral.ResearchData = Astral.ResearchData or { unlocked = {}, stock = {} }
net.Receive("Astral.Research.Sync", function()
	local d = Astral.ResearchData
	d.unlocked = {}
	for _, id in ipairs(net.ReadTable()) do d.unlocked[id] = true end
	d.stock = net.ReadTable()
end)

PAGES[#PAGES + 1] = { "Recherche", function(parent, me)
	local p = section(parent, "Recherche", "Améliore toutes tes machines Astral. Les composants sont pris dans tes conteneurs industriels.")
	net.Start("Astral.Research.Request") net.SendToServer()
	local scroll = vgui.Create("DScrollPanel", p) scroll:Dock(FILL)
	local function build()
		if not IsValid(scroll) then return end
		scroll:Clear()
		local d = Astral.ResearchData
		local tier = 0
		for _, t in ipairs(Astral.Research.Techs) do
			if t.tier ~= tier then
				tier = t.tier
				local h = UI.Label(scroll, "Niveau technologique " .. tier, "Astral.UI.Big", C.accent)
				h:Dock(TOP) h:DockMargin(0, S(8), 0, S(4))
			end
			local done = d.unlocked[t.id]
			local locked = t.requires and not d.unlocked[t.requires]
			local parts = { UI.Money(t.money) }
			local enough = me:GetMoney() >= t.money
			for res, q in SortedPairs(t.items) do
				local have = d.stock[res] or 0
				if have < q then enough = false end
				parts[#parts + 1] = string.format("%d/%d %s", math.min(have, q), q, Astral.Resources.Get(res).name)
			end
			local card = scroll:Add("DPanel")
			card:Dock(TOP) card:SetTall(S(84)) card:DockMargin(0, 0, 0, S(6))
			function card:Paint(w, h)
				draw.RoundedBox(S(8), 0, 0, w, h, C.panel)
				draw.RoundedBoxEx(S(8), 0, 0, S(4), h, done and C.good or (locked and C.line or C.accent2), true, false, true, false)
				draw.SimpleText(t.name, "Astral.UI.Big", S(18), S(10), locked and C.dim or C.text)
				draw.SimpleText(t.desc, "Astral.UI.Small", S(18), S(38), C.dim)
				local status = done and "Débloquée" or (locked and ("Nécessite : " .. Astral.Research.ById[t.requires].name) or table.concat(parts, "  ·  "))
				draw.SimpleText(status, "Astral.UI.Small", S(18), S(58), done and C.good or (enough and C.warn or C.dim))
			end
			local btn = UI.Button(card, done and "Débloquée" or "Rechercher", C.accent2, function()
				net.Start("Astral.Research.Unlock") net.WriteString(t.id) net.SendToServer()
				timer.Simple(0.8, build)
			end)
			btn:SetSize(S(150), S(32))
			function card:PerformLayout(w) btn:SetPos(w - S(166), S(26)) end
			btn:SetDisabled(done or locked or not enough)
		end
	end
	build()
	timer.Simple(0.6, build)
end }

-- Marché : offres envoyées par le serveur (sv_market.lua) ; le serveur revérifie tout (stock, prix, argent, place)
Astral.MarketData = Astral.MarketData or { list = {}, mine = {}, stock = {} }
local marketRefresh
net.Receive("Astral.Market.Sync", function()
	local d = Astral.MarketData
	d.list, d.mine, d.stock = net.ReadTable(), net.ReadTable(), net.ReadTable()
	if marketRefresh then marketRefresh() end
end)

local function mcfg(k, d) return Astral.Cfg("Market." .. k, d) end

-- Boîte de dialogue « quantité (+ prix) » avec récapitulatif calculé en direct
local function marketDialog(title, res, maxQty, fixedPrice, onConfirm)
	local f = UI.Frame(title, S(440), fixedPrice and S(250) or S(330))
	local body = vgui.Create("DPanel", f)
	body:Dock(FILL) body:DockMargin(S(6), S(26), S(6), S(6)) function body:Paint() end
	UI.Label(body, string.format("Quantité (1 à %d)", maxQty), "Astral.UI.Small", C.dim):Dock(TOP)
	local qty = UI.Input(body, "Quantité") qty:Dock(TOP) qty:DockMargin(0, S(4), 0, S(10)) qty:SetNumeric(true) qty:SetValue(tostring(maxQty))
	local price
	local minP, maxP = math.max(1, math.ceil(res.value * mcfg("MinPriceFactor", 0.25))), math.floor(res.value * mcfg("MaxPriceFactor", 10))
	if not fixedPrice then
		UI.Label(body, string.format("Prix unitaire (%s à %s, référence %s)", UI.Money(minP), UI.Money(maxP), UI.Money(res.value)), "Astral.UI.Small", C.dim):Dock(TOP)
		price = UI.Input(body, "Prix unitaire") price:Dock(TOP) price:DockMargin(0, S(4), 0, S(10)) price:SetNumeric(true) price:SetValue(tostring(res.value))
	end
	local function values()
		local q = math.floor(tonumber(qty:GetValue()) or 0)
		local p = fixedPrice or math.floor(tonumber(price:GetValue()) or 0)
		return q, p
	end
	local recap = vgui.Create("DPanel", body)
	recap:Dock(TOP) recap:SetTall(S(40)) recap:DockMargin(0, 0, 0, S(10))
	function recap:Paint(w, h)
		draw.RoundedBox(S(6), 0, 0, w, h, C.panel)
		local q, p = values()
		local total = q * p
		local text = fixedPrice and ("Total : " .. UI.Money(total))
			or string.format("Total %s  ·  taxe %d %%  ·  tu recevras %s", UI.Money(total), mcfg("TaxPercent", 5), UI.Money(total - math.floor(total * mcfg("TaxPercent", 5) / 100)))
		draw.SimpleText(text, "Astral.UI.Small", S(12), h / 2, C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	local ok = UI.Button(body, fixedPrice and "Acheter" or "Mettre en vente", C.good, function()
		local q, p = values()
		onConfirm(q, p)
		f:Close()
	end)
	ok:Dock(TOP)
	function ok:Think()
		local q, p = values()
		local bad = q < 1 or q > maxQty or (not fixedPrice and (p < minP or p > maxP))
		if fixedPrice and q * p > LocalPlayer():GetMoney() then bad = true end
		self:SetDisabled(bad)
	end
end

local function marketRow(parent, res, title, sub, right, btnLabel, btnCol, onClick)
	local row = parent:Add("DPanel")
	row:Dock(TOP) row:SetTall(S(54)) row:DockMargin(0, 0, 0, S(4))
	function row:Paint(w, h)
		draw.RoundedBox(S(6), 0, 0, w, h, C.panel)
		draw.RoundedBox(S(4), S(12), h / 2 - S(7), S(14), S(14), res.color)
		draw.SimpleText(title, "Astral.UI.Text", S(36), S(8), C.text)
		draw.SimpleText(sub, "Astral.UI.Small", S(36), S(30), C.dim)
		draw.SimpleText(right, "Astral.UI.Big", w - S(150), h / 2, C.accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
	local b = UI.Button(row, btnLabel, btnCol, onClick)
	b:SetSize(S(120), S(32))
	function row:PerformLayout(w, h) b:SetPos(w - S(132), h / 2 - S(16)) end
	return row
end

PAGES[#PAGES + 1] = { "Marché", function(parent, me)
	local p = section(parent, "Marché", string.format("Achète et vends des ressources entre joueurs. Taxe de %d %% sur les ventes, payée par le vendeur.", mcfg("TaxPercent", 5)))
	net.Start("Astral.Market.Request") net.SendToServer()
	function p:OnRemove() marketRefresh = nil net.Start("Astral.Market.Close") net.SendToServer() end
	local tab = "buy"
	local tabs = vgui.Create("DPanel", p)
	tabs:Dock(TOP) tabs:SetTall(S(34)) tabs:DockMargin(0, 0, 0, S(10)) function tabs:Paint() end
	local scroll = vgui.Create("DScrollPanel", p) scroll:Dock(FILL)
	local function empty(text) UI.Label(scroll, text, "Astral.UI.Text", C.dim):Dock(TOP) end
	local function build()
		if not IsValid(scroll) then return end
		scroll:Clear()
		local d = Astral.MarketData
		if tab == "buy" then
			if #d.list == 0 then return empty("Aucune offre pour l'instant. Reviens plus tard ou mets tes ressources en vente !") end
			for _, o in ipairs(d.list) do
				local res = Astral.Resources.Get(o.r)
				if res then
					local diff = math.floor((o.p / res.value - 1) * 100)
					marketRow(scroll, res, string.format("%s  ×%d", res.name, o.q), string.format("Vendu par %s  ·  référence %s (%s%d %%)", o.s, UI.Money(res.value), diff >= 0 and "+" or "", diff),
						UI.Money(o.p) .. " /u", "Acheter", C.good, function()
							marketDialog("Acheter : " .. res.name, res, o.q, o.p, function(q)
								net.Start("Astral.Market.Buy") net.WriteUInt(o.id, 32) net.WriteUInt(q, 16) net.SendToServer()
							end)
						end)
				end
			end
		elseif tab == "sell" then
			local any = false
			for _, id in ipairs(Astral.Resources.order) do
				local have = d.stock[id] or 0
				local res = Astral.Resources.Get(id)
				if have > 0 and res then
					any = true
					marketRow(scroll, res, res.name, string.format("%d en stock dans tes conteneurs", have), UI.Money(res.value) .. " /u", "Vendre", C.accent, function()
						marketDialog("Mettre en vente : " .. res.name, res, math.min(have, mcfg("MaxQty", 500)), nil, function(q, pr)
							net.Start("Astral.Market.Sell") net.WriteString(id) net.WriteUInt(q, 16) net.WriteUInt(pr, 32) net.SendToServer()
						end)
					end)
				end
			end
			if not any then empty("Tes conteneurs industriels sont vides : produis des ressources (foreuse, raffinerie, serre…) pour les vendre ici.") end
		else
			if #d.mine == 0 then return empty(string.format("Tu n'as aucune offre ouverte (maximum %d).", mcfg("MaxOrders", 5))) end
			for _, o in ipairs(d.mine) do
				local res = Astral.Resources.Get(o.r)
				if res then
					marketRow(scroll, res, string.format("%s  ×%d", res.name, o.q), "Publiée le " .. os.date("%d/%m à %H:%M", o.t), UI.Money(o.p) .. " /u", "Retirer", C.bad, function()
						net.Start("Astral.Market.Cancel") net.WriteUInt(o.id, 32) net.SendToServer()
					end)
				end
			end
		end
	end
	marketRefresh = build
	for _, t in ipairs({ { "buy", "Acheter" }, { "sell", "Vendre" }, { "mine", "Mes offres" } }) do
		local btn = vgui.Create("DButton", tabs)
		btn:Dock(LEFT) btn:SetWide(S(140)) btn:DockMargin(0, 0, S(6), 0) btn:SetText("")
		function btn:Paint(w, h)
			local active = tab == t[1]
			draw.RoundedBox(S(6), 0, 0, w, h, active and C.line or (self:IsHovered() and C.panel or ColorAlpha(C.panel, 120)))
			if active then draw.RoundedBox(S(2), S(10), h - S(4), w - S(20), S(2), C.accent) end
			local label = t[2] .. (t[1] == "mine" and #Astral.MarketData.mine > 0 and ("  (" .. #Astral.MarketData.mine .. ")") or "")
			draw.SimpleText(label, "Astral.UI.Small", w / 2, h / 2, active and C.text or C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		btn.DoClick = function() tab = t[1] build() end
	end
	build()
end }

-- Classements : top 10 calculé par le serveur (sv_stats.lua, cache 60 s)
Astral.LeadersData = Astral.LeadersData or { boards = {}, at = 0 }
net.Receive("Astral.Leaders.Sync", function()
	Astral.LeadersData.boards, Astral.LeadersData.at = net.ReadTable(), RealTime()
end)

local function fmtDuration(s)
	s = math.floor(tonumber(s) or 0)
	return string.format("%d h %02d min", math.floor(s / 3600), math.floor(s / 60) % 60)
end

local BOARDS = {
	{ id = "money",    name = "Fortune",      desc = "Argent possédé",                      fmt = function(e) return UI.Money(e.v) end },
	{ id = "level",    name = "Niveau",       desc = "Niveau atteint",                      fmt = function(e) return "Niveau " .. e.v end },
	{ id = "time",     name = "Temps de jeu", desc = "Temps total passé sur le serveur",    fmt = function(e) return fmtDuration(e.v) end },
	{ id = "industry", name = "Industriels",  desc = "Gains cumulés des ventes industrielles", fmt = function(e) return UI.Money(e.v) end },
	{ id = "produced", name = "Producteurs",  desc = "Unités raffinées, fabriquées et récoltées", fmt = function(e) return string.Comma(e.v) .. " unités" end },
}
local MEDALS = { Color(255, 205, 90), Color(205, 215, 230), Color(220, 150, 95) }

PAGES[#PAGES + 1] = { "Classements", function(parent, me)
	local p = section(parent, "Classements", "Les 10 meilleurs joueurs du serveur. Mis à jour toutes les minutes.")
	net.Start("Astral.Leaders.Request") net.SendToServer()
	local current = BOARDS[1]
	local tabs = vgui.Create("DPanel", p)
	tabs:Dock(TOP) tabs:SetTall(S(34)) tabs:DockMargin(0, 0, 0, S(10)) function tabs:Paint() end
	local scroll = vgui.Create("DScrollPanel", p) scroll:Dock(FILL)
	local mySid = me:SteamID64()
	local function build()
		if not IsValid(scroll) then return end
		scroll:Clear()
		local rows = Astral.LeadersData.boards[current.id]
		local head = UI.Label(scroll, current.desc, "Astral.UI.Small", C.dim) head:Dock(TOP) head:DockMargin(0, 0, 0, S(6))
		if not rows then
			UI.Label(scroll, "Chargement…", "Astral.UI.Text", C.dim):Dock(TOP)
			return
		end
		if #rows == 0 then
			UI.Label(scroll, "Personne n'est encore classé ici : à toi de jouer !", "Astral.UI.Text", C.dim):Dock(TOP)
			return
		end
		for i, e in ipairs(rows) do
			local row = scroll:Add("DPanel")
			row:Dock(TOP) row:SetTall(S(46)) row:DockMargin(0, 0, 0, S(4))
			local mine = e.sid == mySid
			local value = current.fmt(e)
			function row:Paint(w, h)
				draw.RoundedBox(S(6), 0, 0, w, h, mine and C.line or C.panel)
				local medal = MEDALS[i]
				if medal then
					draw.RoundedBox(S(14), S(10), h / 2 - S(14), S(28), S(28), ColorAlpha(medal, 40))
					draw.SimpleText(tostring(i), "Astral.UI.Big", S(24), h / 2, medal, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				else
					draw.SimpleText(tostring(i), "Astral.UI.Text", S(24), h / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
				local name = UI.Truncate(e.name, "Astral.UI.Text", w * 0.5)
				local nameW = draw.SimpleText(name, "Astral.UI.Text", S(52), h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				if e.online then draw.RoundedBox(S(4), S(52) + nameW + S(10), h / 2 - S(4), S(8), S(8), C.good) end
				draw.SimpleText(value, "Astral.UI.Big", w - S(16), h / 2, i <= 3 and MEDALS[i] or C.accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end
		local note = UI.Label(scroll, "● en ligne", "Astral.UI.Tiny", C.good) note:Dock(TOP) note:DockMargin(S(4), S(6), 0, 0)
	end
	for _, b in ipairs(BOARDS) do
		local btn = vgui.Create("DButton", tabs)
		btn:Dock(LEFT) btn:SetWide(S(130)) btn:DockMargin(0, 0, S(6), 0) btn:SetText("")
		function btn:Paint(w, h)
			local active = current == b
			draw.RoundedBox(S(6), 0, 0, w, h, active and C.line or (self:IsHovered() and C.panel or ColorAlpha(C.panel, 120)))
			if active then draw.RoundedBox(S(2), S(10), h - S(4), w - S(20), S(2), C.accent) end
			draw.SimpleText(b.name, "Astral.UI.Small", w / 2, h / 2, active and C.text or C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		btn.DoClick = function() current = b build() end
	end
	build()
	timer.Simple(0.6, build)
	timer.Simple(1.5, build)
end }

PAGES[#PAGES + 1] = { "Factions", function(parent, me)
	local p = section(parent, "Factions", me:InFaction() and ("Ta faction : " .. me:GetFaction()) or "Tu n'es dans aucune faction.")
	local bar = vgui.Create("DPanel", p)
	bar:Dock(BOTTOM) bar:SetTall(S(34)) bar:DockMargin(0, S(12), 0, 0) function bar:Paint() end
	local selected
	local list = rowList(p, function(name) selected = name end)
	list:SetRows(factionList())
	local create = UI.Button(bar, "Créer", C.good, dialogCreateFaction) create:Dock(LEFT) create:SetWide(S(150))
	local join = UI.Button(bar, "Rejoindre", C.accent, function() dialogJoinFaction(selected) end) join:Dock(LEFT) join:SetWide(S(150)) join:DockMargin(S(8), 0, 0, 0)
	local leave = UI.Button(bar, "Quitter", C.bad, function()
		local leader = me:InFaction(nil, true)
		dialogConfirm("Quitter la faction", leader and "Tu es le chef : quitter dissoudra la faction pour tous ses membres." or "Quitter ta faction actuelle ?", "Quitter", C.bad, function() me:LeaveFaction(true) end)
	end)
	leave:Dock(LEFT) leave:SetWide(S(150)) leave:DockMargin(S(8), 0, 0, 0)
	function leave:Think() self:SetDisabled(not me:InFaction()) end
	if #factionList() == 0 then
		local empty = UI.Label(p, "Aucune faction pour l'instant : crée la première !", "Astral.UI.Text", C.dim)
		empty:Dock(TOP)
	end
end }

PAGES[#PAGES + 1] = { "Raids", function(parent, me)
	local p = section(parent, "Raids", "Choisis une cible. Le serveur vérifie qu'elle est raidable (imprimantes, délai, factions).")
	local bar = vgui.Create("DPanel", p)
	bar:Dock(BOTTOM) bar:SetTall(S(34)) bar:DockMargin(0, S(12), 0, 0) function bar:Paint() end
	local target
	local list = rowList(p, function(ply) target = ply end)
	list:SetRows(playerRows(me))
	local start = UI.Button(bar, "Lancer le raid", C.bad, function() if IsValid(target) then me:StartRaid(target) end end)
	start:Dock(LEFT) start:SetWide(S(200))
	function start:Think()
		local valid = IsValid(target)
		local inFac = me:InFaction()
		local tFac = valid and target:InFaction() and not target:InFaction(me:GetFaction())
		self:SetDisabled(not valid or (inFac and not tFac) or (tFac and not inFac))
	end
	local give = UI.Button(bar, "Abandonner le raid", C.warn, function() me:ConceedRaid() end)
	give:Dock(LEFT) give:SetWide(S(200)) give:DockMargin(S(8), 0, 0, 0)
	function give:Think() self:SetDisabled(not (me:InRaid() and (not me:InFaction() or me:InFaction(nil, true)))) end
	local rule = UI.Label(p, "Un joueur en faction ne peut raider qu'une autre faction ; un joueur seul, qu'un joueur seul.", "Astral.UI.Small", C.dim)
	rule:Dock(BOTTOM)
end }

PAGES[#PAGES + 1] = { "Règles", function(parent)
	local p = section(parent, "Règles du serveur")
	local scroll = vgui.Create("DScrollPanel", p) scroll:Dock(FILL)
	for i, r in ipairs(Astral.Cfg("Rules", {})) do
		local row = scroll:Add("DPanel")
		row:Dock(TOP) row:DockMargin(0, 0, 0, S(6)) row:DockPadding(S(44), S(10), S(12), S(10))
		function row:Paint(w, h)
			draw.RoundedBox(S(6), 0, 0, w, h, C.panel)
			draw.SimpleText(tostring(i), "Astral.UI.Big", S(22), S(12), C.accent, TEXT_ALIGN_CENTER)
		end
		local l = UI.Label(row, r, "Astral.UI.Text", C.text)
		l:Dock(TOP) l:SetWrap(true) l:SetAutoStretchVertical(true)
		function row:PerformLayout() self:SizeToChildren(false, true) self:SetTall(self:GetTall() + S(10)) end
	end
end }

local HELP = {
	{ "Comment gagner de l'argent ?", "Achète des imprimantes et des générateurs (F4). Les imprimantes ont besoin d'énergie : place un générateur à proximité. E sur ton imprimante ouvre son menu (infos, améliorations), Maj + E récupère l'argent. Une Banque Astral (niveau 10) centralise l'argent de toutes tes imprimantes. Tu reçois aussi une paye toutes les 3 minutes." },
	{ "Les fermes", "F4 → Astral Fermes : cannabis, tabac, feux d'artifice, cocaïne, méthamphétamine. Récolte avec Maj + E (ou E → menu) : la marchandise va dans ton sac. Revends-la au receleur Silas. Si tu meurs, ton sac tombe au sol ! Le labo de méthamphétamine doit être purgé avant 100 °C." },
	{ "Les PNJ", "Ava (guide) répond à tes questions, Barney gère les quêtes et classements, Silas (receleur) rachète la marchandise de tes fermes." },
	{ "Commandes fun", "!roll, !pile, !me <action>, !donner <nom> <somme>, !saluer, !danse, !rire, !applaudir, !sac, !feu, !commandes. Aussi depuis le menu Tab, sur ta fiche ou celle d'un joueur." },
	{ "Astral Industries", "Au niveau 5, achète une foreuse et un conteneur industriel ; au niveau 8, une raffinerie. Les ressources passent toutes seules de machine en machine. Vends le contenu du conteneur avec E." },
	{ "Construire sa base", "Trouve un endroit défendable, ferme les entrées avec des props et utilise l'outil Fading Door pour ta porte. Ne construis pas près du point d'apparition." },
	{ "Les raids", "F3 → Raids. Il faut au moins une imprimante pour raider ou être raidé. Pendant 5 minutes, les deux camps peuvent détruire les props et machines adverses et récupérer l'argent des imprimantes adverses." },
	{ "Commandes utiles", "/upg (améliorer), /sell (revendre), /dw (lâcher son arme), /pm nom message (message privé), !donner nom somme (donner de l'argent)." },
	{ "Niveaux", "Tu gagnes de l'XP en achetant des machines et en récoltant tes imprimantes. Les niveaux débloquent de nouveaux objets." },
}

PAGES[#PAGES + 1] = { "Aide", function(parent)
	local p = section(parent, "Aide", "Les bases pour bien démarrer.")
	local scroll = vgui.Create("DScrollPanel", p) scroll:Dock(FILL)
	for _, h in ipairs(HELP) do
		local card = scroll:Add("DPanel")
		card:Dock(TOP) card:DockMargin(0, 0, 0, S(8)) card:DockPadding(S(16), S(10), S(16), S(10))
		function card:Paint(w, hh) draw.RoundedBox(S(8), 0, 0, w, hh, C.panel) end
		local t = UI.Label(card, h[1], "Astral.UI.Big", C.accent) t:Dock(TOP)
		local d = UI.Label(card, h[2], "Astral.UI.Text", C.text) d:Dock(TOP) d:SetWrap(true) d:SetAutoStretchVertical(true) d:DockMargin(0, S(4), 0, 0)
		function card:PerformLayout() self:SizeToChildren(false, true) self:SetTall(self:GetTall() + S(10)) end
	end
end }

---------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------
Astral.Menu = Astral.Menu or {}
local M = Astral.Menu

function M.Open(pageIndex)
	if IsValid(M.Frame) then M.Frame:Close() end
	local me = LocalPlayer()
	local f = UI.Frame("", math.min(ScrW() - S(80), S(1000)), math.min(ScrH() - S(80), S(640)))
	M.Frame = f
	function f:OnKeyCodePressed(key) if key == KEY_ESCAPE or key == KEY_F3 then self:Close() end end
	function f:Paint(w, h)
		draw.RoundedBox(S(10), 0, 0, w, h, C.bgSolid)
		draw.RoundedBoxEx(S(10), 0, 0, S(220), h, C.bg, true, false, true, false)
		draw.SimpleText("ASTRAL", "Astral.UI.Huge", S(24), S(22), C.accent)
		draw.SimpleText("BASEWARS", "Astral.UI.Small", S(26), S(56), C.dim)
	end
	local nav = vgui.Create("DPanel", f)
	nav:Dock(LEFT) nav:SetWide(S(210)) nav:DockMargin(0, S(70), 0, 0) function nav:Paint() end
	local content = vgui.Create("DPanel", f)
	content:Dock(FILL) content:DockMargin(S(10), 0, 0, 0) function content:Paint() end
	local current = pageIndex or 1
	local function show(i)
		current = i
		content:Clear()
		PAGES[i][2](content, me)
	end
	for i, page in ipairs(PAGES) do
		local b = vgui.Create("DButton", nav)
		b:Dock(TOP) b:DockMargin(S(10), 0, 0, S(4)) b:SetTall(S(40)) b:SetText("")
		function b:Paint(w, h)
			local active = current == i
			draw.RoundedBox(S(6), 0, 0, w, h, active and C.line or (self:IsHovered() and C.panel or Color(0, 0, 0, 0)))
			if active then draw.RoundedBox(S(2), 0, S(8), S(3), h - S(16), C.accent) end
			draw.SimpleText(page[1], "Astral.UI.Text", S(16), h / 2, active and C.text or C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		b.DoClick = function() show(i) end
	end
	show(current)
end

-- Ouvre directement une page par son titre (« Règles », « Aide »…)
function M.OpenPage(title)
	for i, p in ipairs(PAGES) do if p[1] == title then return M.Open(i) end end
	M.Open()
end

function M.Toggle()
	if IsValid(M.Frame) then M.Frame:Close() else M.Open() end
end

-- Touche F3 (même comportement que SpaceVX, sans gêner la personnalisation d'arme CW 2.0 ni la saisie de texte)
local wasDown = false
hook.Add("Think", "Astral.Menu.Key", function()
	if not GetConVar("astral_hud") or not GetConVar("astral_hud"):GetBool() then return end
	local down = input.IsKeyDown(KEY_F3)
	if down and not wasDown and not gui.IsGameUIVisible() and not IsValid(vgui.GetKeyboardFocus()) then
		local wep = LocalPlayer():GetActiveWeapon()
		if not (IsValid(wep) and wep.CW20Weapon and wep.dt and wep.dt.State == (CW_CUSTOMIZE or 4)) then M.Toggle() end
	end
	wasDown = down
end)

concommand.Add("astral_menu_principal", function() M.Toggle() end)
